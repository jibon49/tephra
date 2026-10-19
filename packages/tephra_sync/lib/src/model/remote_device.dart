// © 2026 Tephra. All rights reserved.

/// Represents a device registered to a remote vault.
final class RemoteDevice {
  /// Creates a [RemoteDevice].
  const RemoteDevice({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    this.appVersion,
    required this.registeredAt,
    required this.updatedAt,
    this.revoked = false,
    this.revokedBy,
    this.revokedAt,
    this.lastAcceptedSeq,
  });

  /// Unique identifier of the device.
  final String deviceId;

  /// User-visible device name.
  final String deviceName;

  /// Operating system platform ('android' | 'windows').
  final String platform;

  /// App version string at last update (e.g. '0.3.0').
  final String? appVersion;

  /// Timestamp when the device was first registered.
  final DateTime registeredAt;

  /// Timestamp of the device's last heartbeat or activity.
  final DateTime updatedAt;

  /// Whether this device has been revoked by an active vault member.
  final bool revoked;

  /// Device ID that issued the revocation, if revoked.
  final String? revokedBy;

  /// Timestamp when the revocation was issued.
  final DateTime? revokedAt;

  /// Sequence number limit beyond which changes from this device are discarded.
  final int? lastAcceptedSeq;

  /// Returns a copy of [RemoteDevice] with optional field replacements.
  RemoteDevice copyWith({
    String? deviceId,
    String? deviceName,
    String? platform,
    String? appVersion,
    DateTime? registeredAt,
    DateTime? updatedAt,
    bool? revoked,
    String? revokedBy,
    DateTime? revokedAt,
    int? lastAcceptedSeq,
  }) {
    return RemoteDevice(
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      platform: platform ?? this.platform,
      appVersion: appVersion ?? this.appVersion,
      registeredAt: registeredAt ?? this.registeredAt,
      updatedAt: updatedAt ?? this.updatedAt,
      revoked: revoked ?? this.revoked,
      revokedBy: revokedBy ?? this.revokedBy,
      revokedAt: revokedAt ?? this.revokedAt,
      lastAcceptedSeq: lastAcceptedSeq ?? this.lastAcceptedSeq,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RemoteDevice &&
          runtimeType == other.runtimeType &&
          deviceId == other.deviceId &&
          deviceName == other.deviceName &&
          platform == other.platform &&
          appVersion == other.appVersion &&
          registeredAt == other.registeredAt &&
          updatedAt == other.updatedAt &&
          revoked == other.revoked &&
          revokedBy == other.revokedBy &&
          revokedAt == other.revokedAt &&
          lastAcceptedSeq == other.lastAcceptedSeq;

  @override
  int get hashCode => Object.hash(
    deviceId,
    deviceName,
    platform,
    appVersion,
    registeredAt,
    updatedAt,
    revoked,
    revokedBy,
    revokedAt,
    lastAcceptedSeq,
  );

  @override
  String toString() =>
      'RemoteDevice($deviceId, name: $deviceName, platform: $platform, revoked: $revoked)';
}
