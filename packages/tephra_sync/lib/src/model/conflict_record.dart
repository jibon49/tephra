// © 2026 Tephra. All rights reserved.

/// Record of a file conflict discovered during synchronization.
final class ConflictRecord {
  /// Creates a [ConflictRecord].
  const ConflictRecord({
    this.id,
    required this.time,
    required this.path,
    required this.copyPath,
    required this.kind,
    required this.otherDevice,
    this.resolved = false,
  });

  /// Auto-incrementing database ID.
  final int? id;

  /// Detection timestamp in milliseconds UTC.
  final int time;

  /// Original vault-relative path.
  final String path;

  /// Vault-relative path where the conflicting copy was preserved.
  final String copyPath;

  /// Conflict type: 'content', 'case', 'delete_edit'.
  final String kind;

  /// Name of the competing remote device.
  final String otherDevice;

  /// True if marked resolved by the user or automatic action.
  final bool resolved;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConflictRecord &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          time == other.time &&
          path == other.path &&
          copyPath == other.copyPath &&
          kind == other.kind &&
          otherDevice == other.otherDevice &&
          resolved == other.resolved;

  @override
  int get hashCode =>
      Object.hash(id, time, path, copyPath, kind, otherDevice, resolved);

  @override
  String toString() =>
      'ConflictRecord(id: $id, path: $path, copyPath: $copyPath, kind: $kind, resolved: $resolved)';
}
