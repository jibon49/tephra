// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_sync/tephra_sync.dart';
import 'package:test/test.dart';

void main() {
  group('DeviceRegistry', () {
    late MemorySyncProvider provider;
    late ManualClock clock;
    late EncryptingObjectCipher cipher;
    late DeviceRegistry registry;

    final deviceA = DeviceIdentity(
      deviceId: '11111111-1111-4111-8111-111111111111',
      deviceName: 'Pixel 8',
      platform: 'android',
    );

    final deviceB = DeviceIdentity(
      deviceId: '22222222-2222-4222-8222-222222222222',
      deviceName: 'Workstation',
      platform: 'windows',
    );

    setUp(() async {
      provider = MemorySyncProvider();
      await provider.connect();
      clock = ManualClock(DateTime.utc(2026, 10, 11, 10, 0));
      cipher = EncryptingObjectCipher(
        masterKey: SecretKey(Uint8List(32)),
        vaultId: 'test-vault-id',
      );
      registry = DeviceRegistry(provider, cipher, clock: clock);
    });

    test('register writes encrypted device info file', () async {
      await registry.register(deviceA, appVersion: '0.3.0');

      final key = RemoteLayout.deviceInfo(deviceA.deviceId);
      final raw = await provider.get(key);
      final decrypted = await cipher.open(raw, ObjectPurpose.device);
      final json = jsonDecode(utf8.decode(decrypted)) as Map<String, Object?>;

      expect(json['v'], equals(1));
      expect(json['deviceId'], equals(deviceA.deviceId));
      expect(json['deviceName'], equals('Pixel 8'));
      expect(json['platform'], equals('android'));
      expect(json['appVersion'], equals('0.3.0'));
      expect(json['registeredAt'], equals('2026-10-11T10:00:00.000Z'));
      expect(json['updatedAt'], equals('2026-10-11T10:00:00.000Z'));
    });

    test(
      'registering existing device preserves original registeredAt timestamp',
      () async {
        await registry.register(deviceA, appVersion: '0.3.0');

        // Move clock forward 2 days
        clock.advance(const Duration(days: 2));
        await registry.register(deviceA, appVersion: '0.3.1');

        final raw = await provider.get(
          RemoteLayout.deviceInfo(deviceA.deviceId),
        );
        final json = jsonDecode(
          utf8.decode(await cipher.open(raw, ObjectPurpose.device)),
        ) as Map<String, Object?>;

        expect(json['registeredAt'], equals('2026-10-11T10:00:00.000Z'));
        expect(json['updatedAt'], equals('2026-10-13T10:00:00.000Z'));
        expect(json['appVersion'], equals('0.3.1'));
      },
    );

    test('heartbeat throttles writes to at most once per hour', () async {
      await registry.register(deviceA);

      var putCount = 0;
      provider.beforeOp = (op, key) async {
        if (op == 'put' && key == RemoteLayout.deviceInfo(deviceA.deviceId)) {
          putCount++;
        }
      };

      // 1. Advance 30 minutes (< 1 hour): heartbeat should be throttled (no write)
      clock.advance(const Duration(minutes: 30));
      await registry.heartbeat(deviceA);
      expect(putCount, equals(0));

      // 2. Advance another 35 minutes (total 65 minutes > 1 hour): heartbeat writes
      clock.advance(const Duration(minutes: 35));
      await registry.heartbeat(deviceA);
      expect(putCount, equals(1));

      final raw = await provider.get(RemoteLayout.deviceInfo(deviceA.deviceId));
      final json = jsonDecode(
        utf8.decode(await cipher.open(raw, ObjectPurpose.device)),
      ) as Map<String, Object?>;
      expect(json['updatedAt'], equals('2026-10-11T11:05:00.000Z'));
      expect(json['registeredAt'], equals('2026-10-11T10:00:00.000Z'));
    });

    test('heartbeat on unregistered device registers it', () async {
      await registry.heartbeat(deviceB, appVersion: '0.3.0');

      final raw = await provider.get(RemoteLayout.deviceInfo(deviceB.deviceId));
      final json = jsonDecode(
        utf8.decode(await cipher.open(raw, ObjectPurpose.device)),
      ) as Map<String, Object?>;
      expect(json['deviceId'], equals(deviceB.deviceId));
      expect(json['deviceName'], equals('Workstation'));
    });

    test('revoke writes revocation file and second revocation is a no-op (first stands)', () async {
      await registry.register(deviceA);

      await registry.revoke(deviceA.deviceId, 150, revokedBy: deviceB.deviceId);

      final revKey = RemoteLayout.deviceRevocation(deviceA.deviceId);
      final raw = await provider.get(revKey);
      final json = jsonDecode(
        utf8.decode(await cipher.open(raw, ObjectPurpose.device)),
      ) as Map<String, Object?>;

      expect(json['v'], equals(1));
      expect(json['deviceId'], equals(deviceA.deviceId));
      expect(json['revokedBy'], equals(deviceB.deviceId));
      expect(json['revokedAt'], equals('2026-10-11T10:00:00.000Z'));
      expect(json['lastAcceptedSeq'], equals(150));

      // Second revocation attempt with different parameters should NOT overwrite
      clock.advance(const Duration(hours: 5));
      await registry.revoke(
        deviceA.deviceId,
        999,
        revokedBy: 'other-device-id',
      );

      final rawAfter = await provider.get(revKey);
      final jsonAfter = jsonDecode(
        utf8.decode(await cipher.open(rawAfter, ObjectPurpose.device)),
      ) as Map<String, Object?>;

      expect(jsonAfter['revokedBy'], equals(deviceB.deviceId));
      expect(jsonAfter['revokedAt'], equals('2026-10-11T10:00:00.000Z'));
      expect(jsonAfter['lastAcceptedSeq'], equals(150));
    });

    test('listDevices merges registration and revocation metadata', () async {
      await registry.register(deviceA);
      clock.advance(const Duration(minutes: 10));
      await registry.register(deviceB);

      // Initially neither is revoked
      var list = await registry.listDevices();
      expect(list.length, equals(2));
      expect(list[0].deviceId, equals(deviceA.deviceId));
      expect(list[0].revoked, isFalse);
      expect(list[1].deviceId, equals(deviceB.deviceId));
      expect(list[1].revoked, isFalse);

      // Revoke deviceA
      clock.advance(const Duration(minutes: 5));
      await registry.revoke(deviceA.deviceId, 42, revokedBy: deviceB.deviceId);

      list = await registry.listDevices();
      expect(list.length, equals(2));

      final devA = list.firstWhere((d) => d.deviceId == deviceA.deviceId);
      expect(devA.revoked, isTrue);
      expect(devA.revokedBy, equals(deviceB.deviceId));
      expect(devA.revokedAt, equals(DateTime.utc(2026, 10, 11, 10, 15)));
      expect(devA.lastAcceptedSeq, equals(42));

      final devB = list.firstWhere((d) => d.deviceId == deviceB.deviceId);
      expect(devB.revoked, isFalse);
      expect(devB.revokedBy, isNull);
    });

    test(
      'DeviceRegistry works with PlaintextObjectCipher in unencrypted vaults',
      () async {
        final plainRegistry = DeviceRegistry(
          provider,
          const PlaintextObjectCipher(),
          clock: clock,
        );

        await plainRegistry.register(deviceA);
        final list = await plainRegistry.listDevices();
        expect(list.length, equals(1));
        expect(list.first.deviceId, equals(deviceA.deviceId));
        expect(list.first.deviceName, equals('Pixel 8'));
      },
    );
  });
}
