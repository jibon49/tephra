// © 2026 Tephra. All rights reserved.

/// Cached metadata of a remote vault backup manifest.
final class BackupRecord {
  /// Creates a [BackupRecord].
  const BackupRecord({
    required this.stamp,
    required this.manifestKey,
    required this.fileCount,
    required this.totalBytes,
    required this.createdAt,
  });

  /// Timestamp stamp string (`yyyyMMddTHHmmssZ`).
  final String stamp;

  /// Remote manifest key (`backups/<stamp>/manifest.json.enc`).
  final String manifestKey;

  /// Number of files contained in the backup.
  final int fileCount;

  /// Aggregate size in bytes of all files in the backup.
  final int totalBytes;

  /// Creation timestamp in milliseconds UTC.
  final int createdAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BackupRecord &&
          runtimeType == other.runtimeType &&
          stamp == other.stamp &&
          manifestKey == other.manifestKey &&
          fileCount == other.fileCount &&
          totalBytes == other.totalBytes &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      Object.hash(stamp, manifestKey, fileCount, totalBytes, createdAt);

  @override
  String toString() =>
      'BackupRecord(stamp: $stamp, files: $fileCount, bytes: $totalBytes)';
}

/// Record of an integrity verification run performed on a backup.
final class BackupVerificationRecord {
  /// Creates a [BackupVerificationRecord].
  const BackupVerificationRecord({
    this.id,
    required this.time,
    required this.stamp,
    required this.sampled,
    required this.ok,
    required this.failed,
    required this.failedKeys,
  });

  /// Auto-incrementing database ID.
  final int? id;

  /// Verification execution timestamp in milliseconds UTC.
  final int time;

  /// Backup stamp that was checked.
  final String stamp;

  /// Total blobs sampled.
  final int sampled;

  /// Blobs verified intact.
  final int ok;

  /// Blobs failing verification or missing remotely.
  final int failed;

  /// List of remote keys that failed verification.
  final List<String> failedKeys;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BackupVerificationRecord &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          time == other.time &&
          stamp == other.stamp &&
          sampled == other.sampled &&
          ok == other.ok &&
          failed == other.failed &&
          _listEquals(failedKeys, other.failedKeys);

  @override
  int get hashCode => Object.hash(
    id,
    time,
    stamp,
    sampled,
    ok,
    failed,
    Object.hashAll(failedKeys),
  );

  @override
  String toString() =>
      'BackupVerificationRecord(stamp: $stamp, sampled: $sampled, ok: $ok, failed: $failed)';

  static bool _listEquals(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
