// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tephra/core/platform/notification_service.dart';
import 'package:tephra/core/sync/headless_sync_runner.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_sync/tephra_sync.dart';
import 'package:tephra_vault/tephra_vault.dart';

class FakeNotificationService implements NotificationService {
  final List<({int id, String title, String body, String? payload})> shown = [];

  @override
  Future<void> init() async {}

  @override
  Future<NotificationPermissionState> permissionState() async =>
      const NotificationPermissionState(notifications: true, exactAlarms: true);

  @override
  Future<bool> requestNotificationPermission() async => true;

  @override
  Future<bool> requestExactAlarmPermission() async => true;

  @override
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    shown.add((id: id, title: title, body: body, payload: payload));
  }

  @override
  Future<void> schedule(ScheduledReminder reminder) async {}

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> showQuickNoteNotification() async {}

  @override
  Future<void> hideQuickNoteNotification() async {}

  @override
  Stream<String> get taps => const Stream.empty();

  @override
  Future<String?> launchPayload() async => null;
}

class SettableClock implements Clock {
  SettableClock(this.current);
  DateTime current;

  @override
  DateTime now() => current;
}

class MemorySecretStore implements SecretStore {
  final Map<String, String> data = {};

  @override
  Future<void> delete(String key) async => data.remove(key);

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async => data[key] = value;
}

