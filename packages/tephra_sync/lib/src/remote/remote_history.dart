// © 2026 Tephra. All rights reserved.

import '../model/hlc.dart';
import '../model/journal_entry.dart';

/// Pure causal history graph computed from a collection of [JournalEntry] records.
///
/// Tracks heads, leaves, forks, and lowest common ancestors across all vault paths.
final class RemoteHistory {
  /// Constructs a [RemoteHistory] from an un-ordered list of [entries].
  factory RemoteHistory(Iterable<JournalEntry> entries) {
    final byId = <String, JournalEntry>{};
    final paths = <String>{};

    for (final e in entries) {
      byId[e.entryId] = e;
      paths.add(e.path);
      if (e.fromPath != null) {
        paths.add(e.fromPath!);
      }
    }

    return RemoteHistory._(byId: byId, allPaths: paths);
  }

  RemoteHistory._({required this.byId, required this.allPaths});

  /// Map of all known journal entries keyed by their unique entryId (`<deviceId>:<seq>`).
  final Map<String, JournalEntry> byId;

  /// Set of all paths ever touched by any entry.
  final Set<String> allPaths;

  /// Returns the parent entry ID of [entry] specifically along the version chain for [path].
  static String? parentAt(JournalEntry entry, String path) {
    if (entry.op == 'put' || entry.op == 'delete') {
      return entry.path == path ? entry.parent : null;
    }
    if (entry.op == 'move') {
      if (entry.fromPath == path) {
        return entry.parent;
      }
      if (entry.path == path) {
        return entry.targetParent;
      }
    }
    return null;
  }

  /// Returns true if [entry] represents a present (non-deleted) file at [path].
  static bool isPresentAt(JournalEntry entry, String path) {
    if (entry.op == 'put' && entry.path == path) return true;
    if (entry.op == 'move' && entry.path == path) return true;
    return false;
  }

  /// Returns all entries touching [path] (either target `path` or `fromPath` for moves).
  List<JournalEntry> entriesTouching(String path) {
    final list = <JournalEntry>[];
    for (final e in byId.values) {
      if (e.path == path || (e.op == 'move' && e.fromPath == path)) {
        list.add(e);
      }
    }
    return list;
  }

  /// Returns all leaf entries at [path], sorted descending by HLC.
  ///
  /// Leaves are entries touching [path] that are not referenced as `parentAt`
  /// or `mergedParent` by any other entry touching [path].
  List<JournalEntry> leaves(String path) {
    final touching = entriesTouching(path);
    if (touching.isEmpty) return const [];

    final referenced = <String>{};
    for (final e in touching) {
      final p = parentAt(e, path);
      if (p != null) referenced.add(p);
      final m = e.mergedParent;
      if (m != null) referenced.add(m);
    }

    final result = <JournalEntry>[];
    for (final e in touching) {
      if (!referenced.contains(e.entryId)) {
        result.add(e);
      }
    }

    result.sort((a, b) => Hlc.parse(b.hlc).compareTo(Hlc.parse(a.hlc)));
    return result;
  }

  /// Returns the current head entry for [path] (the leaf with the greatest HLC).
  JournalEntry? head(String path) {
    final l = leaves(path);
    return l.isEmpty ? null : l.first;
  }

  /// Returns true if [path] currently has multiple un-merged leaves (a fork).
  bool isForked(String path) => leaves(path).length > 1;

  /// Returns all forked paths that have more than one leaf.
  List<String> forkedPaths() {
    final result = <String>[];
    for (final p in allPaths) {
      if (isForked(p)) {
        result.add(p);
      }
    }
    return result;
  }

  /// Performs a breadth-first search backwards along `parentAt` and `mergedParent`
  /// links touching [path] to check if [ancestorId] is an ancestor of (or equal to) [entryId].
  bool isAncestorOrEqual(String ancestorId, String entryId, String path) {
    if (ancestorId == entryId) return true;

    final visited = <String>{entryId};
    final queue = <String>[entryId];

    while (queue.isNotEmpty) {
      final currentId = queue.removeAt(0);
      if (currentId == ancestorId) return true;

      final entry = byId[currentId];
      if (entry == null) continue; // unknown IDs end the walk

      final p = parentAt(entry, path);
      if (p != null && visited.add(p)) {
        queue.add(p);
      }

      final m = entry.mergedParent;
      if (m != null && visited.add(m)) {
        queue.add(m);
      }
    }

    return false;
  }

  /// Finds the Lowest Common Ancestor (LCA) entry between [aId] and [bId] on [path].
  ///
  /// Collects all ancestors-or-self of [aId] and traverses ancestors-or-self
  /// of [bId] in descending HLC order, returning the highest-HLC common node.
  JournalEntry? lowestCommonAncestor(String aId, String bId, String path) {
    final aAncestors = <String>{};
    final aQueue = <String>[aId];

    while (aQueue.isNotEmpty) {
      final curr = aQueue.removeAt(0);
      if (aAncestors.add(curr)) {
        final entry = byId[curr];
        if (entry != null) {
          final p = parentAt(entry, path);
          if (p != null) aQueue.add(p);
          final m = entry.mergedParent;
          if (m != null) aQueue.add(m);
        }
      }
    }

    final bAncestors = <String>{};
    final bQueue = <String>[bId];

    while (bQueue.isNotEmpty) {
      final curr = bQueue.removeAt(0);
      if (bAncestors.add(curr)) {
        final entry = byId[curr];
        if (entry != null) {
          final p = parentAt(entry, path);
          if (p != null) bQueue.add(p);
          final m = entry.mergedParent;
          if (m != null) bQueue.add(m);
        }
      }
    }

    final common = <JournalEntry>[];
    for (final id in bAncestors) {
      if (aAncestors.contains(id)) {
        final entry = byId[id];
        if (entry != null) common.add(entry);
      }
    }

    if (common.isEmpty) return null;
    common.sort((a, b) => Hlc.parse(b.hlc).compareTo(Hlc.parse(a.hlc)));
    return common.first;
  }

  /// Returns all paths whose current head is "present" (not deleted or moved away).
  Set<String> livePaths() {
    final live = <String>{};
    for (final p in allPaths) {
      final h = head(p);
      if (h != null && isPresentAt(h, p)) {
        live.add(p);
      }
    }
    return live;
  }

  /// Returns all historical versions touching [path], sorted in descending HLC order.
  List<JournalEntry> versions(String path) {
    final list = entriesTouching(path);
    list.sort((a, b) => Hlc.parse(b.hlc).compareTo(Hlc.parse(a.hlc)));
    return list;
  }
}
