// © 2026 Tephra. All rights reserved.

import 'dart:math';

import 'package:drift/drift.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_sync/tephra_sync.dart';
import 'package:tephra_vault/tephra_vault.dart';

import 'invariants.dart';
import 'sim_device.dart';

/// Simulated world comprising 3 devices, shared remote storage, clock, and metrics.
final class SimWorld {
  SimWorld._(this.seed) : random = Random(seed);

  final int seed;
  final Random random;
  late final ManualClock clock;
  late final MemorySyncProvider provider;
  late final ObjectCipher cipher;
  late final List<SimDevice> devices;

  static const String defaultRemoteVaultId =
      '6f1c2a9e-3b0d-4c8e-9a51-2d7f0e4b8c11';

  final Map<String, List<int>> mustSurvive = {};
  final List<String> opLog = [];
  int opCount = 0;

  /// Creates and initializes a new [SimWorld] instance.
  static Future<SimWorld> create(int seed) async {
    final world = SimWorld._(seed);
    await world._init();
    return world;
  }

  Future<void> _init() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    clock = ManualClock(DateTime.utc(2026, 10, 15, 12, 0));
    provider = MemorySyncProvider();
    await provider.connect();

    cipher = EncryptingObjectCipher(
      masterKey: SecretKey(Uint8List(32)),
      vaultId: defaultRemoteVaultId,
    );

    // Device A: Android (case-sensitive, isWindows: false)
    final fsA = MemoryVaultFileSystem(caseInsensitive: false);
    final storeA = await SyncStateStore.openMemory();
    final devA = SimDevice(
      name: 'A',
      identity: const DeviceIdentity(
        deviceId: '00000000-0000-4000-8000-000000000001',
        deviceName: 'Pixel 8',
        platform: 'android',
      ),
      isWindows: false,
      fs: fsA,
      store: storeA,
      offlineSwitch: OfflineSwitch(provider),
      cipher: cipher,
      remoteVaultId: defaultRemoteVaultId,
      clock: clock,
    );

    // Device B: Windows (case-insensitive, isWindows: true)
    final fsB = MemoryVaultFileSystem(caseInsensitive: true);
    final storeB = await SyncStateStore.openMemory();
    final devB = SimDevice(
      name: 'B',
      identity: const DeviceIdentity(
        deviceId: '00000000-0000-4000-8000-000000000002',
        deviceName: 'Desktop PC',
        platform: 'windows',
      ),
      isWindows: true,
      fs: fsB,
      store: storeB,
      offlineSwitch: OfflineSwitch(provider),
      cipher: cipher,
      remoteVaultId: defaultRemoteVaultId,
      clock: clock,
    );

    // Device C: Windows (case-insensitive, isWindows: true)
    final fsC = MemoryVaultFileSystem(caseInsensitive: true);
    final storeC = await SyncStateStore.openMemory();
    final devC = SimDevice(
      name: 'C',
      identity: const DeviceIdentity(
        deviceId: '00000000-0000-4000-8000-000000000003',
        deviceName: 'Laptop',
        platform: 'windows',
      ),
      isWindows: true,
      fs: fsC,
      store: storeC,
      offlineSwitch: OfflineSwitch(provider),
      cipher: cipher,
      remoteVaultId: defaultRemoteVaultId,
      clock: clock,
    );

