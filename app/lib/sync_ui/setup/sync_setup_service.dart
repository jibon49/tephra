// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_sync/tephra_sync.dart';

import '../../core/sync/background_sync.dart';
import '../../core/sync/google_auth_service.dart';
import '../../core/sync/secure_secret_store.dart';
import '../../core/sync/sync_messages.dart';
import '../../core/sync/sync_paths.dart';

/// Statistics about local files participating in vault synchronization.
final class LocalVaultStats {
  const LocalVaultStats({required this.fileCount, required this.totalBytes});

  final int fileCount;
  final int totalBytes;
}

/// Result of creating a remote vault.
final class CreatedVaultResult {
  const CreatedVaultResult({
    required this.remoteVaultId,
    required this.vaultName,
    required this.encrypted,
    this.recoveryKeyDisplay,
  });

  final String remoteVaultId;
  final String vaultName;
  final bool encrypted;
  final String? recoveryKeyDisplay;
}

/// Choice made by the user on the first sync screen.
enum FirstSyncChoice { upload, download, merge, downloadToNewFolder }

/// Service managing remote vault discovery, creation, unlocking, and finalization.
abstract interface class SyncSetupService {
  Future<GoogleAccount?> currentAccount();
  Future<GoogleAccount> signInInteractive();
  Future<void> signOut();
  Future<List<RemoteVaultInfo>> listRemoteVaults();
  Future<CreatedVaultResult> createRemoteVault({
    required String vaultName,
    required bool encrypted,
    String? password,
    required DeviceIdentity device,
  });
  Future<void> unlockRemoteVault({
    required String remoteVaultId,
    required String vaultName,
    required bool encrypted,
    String? password,
    String? recoveryKey,
    required DeviceIdentity device,
  });
  Future<LocalVaultStats> getLocalVaultStats();
  Future<void> finalizeSetup({
    required String remoteVaultId,
    required String vaultName,
    required bool encrypted,
    required bool backgroundSync,
    required bool wifiOnly,
    required bool mobileMode,
    required DeviceIdentity device,
    required FirstSyncChoice choice,
    String? newFolderPath,
    bool backupOnly = false,
  });
  Future<void> disconnect({required bool signOutGoogle});
  Future<bool> isConfigured();
}

/// Production implementation of [SyncSetupService].
class DriveSyncSetupService implements SyncSetupService {
  DriveSyncSetupService({
    required this.vaultId,
    required this.localVaultRootPath,
    required GoogleAuthService googleAuthService,
    SecretStore? secretStore,
  }) : _auth = googleAuthService,
       _secretStore = secretStore ?? SecureSecretStore();

  final String vaultId;
  final String localVaultRootPath;
  final GoogleAuthService _auth;
  final SecretStore _secretStore;

  DriveVaultFinder _getFinder() {
    return DriveVaultFinder.fromTokenSource(_auth.tokens);
  }

  @override
  Future<GoogleAccount?> currentAccount() async {
    return _auth.currentAccount();
  }

  @override
  Future<GoogleAccount> signInInteractive() async {
    return _auth.signInInteractive();
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
  }

  @override
  Future<List<RemoteVaultInfo>> listRemoteVaults() async {
    final finder = _getFinder();
    return finder.listRemoteVaults();
  }

  @override
  Future<CreatedVaultResult> createRemoteVault({
    required String vaultName,
    required bool encrypted,
    String? password,
    required DeviceIdentity device,
  }) async {
    final finder = _getFinder();
    final remoteVaultId = generateUuidV4();
    await finder.createVaultFolders(vaultName, remoteVaultId);

    final provider = DriveSyncProvider(
      vaultId: remoteVaultId,
      vaultName: vaultName,
      tokenSource: _auth.tokens,
    );

    final manager = RemoteVaultManager(provider);
    final created = await manager.create(
      vaultName: vaultName,
      password: encrypted ? password : null,
      device: device,
      isAndroid: !kIsWeb && Platform.isAndroid,
    );

    if (encrypted && created.masterKey != null) {
      final keyBytes = await created.masterKey!.extractBytes();
      await _secretStore.write(
        SyncSecretKeys.masterKey(remoteVaultId),
        base64Encode(keyBytes),
      );
    }

    return CreatedVaultResult(
      remoteVaultId: remoteVaultId,
      vaultName: vaultName,
      encrypted: encrypted,
      recoveryKeyDisplay: created.recoveryKeyDisplay,
    );
  }

