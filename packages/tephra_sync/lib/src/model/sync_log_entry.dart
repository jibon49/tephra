// © 2026 Tephra. All rights reserved.

/// A single event entry in the user-visible synchronization log.
final class SyncLogEntry {
  /// Creates a [SyncLogEntry].
  const SyncLogEntry({
    this.id,
    required this.time,
    required this.level,
    required this.kind,
    this.path,
    this.otherPath,
    this.deviceName,
    this.detail,
  });

  /// Auto-incrementing database ID.
  final int? id;

  /// Timestamp in milliseconds UTC.
  final int time;

  /// Severity level: 'info', 'warning', 'error'.
  final String level;

  /// Event kind: 'upload', 'download', 'conflict', 'delete', 'move', etc.
  final String kind;

  /// Primary affected vault-relative path.
  final String? path;

  /// Secondary affected path (e.g. rename target).
  final String? otherPath;

  /// Name of the participating remote device.
  final String? deviceName;

  /// Technical detail, failure message, or explanation.
  final String? detail;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncLogEntry &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          time == other.time &&
          level == other.level &&
          kind == other.kind &&
          path == other.path &&
          otherPath == other.otherPath &&
          deviceName == other.deviceName &&
          detail == other.detail;

  @override
  int get hashCode =>
      Object.hash(id, time, level, kind, path, otherPath, deviceName, detail);

  @override
  String toString() =>
      'SyncLogEntry(id: $id, level: $level, kind: $kind, path: $path, time: $time)';
}
