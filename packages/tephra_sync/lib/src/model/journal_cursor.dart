// © 2026 Tephra. All rights reserved.

/// Processing progress cursor for a specific remote device's journals.
final class JournalCursor {
  /// Creates a [JournalCursor].
  const JournalCursor({
    required this.deviceId,
    required this.lastSeq,
    this.deviceName,
    this.platform,
    this.lastSeenAt,
    this.revokedAfterSeq,
  });

  /// Remote device lower-case UUID.
  final String deviceId;

  /// Highest sequence number processed from this device.
  final int lastSeq;

  /// Human-readable device name.
  final String? deviceName;

  /// Platform identifier ('android' or 'windows').
  final String? platform;

  /// Last seen timestamp in milliseconds UTC.
  final int? lastSeenAt;

  /// Revocation sequence cutoff, if device has been revoked.
  final int? revokedAfterSeq;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JournalCursor &&
          runtimeType == other.runtimeType &&
          deviceId == other.deviceId &&
          lastSeq == other.lastSeq &&
          deviceName == other.deviceName &&
          platform == other.platform &&
          lastSeenAt == other.lastSeenAt &&
          revokedAfterSeq == other.revokedAfterSeq;

  @override
  int get hashCode => Object.hash(
    deviceId,
    lastSeq,
    deviceName,
    platform,
    lastSeenAt,
    revokedAfterSeq,
  );

  @override
  String toString() =>
      'JournalCursor(deviceId: $deviceId, lastSeq: $lastSeq, revoked: $revokedAfterSeq)';
}
