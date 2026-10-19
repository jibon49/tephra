// © 2026 Tephra. All rights reserved.

/// Represents a single append-only journal mutation (`put`, `delete`, or `move`).
final class JournalEntry {
  /// Creates a [JournalEntry].
  const JournalEntry({
    required this.entryId,
    required this.deviceId,
    required this.seq,
    required this.hlc,
    required this.op,
    required this.path,
    this.fromPath,
    this.hash,
    this.size,
    this.mtime,
    this.blobKeys,
    this.parent,
    this.targetParent,
    this.mergedParent,
    required this.time,
  });

  /// Unique entry id format `<deviceId>:<seq>`.
  final String entryId;

  /// Lower-case UUID of the authoring device.
  final String deviceId;

  /// Monotonically increasing sequence number on the authoring device.
  final int seq;

  /// Hybrid Logical Clock timestamp string.
  final String hlc;

  /// Operation kind: 'put', 'delete', or 'move'.
  final String op;

  /// Target vault-relative path.
  final String path;

  /// Original vault-relative path for 'move' operations.
  final String? fromPath;

  /// SHA-256 hash of plaintext content for 'put' operations.
  final String? hash;

  /// File size in bytes for 'put' operations.
  final int? size;

  /// File modification time in milliseconds UTC.
  final int? mtime;

  /// List of ciphertext blob keys.
  final List<String>? blobKeys;

  /// Direct parent entry id in the path's version graph.
  final String? parent;

  /// For 'move' operations: parent entry id of the target path before the move.
  final String? targetParent;

  /// For merge operations: second parent entry id that was merged with [parent].
  final String? mergedParent;

  /// Creation timestamp in milliseconds UTC.
  final int time;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JournalEntry &&
          runtimeType == other.runtimeType &&
          entryId == other.entryId &&
          deviceId == other.deviceId &&
          seq == other.seq &&
          hlc == other.hlc &&
          op == other.op &&
          path == other.path &&
          fromPath == other.fromPath &&
          hash == other.hash &&
          size == other.size &&
          mtime == other.mtime &&
          parent == other.parent &&
          targetParent == other.targetParent &&
          mergedParent == other.mergedParent &&
          time == other.time &&
          _listEquals(blobKeys, other.blobKeys);

  @override
  int get hashCode => Object.hash(
    entryId,
    deviceId,
    seq,
    hlc,
    op,
    path,
    fromPath,
    hash,
    size,
    mtime,
    parent,
    targetParent,
    mergedParent,
    time,
  );

  @override
  String toString() =>
      'JournalEntry(id: $entryId, op: $op, path: $path, seq: $seq, parent: $parent)';

  static bool _listEquals(List<String>? a, List<String>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
