// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import 'package:tephra_core/tephra_core.dart';

import '../crypto/object_cipher.dart';
import '../crypto/object_purpose.dart';
import '../errors/sync_exceptions.dart';
import '../model/device_identity.dart';
import '../model/remote_device.dart';
import '../provider/sync_provider.dart';
import 'remote_layout.dart';

/// Manages device registration, periodic heartbeats, and revocations in remote vaults.
final class DeviceRegistry {
  /// Creates a [DeviceRegistry].
  DeviceRegistry(
    this.provider,
    this.cipher, {
    this.clock = const SystemClock(),
  });

  /// The underlying remote storage provider.
  final SyncProvider provider;

  /// Object cipher used to seal and open device records.
  final ObjectCipher cipher;

  /// Clock used for timestamping registrations and revocations.
  final Clock clock;

  /// Minimum interval required between device heartbeat writes (1 hour).
  static const Duration heartbeatThrottle = Duration(hours: 1);

  /// Registers [device] with the remote vault.
  ///
  /// Writes `devices/<deviceId>.json.enc` sealed under [ObjectPurpose.device].
  /// If the device was previously registered, preserves its original [registeredAt] timestamp.
  Future<void> register(
    DeviceIdentity device, {
    String appVersion = '0.3.0',
  }) async {
    final now = clock.now().toUtc();
    var registeredAt = now;

    final key = RemoteLayout.deviceInfo(device.deviceId);
    try {
      final existingBytes = await provider.get(key);
      final decrypted = await cipher.open(existingBytes, ObjectPurpose.device);
      final json = jsonDecode(utf8.decode(decrypted)) as Map<String, Object?>;
      final existingReg = json['registeredAt'] as String?;
      if (existingReg != null) {
        registeredAt = DateTime.parse(existingReg).toUtc();
      }
    } on RemoteNotFoundException {
      // First registration; registeredAt is now
    }

    final payload = {
      'v': 1,
      'deviceId': device.deviceId,
      'deviceName': device.deviceName,
      'platform': device.platform,
      'appVersion': appVersion,
      'registeredAt': registeredAt.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };

    final sealed = await cipher.seal(
      utf8.encode(jsonEncode(payload)),
      ObjectPurpose.device,
    );
    await provider.put(key, sealed);
  }

  /// Updates heartbeat timestamp for [device], throttled to at most once per hour.
  ///
  /// If less than 1 hour has elapsed since the last update, this method is a no-op.
  Future<void> heartbeat(
    DeviceIdentity device, {
    String appVersion = '0.3.0',
  }) async {
    final key = RemoteLayout.deviceInfo(device.deviceId);
    final now = clock.now().toUtc();

    try {
      final existingBytes = await provider.get(key);
      final decrypted = await cipher.open(existingBytes, ObjectPurpose.device);
      final json = jsonDecode(utf8.decode(decrypted)) as Map<String, Object?>;
      final lastUpdatedStr = json['updatedAt'] as String?;
      if (lastUpdatedStr != null) {
        final lastUpdated = DateTime.parse(lastUpdatedStr).toUtc();
        if (now.difference(lastUpdated) < heartbeatThrottle) {
          // Throttled: at most once per hour
          return;
        }
      }

      final registeredAtStr = json['registeredAt'] as String?;
      final registeredAt = registeredAtStr != null
          ? DateTime.parse(registeredAtStr).toUtc()
          : now;

      final payload = {
        'v': 1,
        'deviceId': device.deviceId,
        'deviceName': device.deviceName,
        'platform': device.platform,
        'appVersion': appVersion,
        'registeredAt': registeredAt.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };

      final sealed = await cipher.seal(
        utf8.encode(jsonEncode(payload)),
        ObjectPurpose.device,
      );
      await provider.put(key, sealed);
    } on RemoteNotFoundException {
      await register(device, appVersion: appVersion);
    }
  }

