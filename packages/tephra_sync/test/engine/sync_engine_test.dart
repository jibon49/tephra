// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_sync/tephra_sync.dart';
import 'package:tephra_vault/tephra_vault.dart';
import 'package:test/test.dart';

void main() {
  group('SyncEngine', () {
    late MemorySyncProvider provider;
    late PlaintextObjectCipher cipher;

    late MemoryVaultFileSystem fsA;
    late SyncStateStore storeA;
    late MemorySyncLock lockA;
    late DeviceIdentity deviceA;

    late MemoryVaultFileSystem fsB;
    late SyncStateStore storeB;
    late MemorySyncLock lockB;
    late DeviceIdentity deviceB;

    SyncEngine buildEngineA({CrashInjector? crashInjector}) {
      return SyncEngine(
        fs: fsA,
        provider: provider,
        store: storeA,
        cipher: cipher,
        remoteVaultId: 'test_vault',
        device: deviceA,
        lock: lockA,
        crashInjector: crashInjector,
      );
    }

    SyncEngine buildEngineB({CrashInjector? crashInjector}) {
      return SyncEngine(
        fs: fsB,
        provider: provider,
        store: storeB,
        cipher: cipher,
        remoteVaultId: 'test_vault',
        device: deviceB,
        lock: lockB,
        crashInjector: crashInjector,
      );
    }

    setUp(() async {
      provider = MemorySyncProvider();
      cipher = PlaintextObjectCipher();

      fsA = MemoryVaultFileSystem();
      storeA = await SyncStateStore.openMemory();
      lockA = MemorySyncLock();
      deviceA = const DeviceIdentity(
        deviceId: '11111111-1111-4111-8111-111111111111',
        deviceName: 'Device A',
        platform: 'windows',
      );

      fsB = MemoryVaultFileSystem();
      storeB = await SyncStateStore.openMemory();
      lockB = MemorySyncLock();
      deviceB = const DeviceIdentity(
        deviceId: '22222222-2222-4222-8222-222222222222',
        deviceName: 'Device B',
        platform: 'android',
      );
    });

    tearDown(() async {
      await storeA.close();
      await storeB.close();
    });

    test('two devices round trips: create, edit, rename, delete', () async {
      final engineA = buildEngineA();
      final engineB = buildEngineB();

      // 1. Create on A
      final notePath = VaultPath('welcome.md');
      await fsA.writeBytes(
        notePath,
        utf8.encode('# Welcome to Tephra\nFirst line.\n'),
      );
      final reportA1 = await engineA.syncOnce();
      expect(reportA1.uploaded, equals(1));

      // Sync on B -> downloads note
      final reportB1 = await engineB.syncOnce();
      expect(reportB1.downloaded, equals(1));
      expect(await fsB.stat(notePath), isNotNull);
      expect(
        utf8.decode(await fsB.readBytes(notePath)),
        equals('# Welcome to Tephra\nFirst line.\n'),
      );

      // 2. Edit on B
      await fsB.writeBytes(
        notePath,
        utf8.encode('# Welcome to Tephra\nFirst line.\nSecond line.\n'),
      );
      final reportB2 = await engineB.syncOnce();
      expect(reportB2.uploaded, equals(1));

      // Sync on A -> downloads edited note
      final reportA2 = await engineA.syncOnce();
      expect(reportA2.downloaded, equals(1));
      expect(
        utf8.decode(await fsA.readBytes(notePath)),
        equals('# Welcome to Tephra\nFirst line.\nSecond line.\n'),
      );

      // 3. Rename on A: welcome.md -> intro.md
      final newPath = VaultPath('intro.md');
      await fsA.move(notePath, newPath);
      final reportA3 = await engineA.syncOnce();
      expect(
        reportA3.uploaded,
        equals(0),
      ); // rename publishes move, not blob upload

      // Sync on B -> applies rename locally
      final reportB3 = await engineB.syncOnce();
      expect(reportB3.renamed, equals(1));
      expect(await fsB.stat(notePath), isNull);
      expect(await fsB.stat(newPath), isNotNull);
      expect(
        utf8.decode(await fsB.readBytes(newPath)),
        equals('# Welcome to Tephra\nFirst line.\nSecond line.\n'),
      );

      // 4. Delete on B
      await fsB.delete(newPath, mode: TrashMode.vaultTrash);
      final reportB4 = await engineB.syncOnce();
      expect(reportB4.deletedRemote, equals(1));

      // Sync on A -> applies deletion
      final reportA4 = await engineA.syncOnce();
      expect(reportA4.deletedLocal, equals(1));
      expect(await fsA.stat(newPath), isNull);

      await engineA.dispose();
      await engineB.dispose();
    });

    test('mutual exclusion: SyncLockedException if lock held', () async {
      await lockA.tryAcquire();
      final engine = buildEngineA();
      expect(() => engine.syncOnce(), throwsA(isA<SyncLockedException>()));
      await lockA.release();
      await engine.dispose();
    });

    test(
      'cancel mid-cycle exits gracefully without corrupting state',
      () async {
        final token = SyncCancelToken()..cancel();
        final engine = buildEngineA();
        final report = await engine.syncOnce(cancel: token);
        expect(report, isNotNull);
        expect(lockA.isHeld, isFalse);
        await engine.dispose();
      },
    );

    test(
      'quota exceeded mid-upload preserves local phase and retries cleanly',
      () async {
        final path = VaultPath('large.md');
        await fsA.writeBytes(path, utf8.encode('Large content to sync'));

        // Set quota limit to 0 bytes to simulate quota exceeded
        provider.quotaLimitBytes = 0;

        final engineA = buildEngineA();
        final report = await engineA.syncOnce();
        expect(report.errors, isNotEmpty);
        expect(report.uploaded, equals(0));

        // Local file is intact
        expect(await fsA.stat(path), isNotNull);

        // Raise quota and retry
        provider.quotaLimitBytes = 100 * 1024 * 1024;
        final retryReport = await engineA.syncOnce();
        expect(retryReport.uploaded, equals(1));

        // Device B receives it cleanly
        final engineB = buildEngineB();
        final reportB = await engineB.syncOnce();
        expect(reportB.downloaded, equals(1));
        expect(await fsB.stat(path), isNotNull);

        await engineA.dispose();
        await engineB.dispose();
      },
    );

    group('Crash recovery for every CrashPoint', () {
      for (final point in CrashPoint.values) {
        test('recovers cleanly after crashing at $point', () async {
          final testPath = VaultPath('note_${point.name}.md');
          final content = utf8.encode('Crash test for point ${point.name}');
          await fsA.writeBytes(testPath, content);

          final isLocalWritePoint =
              point == CrashPoint.beforeLocalWrite ||
              point == CrashPoint.afterLocalWrite ||
              point == CrashPoint.afterLocalStateUpdate;

          if (isLocalWritePoint) {
            // A publishes cleanly
            final engineA = buildEngineA();
            final rA = await engineA.syncOnce();
            expect(rA.uploaded, equals(1));
            await engineA.dispose();

            // B crashes while receiving
            var didCrash = false;
            final crashingEngineB = buildEngineB(
              crashInjector: (p, path) {
                if (p == point) {
                  didCrash = true;
                  throw SimulatedCrash(p, path);
                }
              },
            );

            try {
              await crashingEngineB.syncOnce();
            } on SimulatedCrash catch (e) {
              expect(e.point, equals(point));
            } finally {
              await crashingEngineB.dispose();
            }

            expect(
              didCrash,
              isTrue,
              reason: 'Crash point $point was not triggered',
            );

            // Fresh B recovers and completes
            final freshEngineB = buildEngineB();
            await freshEngineB.syncOnce();
            await freshEngineB.dispose();
          } else {
            // A crashes during upload or cycle orchestration
            var didCrash = false;
            final crashingEngine = buildEngineA(
              crashInjector: (p, path) {
                if (p == point) {
                  didCrash = true;
                  throw SimulatedCrash(p, path);
                }
              },
            );

            try {
              await crashingEngine.syncOnce();
            } on SimulatedCrash catch (e) {
              expect(e.point, equals(point));
            } finally {
              await crashingEngine.dispose();
            }

            expect(
              didCrash,
              isTrue,
              reason: 'Crash point $point was not triggered',
            );

            // Build fresh engines on the same fs and stores
            final freshEngineA = buildEngineA();
            final engineB = buildEngineB();

            // Recover and complete cycles
            await freshEngineA.syncOnce();
            await engineB.syncOnce();

            await freshEngineA.dispose();
            await engineB.dispose();
          }

          // Assert convergence: both devices must have the file with identical content
          expect(await fsA.stat(testPath), isNotNull);
          expect(await fsB.stat(testPath), isNotNull);

          final contentA = await fsA.readBytes(testPath);
          final contentB = await fsB.readBytes(testPath);
          expect(contentA, equals(contentB));
        });
      }
    });
  });
}
