// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_markdown/tephra_markdown.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../../core/json_file_store.dart';
import 'fold_regions.dart';

/// Stored representation of a single fold item in `.tephra/workspace.json`.
final class FoldItem {
  const FoldItem({required this.kind, required this.line, required this.text});

  factory FoldItem.fromJson(Map<String, Object?> json) {
    final kStr = json['k'] as String?;
    final kind = kStr == 'l' ? FoldKind.list : FoldKind.heading;
    final line = (json['line'] as num?)?.toInt() ?? 0;
    final text = json['text'] as String? ?? '';
    return FoldItem(kind: kind, line: line, text: text);
  }

  /// 'h' for heading, 'l' for list item.
  final FoldKind kind;

  /// 0-based line number of the header.
  final int line;

  /// Trimmed header line text, up to 80 characters.
  final String text;

  Map<String, Object?> toJson() => {
    'k': kind == FoldKind.heading ? 'h' : 'l',
    'line': line,
    'text': text,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FoldItem &&
          kind == other.kind &&
          line == other.line &&
          text == other.text;

  @override
  int get hashCode => Object.hash(kind, line, text);

  @override
  String toString() => 'FoldItem(kind: $kind, line: $line, text: "$text")';
}

/// Store for persisting folded regions in `.tephra/workspace.json`.
final class FoldStore {
  FoldStore({
    required this.fs,
    required this.deviceId,
    Clock? clock,
    TephraJsonStore? jsonStore,
  }) : clock = clock ?? const SystemClock(),
       jsonStore = jsonStore ?? TephraJsonStore(clock);

  final VaultFileSystem fs;
  final String deviceId;
  final Clock clock;
  final TephraJsonStore jsonStore;

  static final _workspacePath = VaultPath('.tephra/workspace.json');

  Timer? _debounceTimer;
  final Map<VaultPath, List<FoldItem>> _pending = {};

  /// Constructs a [FoldItem] from a given [region].
  static FoldItem itemFromRegion({
    required FoldRegion region,
    required String text,
    required LineIndex lines,
  }) {
    final headerLine = lines.lineOf(region.headerStart);
    final start = lines.lineStart(headerLine);
    final end = lines.lineEnd(headerLine);
    var headerText = text.substring(start, end).trim();
    if (headerText.length > 80) {
      headerText = headerText.substring(0, 80);
    }
    return FoldItem(kind: region.kind, line: headerLine, text: headerText);
  }

  /// Loads persisted fold items for [path].
  Future<List<FoldItem>> load(VaultPath path) async {
    await flush();
    final root = await jsonStore.readMap(fs, _workspacePath);
    final rawDevice = root[deviceId];
    if (rawDevice is! Map) return const [];
    final rawFolds = rawDevice['folds'];
    if (rawFolds is! Map) return const [];
    final rawNote = rawFolds[path.value];
    if (rawNote is! Map) return const [];
    final rawItems = rawNote['items'];
    if (rawItems is! List) return const [];

    final items = <FoldItem>[];
    for (final raw in rawItems) {
      if (raw is Map) {
        items.add(FoldItem.fromJson(Map<String, Object?>.from(raw)));
      }
    }
    return items;
  }

