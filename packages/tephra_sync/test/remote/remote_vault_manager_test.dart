// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:typed_data';

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_sync/tephra_sync.dart';
import 'package:test/test.dart';

void main() {
  group('RemoteVaultManager', () {
    late MemorySyncProvider provider;
    late ManualClock clock;
    late RemoteVaultManager manager;

    final device = DeviceIdentity(
      deviceId: '11111111-1111-4111-8111-111111111111',
      deviceName: 'Pixel 8',
      platform: 'android',
    );

    // Fast floor override for rapid unit tests
    final fastFloor = KdfParams(
      memoryKiB: 1024,
      iterations: 1,
      parallelism: 1,
      salt: Uint8List(16),
      calibratedMs: 0,
    );

    setUp(() async {
      provider = MemorySyncProvider();
      await provider.connect();
      clock = ManualClock(DateTime.utc(2026, 10, 11, 12, 0));
      manager = RemoteVaultManager(
        provider,
        clock: clock,
        floorOverride: fastFloor,
      );
    });

    test('create encrypted vault -> unlock with password gives same master key bytes', () async {
      final created = await manager.create(
        vaultName: 'Personal Notes',
        password: 'correct-horse-battery-staple',
        device: device,
        isAndroid: false,
      );

      expect(created.header.vaultName, equals('Personal Notes'));
      expect(created.header.isEncrypted, isTrue);
      expect(created.masterKey, isNotNull);
      expect(created.recoveryKeyDisplay, isNotNull);

      final header = await manager.readHeader();
      expect(header.vaultId, equals(created.header.vaultId));

      final unlockedKey = await manager.unlockWithPassword(
        header,
        'correct-horse-battery-staple',
      );

      final createdBytes = await created.masterKey!.extractBytes();
      final unlockedBytes = await unlockedKey.extractBytes();
      expect(unlockedBytes, equals(createdBytes));
    });

    test('unlock with recovery key gives same master key bytes', () async {
      final created = await manager.create(
        vaultName: 'Recovery Test Vault',
        password: 'secret-password',
        device: device,
        isAndroid: false,
      );

      final header = await manager.readHeader();
      final recoveryUnlocked = await manager.unlockWithRecoveryKey(
        header,
        created.recoveryKeyDisplay!,
      );

      final createdBytes = await created.masterKey!.extractBytes();
      final recoveryBytes = await recoveryUnlocked.extractBytes();
      expect(recoveryBytes, equals(createdBytes));
    });

    test('wrong password throws WrongPasswordException', () async {
      await manager.create(
        vaultName: 'Auth Failure Vault',
        password: 'actual-password',
        device: device,
        isAndroid: false,
      );

      final header = await manager.readHeader();
      expect(
        () => manager.unlockWithPassword(header, 'wrong-password'),
        throwsA(isA<WrongPasswordException>()),
      );
    });

    test('wrong recovery key throws WrongRecoveryKeyException', () async {
      await manager.create(
        vaultName: 'Recovery Failure Vault',
        password: 'actual-password',
        device: device,
        isAndroid: false,
      );

      final header = await manager.readHeader();

      // Corrupt or invalid recovery key string
      expect(
        () => manager.unlockWithRecoveryKey(
          header,
          'INVALID-KEY-STRING-TOO-SHORT',
        ),
        throwsA(isA<WrongRecoveryKeyException>()),
      );
    });

    test(
      'create unencrypted vault -> encryption is none and device is registered',
      () async {
        final created = await manager.create(
          vaultName: 'Plain Vault',
          password: null,
          device: device,
          isAndroid: false,
        );

        expect(created.header.isEncrypted, isFalse);
        expect(created.header.encryption, equals('none'));
        expect(created.masterKey, isNull);
        expect(created.recoveryKeyDisplay, isNull);

        final header = await manager.readHeader();
        expect(header.isEncrypted, isFalse);

        final registry = DeviceRegistry(
          provider,
          const PlaintextObjectCipher(),
          clock: clock,
        );
        final devices = await registry.listDevices();
        expect(devices.length, equals(1));
        expect(devices.first.deviceId, equals(device.deviceId));
      },
    );

    test('vault.json is written strictly after the device file', () async {
      var deviceFileExistedWhenVaultJsonPut = false;

      provider.beforeOp = (op, key) async {
        if (op == 'put' && key == RemoteLayout.vaultHeader) {
          try {
            await provider.get(RemoteLayout.deviceInfo(device.deviceId));
            deviceFileExistedWhenVaultJsonPut = true;
          } catch (_) {
            deviceFileExistedWhenVaultJsonPut = false;
          }
        }
      };

      await manager.create(
        vaultName: 'Order Test Vault',
        password: 'order-test-password',
        device: device,
        isAndroid: false,
      );

      expect(deviceFileExistedWhenVaultJsonPut, isTrue);
    });

    test('changePassword re-wraps master key: old fails, new works, recovery works, blob still decrypts', () async {
      final created = await manager.create(
        vaultName: 'Rekey Test',
        password: 'initial-password-1',
        device: device,
        isAndroid: false,
      );

      // Create an encrypted blob using masterKey before password change
      final cipher = EncryptingObjectCipher(
        masterKey: created.masterKey!,
        vaultId: created.header.vaultId,
      );
      final plaintext = utf8.encode(
        'Top Secret Note Content Before Password Change',
      );
      final sealedBlob = await cipher.seal(plaintext, ObjectPurpose.blob);

      // Change password
      clock.advance(const Duration(hours: 2));
      await manager.changePassword(
        h: created.header,
        masterKey: created.masterKey!,
        newPassword: 'updated-password-2',
        isAndroid: false,
      );

      final updatedHeader = await manager.readHeader();
      expect(updatedHeader.updatedAt, equals(clock.now().toUtc()));

      // 1. Old password fails
      expect(
        () => manager.unlockWithPassword(updatedHeader, 'initial-password-1'),
        throwsA(isA<WrongPasswordException>()),
      );

      // 2. New password works and recovers original master key
      final unlockedNew = await manager.unlockWithPassword(
        updatedHeader,
        'updated-password-2',
      );
      final unlockedNewBytes = await unlockedNew.extractBytes();
      final createdBytes = await created.masterKey!.extractBytes();
      expect(unlockedNewBytes, equals(createdBytes));

      // 3. Recovery key still works
      final unlockedRec = await manager.unlockWithRecoveryKey(
        updatedHeader,
        created.recoveryKeyDisplay!,
      );
      final unlockedRecBytes = await unlockedRec.extractBytes();
      expect(unlockedRecBytes, equals(createdBytes));

      // 4. Blob created before change still decrypts with the newly unlocked key
      final newCipher = EncryptingObjectCipher(
        masterKey: unlockedNew,
        vaultId: updatedHeader.vaultId,
      );
      final decrypted = await newCipher.open(sealedBlob, ObjectPurpose.blob);
      expect(
        utf8.decode(decrypted),
        equals('Top Secret Note Content Before Password Change'),
      );
    });

    test('regenerateRecoveryKey updates recovery key, old fails, new works, password still works', () async {
      final created = await manager.create(
        vaultName: 'Regen Recovery Test',
        password: 'my-password',
        device: device,
        isAndroid: false,
      );

      final oldRecovery = created.recoveryKeyDisplay!;

      // Regenerate recovery key
      clock.advance(const Duration(hours: 1));
      final newRecovery = await manager.regenerateRecoveryKey(
        h: created.header,
        masterKey: created.masterKey!,
      );

      expect(newRecovery, isNot(equals(oldRecovery)));

      final updatedHeader = await manager.readHeader();

      // 1. Old recovery key fails
      expect(
        () => manager.unlockWithRecoveryKey(updatedHeader, oldRecovery),
        throwsA(isA<WrongRecoveryKeyException>()),
      );

      // 2. New recovery key unlocks same master key
      final unlockedByNewRec = await manager.unlockWithRecoveryKey(
        updatedHeader,
        newRecovery,
      );
      expect(
        await unlockedByNewRec.extractBytes(),
        equals(await created.masterKey!.extractBytes()),
      );

      // 3. Password still works
      final unlockedByPw = await manager.unlockWithPassword(
        updatedHeader,
        'my-password',
      );
      expect(
        await unlockedByPw.extractBytes(),
        equals(await created.masterKey!.extractBytes()),
      );
    });

    test('unknown extra fields are preserved after changePassword', () async {
      final created = await manager.create(
        vaultName: 'Extra Fields Vault',
        password: 'password',
        device: device,
        isAndroid: false,
      );

      // Add unknown field to vault.json directly
      final headerWithExtra = created.header.copyWith(
        extraFields: {'serverSyncPolicy': 'eager', 'futureOption': 123},
      );
      await provider.put(
        RemoteLayout.vaultHeader,
        utf8.encode(headerWithExtra.toPrettyJson()),
      );

      // Read back with extra fields
      final loadedWithExtra = await manager.readHeader();
      expect(loadedWithExtra.extraFields['serverSyncPolicy'], equals('eager'));

      // Perform changePassword
      await manager.changePassword(
        h: loadedWithExtra,
        masterKey: created.masterKey!,
        newPassword: 'new-password',
        isAndroid: false,
      );

      // Verify extra fields survived changePassword rewrite
      final afterRekey = await manager.readHeader();
      expect(afterRekey.extraFields['serverSyncPolicy'], equals('eager'));
      expect(afterRekey.extraFields['futureOption'], equals(123));
    });

    test(
      'real floor Argon2id calibration and password unlock works end-to-end',
      () async {
        // Real floor test without floorOverride
        final realManager = RemoteVaultManager(
          provider,
          clock: clock,
          // no floorOverride: uses real floor (64 MiB, 3 iterations)
        );

        final created = await realManager.create(
          vaultName: 'Slow Floor Vault',
          password: 'real-floor-password',
          device: device,
          isAndroid: false,
        );

        final header = await realManager.readHeader();
        expect(header.kdf!.memoryKiB, equals(65536));
        expect(header.kdf!.iterations, equals(3));

        final unlocked = await realManager.unlockWithPassword(
          header,
          'real-floor-password',
        );

        expect(
          await unlocked.extractBytes(),
          equals(await created.masterKey!.extractBytes()),
        );
      },
      tags: ['slow'],
    );
  });
}
