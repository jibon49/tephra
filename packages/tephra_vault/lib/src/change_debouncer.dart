// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

/// The kind of raw change reported by a file watcher.
enum RawChangeKind { added, modified, removed }

/// A merged change coalesced by [ChangeDebouncer].
final class MergedChange {
  const MergedChange(this.path, this.kind);

  final VaultPath path;
  final RawChangeKind kind;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MergedChange && path == other.path && kind == other.kind;

  @override
  int get hashCode => Object.hash(path, kind);

  @override
  String toString() => 'MergedChange($path, $kind)';
}

/// Debounces and coalesces raw filesystem change events.
final class ChangeDebouncer {
  ChangeDebouncer({
    required this.clock,
    this.quiet = const Duration(milliseconds: 150),
    this.maxWait = const Duration(milliseconds: 500),
  });

  final Clock clock;
  final Duration quiet;
  final Duration maxWait;

  final Map<VaultPath, RawChangeKind?> _changes = {};
  final List<VaultPath> _order = [];
  DateTime? _firstEventAt;
  DateTime? _lastEventAt;

  bool get isEmpty => _firstEventAt == null;
  bool get isNotEmpty => _firstEventAt != null;

  /// Adds a raw change event for [path].
  void add(VaultPath path, RawChangeKind kind) {
    final now = clock.now();
    _firstEventAt ??= now;
    _lastEventAt = now;

    if (!_changes.containsKey(path)) {
      _order.add(path);
      _changes[path] = kind;
    } else {
      final existing = _changes[path];
      if (existing == null) {
        _changes[path] = kind;
      } else {
        _changes[path] = _merge(existing, kind);
      }
    }
  }

  static RawChangeKind? _merge(RawChangeKind earlier, RawChangeKind later) {
    switch ((earlier, later)) {
      case (RawChangeKind.added, RawChangeKind.modified):
        return RawChangeKind.added;
      case (RawChangeKind.added, RawChangeKind.removed):
        return null;
      case (RawChangeKind.modified, RawChangeKind.modified):
        return RawChangeKind.modified;
      case (RawChangeKind.modified, RawChangeKind.removed):
        return RawChangeKind.removed;
      case (RawChangeKind.removed, RawChangeKind.added):
        return RawChangeKind.modified;
      case (RawChangeKind.removed, RawChangeKind.modified):
        return RawChangeKind.modified;
      case (RawChangeKind.modified, RawChangeKind.added):
        return RawChangeKind.modified;
      case (RawChangeKind.removed, RawChangeKind.removed):
        return RawChangeKind.removed;
      case (RawChangeKind.added, RawChangeKind.added):
        return RawChangeKind.added;
    }
  }

  /// Returns the merged changes when the quiet period (150 ms since the last
  /// event) or maxWait (500 ms since the first pending event) has elapsed, else
  /// null.
  List<MergedChange>? flushIfDue() {
    final due = nextDueAt;
    if (due == null) return null;
    final now = clock.now();
    if (now.isBefore(due)) return null;

    final result = <MergedChange>[];
    for (final path in _order) {
      final kind = _changes[path];
      if (kind != null) {
        result.add(MergedChange(path, kind));
      }
    }
    clear();
    return result;
  }

  /// Returns the timestamp when pending events are next due for flush,
  /// or null if no events are pending.
  DateTime? get nextDueAt {
    if (_firstEventAt == null || _lastEventAt == null) return null;
    final quietDue = _lastEventAt!.add(quiet);
    final maxDue = _firstEventAt!.add(maxWait);
    return quietDue.isBefore(maxDue) ? quietDue : maxDue;
  }

  /// Clears all pending changes.
  void clear() {
    _changes.clear();
    _order.clear();
    _firstEventAt = null;
    _lastEventAt = null;
  }
}