void main() {
  late Directory tempDir;
  late Directory syncDir;
  late FakeNotificationService notificationService;
  late MemorySecretStore secretStore;
  late SettableClock clock;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('headless_sync_test_');
    syncDir = Directory(p.join(tempDir.path, 'sync'))..createSync();
    notificationService = FakeNotificationService();
    secretStore = MemorySecretStore();
    clock = SettableClock(DateTime.utc(2026, 10, 20, 10, 0, 0));
  });

  tearDown(() async {
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  Future<File> createVaultDb({
    required String vaultId,
    required String remoteVaultId,
    String mode = 'sync',
    bool backgroundSync = true,
    bool encrypted = false,
  }) async {
    final dbFile = File(p.join(syncDir.path, '$vaultId.sqlite'));
    final store = await SyncStateStore.open(dbFile.path);
    await store.setMeta('mode', mode);
    await store.setMeta('backgroundSync', backgroundSync ? 'true' : 'false');
    await store.setMeta('vaultRootPath', tempDir.path);
    await store.setMeta('remoteVaultId', remoteVaultId);
    await store.setMeta('deviceId', 'dev-1');
    await store.setMeta('deviceName', 'Device One');
    await store.setMeta('providerId', 'memory');
    await store.setMeta('encrypted', encrypted ? 'true' : 'false');
    await store.close();
    return dbFile;
  }

  test('skips vaults with backgroundSync = false', () async {
    await createVaultDb(
      vaultId: 'v1',
      remoteVaultId: 'rem-1',
      backgroundSync: false,
    );

    var engineRunCalled = false;
    final runner = HeadlessSyncRunner(
      syncDir: syncDir,
      notificationService: notificationService,
      secretStore: secretStore,
      clock: clock,
      fsFactory: (root) => MemoryVaultFileSystem(),
      providerOverride: MemorySyncProvider(),
      engineRunner:
          ({
            required cancelToken,
            required cipher,
            required deviceIdentity,
            required fs,
            required provider,
            required remoteVaultId,
            required store,
            required trigger,
          }) async {
            engineRunCalled = true;
            return const SyncReport(duration: Duration.zero);
          },
    );

    final ok = await runner.runAll();
    expect(ok, isTrue);
    expect(engineRunCalled, isFalse);
  });

  test('skips encrypted vault when master key is missing', () async {
    await createVaultDb(vaultId: 'v2', remoteVaultId: 'rem-2', encrypted: true);

    var engineRunCalled = false;
    final runner = HeadlessSyncRunner(
      syncDir: syncDir,
      notificationService: notificationService,
      secretStore: secretStore, // no key stored
      clock: clock,
      fsFactory: (root) => MemoryVaultFileSystem(),
      providerOverride: MemorySyncProvider(),
      engineRunner:
          ({
            required cancelToken,
            required cipher,
            required deviceIdentity,
            required fs,
            required provider,
            required remoteVaultId,
            required store,
            required trigger,
          }) async {
            engineRunCalled = true;
            return const SyncReport(duration: Duration.zero);
          },
    );

    final ok = await runner.runAll();
    expect(ok, isTrue);
    expect(engineRunCalled, isFalse);
  });

  test('handles SyncLockedException silently', () async {
    await createVaultDb(
      vaultId: 'v3',
      remoteVaultId: 'rem-3',
      encrypted: false,
    );

    final runner = HeadlessSyncRunner(
      syncDir: syncDir,
      notificationService: notificationService,
      secretStore: secretStore,
      clock: clock,
      fsFactory: (root) => MemoryVaultFileSystem(),
      providerOverride: MemorySyncProvider(),
      engineRunner:
          ({
            required cancelToken,
            required cipher,
            required deviceIdentity,
            required fs,
            required provider,
            required remoteVaultId,
            required store,
            required trigger,
          }) async {
            throw const SyncLockedException();
          },
    );

    final ok = await runner.runAll();
    expect(ok, isTrue);
  });

  test('AuthRevokedException sets needsAttention status and throttles notification to 24h', () async {
    final dbFile = await createVaultDb(
      vaultId: 'v4',
      remoteVaultId: 'rem-4',
      encrypted: false,
    );

    final runner = HeadlessSyncRunner(
      syncDir: syncDir,
      notificationService: notificationService,
      secretStore: secretStore,
      clock: clock,
      fsFactory: (root) => MemoryVaultFileSystem(),
      providerOverride: MemorySyncProvider(),
      tokenSourceFactory: () => throw const AuthRevokedException(),
      engineRunner:
          ({
            required cancelToken,
            required cipher,
            required deviceIdentity,
            required fs,
            required provider,
            required remoteVaultId,
            required store,
            required trigger,
          }) async {
            throw const AuthRevokedException();
          },
    );

    // Run 1: fires first notification
    final ok1 = await runner.runAll();
    expect(ok1, isTrue);
    expect(notificationService.shown.length, 1);
    expect(
      notificationService.shown.first.body,
      contains('reconnect Google Drive'),
    );

    final store = await SyncStateStore.open(dbFile.path);
    expect(await store.getMeta('status'), 'needsAttention');
    expect(
      await store.getMeta('lastNotificationAt'),
      clock.now().toIso8601String(),
    );
    await store.close();

    // Run 2: advance clock by 5 hours (< 24h) -> no new notification
    clock.current = clock.current.add(const Duration(hours: 5));
    final ok2 = await runner.runAll();
    expect(ok2, isTrue);
    expect(notificationService.shown.length, 1);

    // Run 3: advance clock by 20 hours (total 25h > 24h) -> notification fires again
    clock.current = clock.current.add(const Duration(hours: 20));
    final ok3 = await runner.runAll();
    expect(ok3, isTrue);
    expect(notificationService.shown.length, 2);
  });

  test('cancels active cycle when budget expires', () async {
    await createVaultDb(
      vaultId: 'v5',
      remoteVaultId: 'rem-5',
      encrypted: false,
    );

    var cancelObserved = false;
    final runner = HeadlessSyncRunner(
      syncDir: syncDir,
      notificationService: notificationService,
      secretStore: secretStore,
      clock: clock,
      fsFactory: (root) => MemoryVaultFileSystem(),
      providerOverride: MemorySyncProvider(),
      engineRunner:
          ({
            required cancelToken,
            required cipher,
            required deviceIdentity,
            required fs,
            required provider,
            required remoteVaultId,
            required store,
            required trigger,
          }) async {
            final sw = Stopwatch()..start();
            while (!cancelToken.isCancelled && sw.elapsedMilliseconds < 1000) {
              await Future<void>.delayed(const Duration(milliseconds: 10));
            }
            if (cancelToken.isCancelled) {
              cancelObserved = true;
            }
            return SyncReport(duration: sw.elapsed);
          },
    );

    final ok = await runner.runAll(budget: const Duration(milliseconds: 50));
    expect(ok, isTrue);
    expect(cancelObserved, isTrue);
  });
}
