// © 2026 Tephra. All rights reserved.

/// Storage usage and capacity information reported by a [SyncProvider].
final class Quota {
  /// Creates a [Quota] report.
  const Quota({required this.usedBytes, this.limitBytes});

  /// Decodes [Quota] from a JSON map.
  factory Quota.fromJson(Map<String, Object?> json) {
    return Quota(
      usedBytes: (json['usedBytes']! as num).toInt(),
      limitBytes: (json['limitBytes'] as num?)?.toInt(),
    );
  }

  /// Total bytes currently consumed on the remote backend.
  final int usedBytes;

  /// Total byte capacity, or null if storage is unlimited.
  final int? limitBytes;

  /// Remaining free storage in bytes, or null if unlimited.
  int? get freeBytes => limitBytes == null ? null : limitBytes! - usedBytes;

  /// Encodes this quota report to a JSON-compatible map.
  Map<String, Object?> toJson() => {
    'usedBytes': usedBytes,
    if (limitBytes != null) 'limitBytes': limitBytes,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Quota &&
          runtimeType == other.runtimeType &&
          usedBytes == other.usedBytes &&
          limitBytes == other.limitBytes;

  @override
  int get hashCode => Object.hash(usedBytes, limitBytes);

  @override
  String toString() =>
      'Quota(used: $usedBytes, limit: $limitBytes, free: $freeBytes)';
}