  /// Debounces saving [items] for [path] by 1 second.
  ///
  /// Saving an empty list removes the note's entry.
  void save(VaultPath path, List<FoldItem> items) {
    _pending[path] = items;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 1), () {
      unawaited(flush());
    });
  }

  /// Flushes any pending debounced saves to disk immediately.
  Future<void> flush() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    if (_pending.isEmpty) return;

    final toWrite = Map<VaultPath, List<FoldItem>>.from(_pending);
    _pending.clear();
    await _persist(toWrite);
  }

  Future<void> _persist(Map<VaultPath, List<FoldItem>> toWrite) async {
    await jsonStore.update(fs, _workspacePath, (root) {
      final rawDevice = root[deviceId];
      final Map<String, Object?> deviceMap = rawDevice is Map
          ? Map<String, Object?>.from(rawDevice)
          : <String, Object?>{};

      final rawFolds = deviceMap['folds'];
      final Map<String, Object?> foldsMap = rawFolds is Map
          ? Map<String, Object?>.from(rawFolds)
          : <String, Object?>{};

      final nowMs = clock.now().millisecondsSinceEpoch;

      for (final entry in toWrite.entries) {
        final pathKey = entry.key.value;
        final items = entry.value;
        if (items.isEmpty) {
          foldsMap.remove(pathKey);
        } else {
          foldsMap[pathKey] = {
            't': nowMs,
            'items': items.map((e) => e.toJson()).toList(),
          };
        }
      }

      // At most 500 notes are kept (drop the oldest t).
      if (foldsMap.length > 500) {
        final entries = foldsMap.entries.toList()
          ..sort((a, b) {
            final aTime = ((a.value as Map?)?['t'] as num?)?.toInt() ?? 0;
            final bTime = ((b.value as Map?)?['t'] as num?)?.toInt() ?? 0;
            return aTime.compareTo(bTime);
          });
        while (entries.length > 500) {
          final oldest = entries.removeAt(0);
          foldsMap.remove(oldest.key);
        }
      }

      deviceMap['folds'] = foldsMap;
      root[deviceId] = deviceMap;
    });
  }

  /// Re-keys entries when files or folders are moved.
  Future<void> retarget(Map<VaultPath, VaultPath> moves) async {
    await flush();
    if (moves.isEmpty) return;

    await jsonStore.update(fs, _workspacePath, (root) {
      final rawDevice = root[deviceId];
      if (rawDevice is! Map) return;
      final deviceMap = Map<String, Object?>.from(rawDevice);
      final rawFolds = deviceMap['folds'];
      if (rawFolds is! Map) return;
      final foldsMap = Map<String, Object?>.from(rawFolds);

      var changed = false;
      final newFolds = <String, Object?>{};

      for (final entry in foldsMap.entries) {
        final oldKey = entry.key;
        final oldPath = VaultPath(oldKey);
        var targetKey = oldKey;

        if (moves.containsKey(oldPath)) {
          targetKey = moves[oldPath]!.value;
          changed = true;
        } else {
          for (final move in moves.entries) {
            final fromPrefix = '${move.key.value}/';
            if (oldKey.startsWith(fromPrefix)) {
              targetKey =
                  '${move.value.value}/${oldKey.substring(fromPrefix.length)}';
              changed = true;
              break;
            }
          }
        }
        newFolds[targetKey] = entry.value;
      }

      if (changed) {
        deviceMap['folds'] = newFolds;
        root[deviceId] = deviceMap;
      }
    });
  }

  /// Removes entries for [path] (or its descendants if a folder) from the store.
  Future<void> remove(VaultPath path) async {
    await flush();
    await jsonStore.update(fs, _workspacePath, (root) {
      final rawDevice = root[deviceId];
      if (rawDevice is! Map) return;
      final deviceMap = Map<String, Object?>.from(rawDevice);
      final rawFolds = deviceMap['folds'];
      if (rawFolds is! Map) return;
      final foldsMap = Map<String, Object?>.from(rawFolds);

      final pathKey = path.value;
      final prefix = '$pathKey/';
      final toRemove = foldsMap.keys
          .where((k) => k == pathKey || k.startsWith(prefix))
          .toList();

      if (toRemove.isNotEmpty) {
        for (final k in toRemove) {
          foldsMap.remove(k);
        }
        deviceMap['folds'] = foldsMap;
        root[deviceId] = deviceMap;
      }
    });
  }

  /// Restores fold regions from [storedItems] against [regions].
  ///
  /// For each stored item:
  /// 1. Finds the region of the same `k` whose header line number equals `line`
  ///    and whose header text equals `text`.
  /// 2. If none, the region with the same text nearest to `line` (within ±200 lines)
  ///    not yet used.
  /// 3. If none, drops the item.
  static List<FoldRegion> restore({
    required List<FoldRegion> regions,
    required List<FoldItem> storedItems,
    required String text,
    required LineIndex lines,
  }) {
    if (storedItems.isEmpty || regions.isEmpty) return const [];

    final regionMeta = <({FoldRegion region, int line, String text})>[];

    for (final r in regions) {
      final line = lines.lineOf(r.headerStart);
      final start = lines.lineStart(line);
      final end = lines.lineEnd(line);
      var hText = text.substring(start, end).trim();
      if (hText.length > 80) {
        hText = hText.substring(0, 80);
      }
      regionMeta.add((region: r, line: line, text: hText));
    }

    final usedIndices = <int>{};
    final restored = <FoldRegion>[];

    for (final item in storedItems) {
      int? matchIndex;

      // 1. Exact match on kind, line number, and header text.
      for (var i = 0; i < regionMeta.length; i++) {
        if (usedIndices.contains(i)) continue;
        final m = regionMeta[i];
        if (m.region.kind == item.kind &&
            m.line == item.line &&
            m.text == item.text) {
          matchIndex = i;
          break;
        }
      }

      // 2. Nearest region with same kind and text within ±200 lines.
      if (matchIndex == null) {
        int? bestIndex;
        var bestDist = 201;
        for (var i = 0; i < regionMeta.length; i++) {
          if (usedIndices.contains(i)) continue;
          final m = regionMeta[i];
          if (m.region.kind == item.kind && m.text == item.text) {
            final dist = (m.line - item.line).abs();
            if (dist <= 200 && dist < bestDist) {
              bestDist = dist;
              bestIndex = i;
            }
          }
        }
        matchIndex = bestIndex;
      }

      // 3. If found, mark region as used and add to restored.
      if (matchIndex != null) {
        usedIndices.add(matchIndex);
        restored.add(regionMeta[matchIndex].region);
      }
    }

    return restored;
  }
}