  @override
  Future<void> unlockRemoteVault({
    required String remoteVaultId,
    required String vaultName,
    required bool encrypted,
    String? password,
    String? recoveryKey,
    required DeviceIdentity device,
  }) async {
    if (!encrypted) {
      return;
    }

    final provider = DriveSyncProvider(
      vaultId: remoteVaultId,
      vaultName: vaultName,
      tokenSource: _auth.tokens,
    );

    final manager = RemoteVaultManager(provider);
    final header = await manager.readHeader();

    final SecretKey masterKey;
    if (password != null && password.isNotEmpty) {
      masterKey = await manager.unlockWithPassword(header, password);
    } else if (recoveryKey != null && recoveryKey.isNotEmpty) {
      masterKey = await manager.unlockWithRecoveryKey(header, recoveryKey);
    } else {
      throw ArgumentError('Either password or recoveryKey must be provided');
    }

    final keyBytes = await masterKey.extractBytes();
    await _secretStore.write(
      SyncSecretKeys.masterKey(remoteVaultId),
      base64Encode(keyBytes),
    );

    // Register this device with the unlocked remote vault
    final cipher = EncryptingObjectCipher(
      masterKey: masterKey,
      vaultId: remoteVaultId,
    );
    final registry = DeviceRegistry(provider, cipher);
    await registry.register(device);
  }

  @override
  Future<LocalVaultStats> getLocalVaultStats() async {
    final dir = Directory(localVaultRootPath);
    if (!dir.existsSync()) {
      return const LocalVaultStats(fileCount: 0, totalBytes: 0);
    }

    var count = 0;
    var totalBytes = 0;

    const rules = SelectiveSyncRules();
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File) continue;
      final relPath = p
          .relative(entity.path, from: localVaultRootPath)
          .replaceAll(r'\', '/');
      final vaultPath = VaultPath(relPath);
      final size = entity.lengthSync();
      if (SyncPathRules.participates(vaultPath, size, rules)) {
        count++;
        totalBytes += size;
      }
    }

    return LocalVaultStats(fileCount: count, totalBytes: totalBytes);
  }

  @override
  Future<void> finalizeSetup({
    required String remoteVaultId,
    required String vaultName,
    required bool encrypted,
    required bool backgroundSync,
    required bool wifiOnly,
    required bool mobileMode,
    required DeviceIdentity device,
    required FirstSyncChoice choice,
    String? newFolderPath,
    bool backupOnly = false,
  }) async {
    final supportDir = await getApplicationSupportDirectory();
    final dbPath = SyncPaths.syncDatabasePathForSupportDir(
      supportDir.path,
      vaultId,
    );

    final store = await SyncStateStore.open(dbPath);
    try {
      final actualVaultRoot = newFolderPath ?? localVaultRootPath;

      await store.setMeta('mode', backupOnly ? 'backupOnly' : 'sync');
      await store.setMeta('backgroundSync', backgroundSync ? 'true' : 'false');
      await store.setMeta('wifiOnly', wifiOnly ? 'true' : 'false');
      await store.setMeta('mobileMode', mobileMode ? 'true' : 'false');
      await store.setMeta('vaultRootPath', actualVaultRoot);
      await store.setMeta('remoteVaultId', remoteVaultId);
      await store.setMeta('vaultName', vaultName);
      await store.setMeta('deviceId', device.deviceId);
      await store.setMeta('deviceName', device.deviceName);
      await store.setMeta('encrypted', encrypted ? 'true' : 'false');
      await store.setMeta('providerId', 'drive');
      await store.setMeta('status', SyncUiState.idle.name);
    } finally {
      await store.close();
    }

    // Schedule background tasks if enabled on Android
    await BackgroundSyncScheduler.apply(
      enabled: backgroundSync,
      wifiOnly: wifiOnly,
      chargingOnly: false,
    );
  }

  @override
  Future<void> disconnect({required bool signOutGoogle}) async {
    final supportDir = await getApplicationSupportDirectory();
    final dbPath = SyncPaths.syncDatabasePathForSupportDir(
      supportDir.path,
      vaultId,
    );
    final file = File(dbPath);
    String? remoteVaultId;
    if (file.existsSync()) {
      final store = await SyncStateStore.open(dbPath);
      try {
        remoteVaultId = await store.getMeta('remoteVaultId');
        await store.setMeta('mode', 'off');
        await store.setMeta('status', SyncUiState.notConfigured.name);
      } finally {
        await store.close();
      }
    }

    if (remoteVaultId != null) {
      await _secretStore.delete(SyncSecretKeys.masterKey(remoteVaultId));
    }

    await BackgroundSyncScheduler.apply(
      enabled: false,
      wifiOnly: false,
      chargingOnly: false,
    );

    if (signOutGoogle) {
      await _auth.signOut();
    }
  }

  @override
  Future<bool> isConfigured() async {
    final supportDir = await getApplicationSupportDirectory();
    final dbPath = SyncPaths.syncDatabasePathForSupportDir(
      supportDir.path,
      vaultId,
    );
    final file = File(dbPath);
    if (!file.existsSync()) return false;
    final store = await SyncStateStore.open(dbPath);
    try {
      final mode = await store.getMeta('mode');
      return mode != null && mode != 'off';
    } finally {
      await store.close();
    }
  }
}
