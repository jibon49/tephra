// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_sync/tephra_sync.dart';
import 'package:tephra_vault/tephra_vault.dart';

/// Wraps a [SyncProvider] to allow toggling network availability on or off.
final class OfflineSwitch implements SyncProvider {
  OfflineSwitch(this.underlying);

  final SyncProvider underlying;
  bool isOnline = true;

  void _checkOnline() {
    if (!isOnline) {
      throw const NetworkUnavailableException();
    }
  }

  @override
  String get id => underlying.id;

  @override
  Future<void> connect() async {
    _checkOnline();
    return underlying.connect();
  }

  @override
  Future<void> delete(String key) async {
    _checkOnline();
    return underlying.delete(key);
  }

  @override
  Future<List<int>> get(String key) async {
    _checkOnline();
    return underlying.get(key);
  }

  @override
  Future<List<RemoteObject>> list(String prefix) async {
    _checkOnline();
    return underlying.list(prefix);
  }

  @override
  Future<void> put(String key, List<int> bytes) async {
    _checkOnline();
    return underlying.put(key, bytes);
  }

  @override
  Future<Quota?> quota() async {
    _checkOnline();
    return underlying.quota();
  }

  @override
  Future<RemoteChanges> changesSince(String? cursor) async {
    _checkOnline();
    return underlying.changesSince(cursor);
  }
}

/// Simulated client device with its own filesystem, database store, lock, and history.
final class SimDevice {
  SimDevice({
    required this.name,
    required this.identity,
    required this.isWindows,
    required this.fs,
    required this.store,
    required this.offlineSwitch,
    required this.cipher,
    required this.remoteVaultId,
    required this.clock,
  }) : lock = MemorySyncLock(),
       localHistory = LocalHistory(fs, clock, Duration.zero);

  final String name;
  DeviceIdentity identity;
  final bool isWindows;
  final VaultFileSystem fs;
  final SyncStateStore store;
  final OfflineSwitch offlineSwitch;
  final ObjectCipher cipher;
  final String remoteVaultId;
  final ManualClock clock;
  final MemorySyncLock lock;
  final LocalHistory localHistory;

  SyncEngine _createEngine({CrashInjector? crashInjector}) {
    return SyncEngine(
      fs: fs,
      provider: offlineSwitch,
      store: store,
      cipher: cipher,
      remoteVaultId: remoteVaultId,
      device: identity,
      lock: lock,
      clock: clock,
      crashInjector: crashInjector,
      localHistory: localHistory,
    );
  }

  /// Performs a sync cycle on this device.
  ///
  /// Re-creates a fresh engine instance each time to ensure restart safety.
  /// Catches and rethrows [SimulatedCrash] or [NetworkUnavailableException] as expected.
  Future<SyncReport?> syncOnce({CrashInjector? crashInjector}) async {
    final engine = _createEngine(crashInjector: crashInjector);
    try {
      final report = await engine.syncOnce();
      identity = engine.device;
      return report;
    } finally {
      await engine.dispose();
    }
  }

  /// Automatically approves any held deletes pending user confirmation on this device.
  Future<void> approveHeldDeletes() async {
    final metaHeld = await store.getMeta('heldDeletes');
    if (metaHeld != null && metaHeld.isNotEmpty) {
      try {
        final paths = (jsonDecode(metaHeld) as List<dynamic>).cast<String>();
        if (paths.isNotEmpty) {
          final decisions = {
            for (final p in paths) VaultPath(p): DeleteDecision.approve,
          };
          final engine = _createEngine();
          try {
            await engine.decideHeldDeletes(decisions);
          } finally {
            await engine.dispose();
          }
        }
      } catch (_) {
        // Ignored in simulator
      }
    }
  }
}