    devices = [devA, devB, devC];
  }

  /// Advances the simulated clock by 1 to 5,000 ms.
  void advanceClock() {
    clock.advance(Duration(milliseconds: 1 + random.nextInt(5000)));
  }

  /// Records an operation description in the log.
  void logOp(String desc) {
    opCount++;
    opLog.add('[$opCount] $desc');
  }

  /// Returns a random device.
  SimDevice randomDevice() => devices[random.nextInt(devices.length)];

  /// Returns a random currently online device, or null if all are offline.
  SimDevice? randomOnlineDevice() {
    final online = devices.where((d) => d.offlineSwitch.isOnline).toList();
    if (online.isEmpty) return null;
    return online[random.nextInt(online.length)];
  }

  /// Lists all paths on [dev] participating in sync.
  Future<List<VaultPath>> listParticipatingFiles(SimDevice dev) async {
    const rules = SelectiveSyncRules();
    final entries = await dev.fs.list(recursive: true);
    final result = <VaultPath>[];
    for (final e in entries) {
      if (!e.isFolder && SyncPathRules.participates(e.path, e.size, rules)) {
        result.add(e.path);
      }
    }
    return result;
  }

  /// Lists participating Markdown notes on [dev].
  Future<List<VaultPath>> listParticipatingNotes(SimDevice dev) async {
    final all = await listParticipatingFiles(dev);
    return all.where((p) => p.extension == 'md').toList();
  }

  /// Lists participating binary files on [dev].
  Future<List<VaultPath>> listParticipatingBinaries(SimDevice dev) async {
    final all = await listParticipatingFiles(dev);
    return all.where((p) => p.extension != 'md').toList();
  }

  final Map<String, (DateTime, String)> _fileHashCache = {};

  /// Records every participating file on [dev] into [mustSurvive] before a sync.
  Future<void> recordMustSurvive(SimDevice dev) async {
    final files = await listParticipatingFiles(dev);
    for (final path in files) {
      final stat = await dev.fs.stat(path);
      if (stat == null) continue;
      final cacheKey = '${dev.name}:${path.value}';
      final cached = _fileHashCache[cacheKey];
      if (cached != null && cached.$1 == stat.modified) {
        continue;
      }
      final bytes = await dev.fs.readBytes(path);
      final hash = contentHash(bytes);
      _fileHashCache[cacheKey] = (stat.modified, hash);
      mustSurvive[hash] = bytes;
    }
  }

  /// Executes a single sync cycle on [dev], recording [mustSurvive] first.
  Future<void> syncDevice(SimDevice dev, {CrashPoint? crashPoint}) async {
    await recordMustSurvive(dev);
    try {
      CrashInjector? injector;
      if (crashPoint != null) {
        injector = (p, path) {
          if (p == crashPoint) {
            throw SimulatedCrash(p, path);
          }
        };
      }
      final report = await dev.syncOnce(crashInjector: injector);
      logOp('syncOnce on ${dev.name} (crash: $crashPoint) -> $report');
    } on SimulatedCrash catch (e) {
      logOp('syncOnce on ${dev.name} crashed at ${e.point}');
    } on NetworkUnavailableException {
      logOp('syncOnce on ${dev.name} skipped: network unavailable');
    }

    await dev.approveHeldDeletes();
  }

  /// Brings all devices online and syncs until all devices apply zero actions.
  Future<void> convergeAll({int maxRounds = 10}) async {
    for (final dev in devices) {
      dev.offlineSwitch.isOnline = true;
      await dev.approveHeldDeletes();
    }

    final roundReports = <String>[];
    var round = 0;
    while (round < maxRounds) {
      round++;
      var totalActions = 0;

      for (final dev in devices) {
        await dev.approveHeldDeletes();
        await recordMustSurvive(dev);
        final report = await dev.syncOnce();
        if (report != null) {
          roundReports.add(
            'round $round dev ${dev.name}: $report errors: ${report.errors}',
          );
          final actions =
              report.uploaded +
              report.downloaded +
              report.merged +
              report.conflicts +
              report.deletedLocal +
              report.deletedRemote +
              report.renamed +
              report.heldDeletes;
          totalActions += actions;
        }
      }

      if (totalActions == 0) {
        return; // All devices converged!
      }
    }

    throw InvariantViolationException(
      'Failed to converge after $maxRounds rounds:\n${roundReports.join('\n')}',
    );
  }

  /// Closes database connections and resources on all devices.
  Future<void> close() async {
    for (final dev in devices) {
      await dev.store.close();
    }
  }
}
