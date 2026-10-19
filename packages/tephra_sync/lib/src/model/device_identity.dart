// © 2026 Tephra. All rights reserved.

/// Unique identity of a device participating in vault synchronization.
final class DeviceIdentity {
  /// Creates a [DeviceIdentity].
  const DeviceIdentity({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
  });

  /// Decodes a [DeviceIdentity] from JSON map.
  factory DeviceIdentity.fromJson(Map<String, Object?> json) {
    return DeviceIdentity(
      deviceId: (json['deviceId'] ?? json['device_id'])! as String,
      deviceName: (json['deviceName'] ?? json['device_name'])! as String,
      platform: (json['platform'])! as String,
    );
  }

  /// Lower-case RFC 4122 v4 UUID string representing this device.
  final String deviceId;

  /// Human-readable device name (e.g. 'Pixel 8', 'Living Room PC').
  final String deviceName;

  /// Operating system platform identifier ('android' or 'windows').
  final String platform;

  /// Encodes this identity to a JSON map.
  Map<String, Object?> toJson() => {
    'deviceId': deviceId,
    'deviceName': deviceName,
    'platform': platform,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceIdentity &&
          runtimeType == other.runtimeType &&
          deviceId == other.deviceId &&
          deviceName == other.deviceName &&
          platform == other.platform;

  @override
  int get hashCode => Object.hash(deviceId, deviceName, platform);

  @override
  String toString() =>
      'DeviceIdentity(deviceId: $deviceId, deviceName: $deviceName, platform: $platform)';
}