  /// Revokes [targetId] on the remote vault with [lastAcceptedSeq].
  ///
  /// Writes `devices/<targetId>.revoked.json.enc`. If the file already exists,
  /// this is a no-op: the first revocation stands.
  Future<void> revoke(
    String targetId,
    int lastAcceptedSeq, {
    required String revokedBy,
  }) async {
    final revKey = RemoteLayout.deviceRevocation(targetId);
    try {
      await provider.get(revKey);
      // Already revoked; the first revocation stands
      return;
    } on RemoteNotFoundException {
      // Not yet revoked; proceed
    }

    final now = clock.now().toUtc();
    final payload = {
      'v': 1,
      'deviceId': targetId,
      'revokedBy': revokedBy,
      'revokedAt': now.toIso8601String(),
      'lastAcceptedSeq': lastAcceptedSeq,
    };

    final sealed = await cipher.seal(
      utf8.encode(jsonEncode(payload)),
      ObjectPurpose.device,
    );
    await provider.put(revKey, sealed);
  }

  /// Lists all registered devices and merges revocation records.
  Future<List<RemoteDevice>> listDevices() async {
    final objects = await provider.list(RemoteLayout.devicesPrefix);

    final infoKeys = <String, String>{}; // deviceId -> key
    final revKeys = <String, String>{}; // deviceId -> key

    for (final obj in objects) {
      final key = obj.key;
      final parsed = RemoteLayout.parse(key);
      if (parsed is DeviceInfoKey) {
        infoKeys[parsed.deviceId] = key;
      } else if (parsed is DeviceRevocationKey) {
        revKeys[parsed.deviceId] = key;
      }
    }

    // Read all revocation records
    final revocations = <String, Map<String, Object?>>{};
    for (final entry in revKeys.entries) {
      try {
        final bytes = await provider.get(entry.value);
        final decrypted = await cipher.open(bytes, ObjectPurpose.device);
        final json = jsonDecode(utf8.decode(decrypted)) as Map<String, Object?>;
        revocations[entry.key] = json;
      } catch (_) {
        // Skip unreadable or corrupt revocation records
      }
    }

    final devices = <RemoteDevice>[];

    // Read all device info records
    for (final entry in infoKeys.entries) {
      try {
        final bytes = await provider.get(entry.value);
        final decrypted = await cipher.open(bytes, ObjectPurpose.device);
        final json = jsonDecode(utf8.decode(decrypted)) as Map<String, Object?>;

        final deviceId = json['deviceId'] as String;
        final deviceName = json['deviceName'] as String;
        final platform = json['platform'] as String;
        final appVersion = json['appVersion'] as String?;
        final registeredAt = DateTime.parse(json['registeredAt'] as String)
            .toUtc();
        final updatedAt = DateTime.parse(json['updatedAt'] as String).toUtc();

        final rev = revocations[deviceId];
        final isRevoked = rev != null;
        final revokedBy = rev?['revokedBy'] as String?;
        final revokedAtStr = rev?['revokedAt'] as String?;
        final revokedAt = revokedAtStr != null
            ? DateTime.parse(revokedAtStr).toUtc()
            : null;
        final lastAcceptedSeq = (rev?['lastAcceptedSeq'] as num?)?.toInt();

        devices.add(
          RemoteDevice(
            deviceId: deviceId,
            deviceName: deviceName,
            platform: platform,
            appVersion: appVersion,
            registeredAt: registeredAt,
            updatedAt: updatedAt,
            revoked: isRevoked,
            revokedBy: revokedBy,
            revokedAt: revokedAt,
            lastAcceptedSeq: lastAcceptedSeq,
          ),
        );
      } catch (_) {
        // Skip unreadable device info records
      }
    }

    // Handle any orphaned revocation records whose info file was not found
    for (final entry in revocations.entries) {
      if (!infoKeys.containsKey(entry.key)) {
        final rev = entry.value;
        final deviceId = rev['deviceId'] as String? ?? entry.key;
        final revokedBy = rev['revokedBy'] as String?;
        final revokedAtStr = rev['revokedAt'] as String?;
        final revokedAt = revokedAtStr != null
            ? DateTime.parse(revokedAtStr).toUtc()
            : clock.now().toUtc();
        final lastAcceptedSeq = (rev['lastAcceptedSeq'] as num?)?.toInt();

        devices.add(
          RemoteDevice(
            deviceId: deviceId,
            deviceName: 'Unknown Device',
            platform: 'unknown',
            registeredAt: revokedAt,
            updatedAt: revokedAt,
            revoked: true,
            revokedBy: revokedBy,
            revokedAt: revokedAt,
            lastAcceptedSeq: lastAcceptedSeq,
          ),
        );
      }
    }

    devices.sort((a, b) => a.registeredAt.compareTo(b.registeredAt));
    return devices;
  }
}
