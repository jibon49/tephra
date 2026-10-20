// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_sync/tephra_sync.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../logging.dart';
import '../platform/notification_service.dart';
import 'google_auth_android.dart';
import 'secure_secret_store.dart';
import 'sync_messages.dart';

final _log = Logger('sync.headless');

/// Callback that executes a sync cycle for a specific vault during headless runs.
typedef HeadlessEngineRunner = Future<SyncReport> Function({
  required SyncStateStore store,
  required VaultFileSystem fs,
  required SyncProvider provider,
  required ObjectCipher cipher,
  required DeviceIdentity deviceIdentity,
  required String remoteVaultId,
  required SyncTrigger trigger,
  required SyncCancelToken cancelToken,
});

/// Factory callback for creating an [AccessTokenSource].
typedef TokenSourceFactory = AccessTokenSource Function();

/// Factory callback for creating a [VaultFileSystem].
typedef VaultFileSystemFactory = VaultFileSystem Function(String rootPath);

/// Headless background sync executor invoked by WorkManager or background schedulers.
class HeadlessSyncRunner {
  HeadlessSyncRunner({
    this.syncDir,
    this.appSupportDir,
    NotificationService? notificationService,
    SecretStore? secretStore,
    Clock? clock,
    this.engineRunner,
    this.tokenSourceFactory,
    this.fsFactory,
    this.providerOverride,
  }) : notificationService =
           notificationService ?? const NoopNotificationService(),
       secretStore = secretStore ?? SecureSecretStore(),
       clock = clock ?? const SystemClock();

  final Directory? syncDir;
  final Directory? appSupportDir;
  final NotificationService notificationService;
  final SecretStore secretStore;
  final Clock clock;
  final HeadlessEngineRunner? engineRunner;
  final TokenSourceFactory? tokenSourceFactory;
  final VaultFileSystemFactory? fsFactory;
  final SyncProvider? providerOverride;

  /// Runs background sync cycles across all enabled sync databases within [budget].
  ///
  /// Returns `true` if all vaults completed or were skipped safely, or `false` on
  /// unexpected critical failures.
  Future<bool> runAll({Duration budget = const Duration(minutes: 8)}) async {
    try {
      await setupHeadlessLogging(appSupportDir: appSupportDir);

      final Directory dir;
      if (syncDir != null) {
        dir = syncDir!;
      } else {
        final supportDir =
            appSupportDir ?? await getApplicationSupportDirectory();
        dir = Directory(p.join(supportDir.path, 'sync'));
      }

      if (!dir.existsSync()) {
        _log.info('No sync directory found at ${dir.path}; nothing to sync');
        return true;
      }

      final dbFiles = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.sqlite'))
          .toList();

      for (final dbFile in dbFiles) {
        SyncStateStore? store;
        try {
          store = await SyncStateStore.open(dbFile.path);

          final mode = await store.getMeta('mode') ?? 'off';
          final bgSync = (await store.getMeta('backgroundSync')) == 'true';
          if (mode == 'off' || !bgSync) {
            continue;
          }

          final vaultRootPath = await store.getMeta('vaultRootPath');
          final remoteVaultId = await store.getMeta('remoteVaultId');
          final vaultName =
              await store.getMeta('vaultName') ?? remoteVaultId ?? 'Vault';
          final deviceId = await store.getMeta('deviceId');
          final deviceName = await store.getMeta('deviceName') ?? 'Tephra';
          final providerId = await store.getMeta('providerId') ?? 'drive';

          if (vaultRootPath == null ||
              remoteVaultId == null ||
              deviceId == null) {
            _log.warning('Missing required sync metadata in ${dbFile.path}');
            continue;
          }

          final deviceIdentity = DeviceIdentity(
            deviceId: deviceId,
            deviceName: deviceName,
            platform: Platform.isAndroid ? 'android' : 'windows',
          );

          // 1. Vault File System
          final fs = fsFactory != null
              ? fsFactory!(vaultRootPath)
              : IoVaultFileSystem(vaultRootPath);

          // 2. Object Cipher
          final masterKeyStr = await secretStore.read(
            SyncSecretKeys.masterKey(remoteVaultId),
          );
          final isEncrypted = (await store.getMeta('encrypted')) == 'true';
          ObjectCipher cipher;
          if (isEncrypted) {
            if (masterKeyStr == null || masterKeyStr.isEmpty) {
              _log.severe(
                'KeyNotAvailableException for remote vault $remoteVaultId',
              );
              continue;
            }
            cipher = EncryptingObjectCipher(
              masterKey: MasterKey(base64Decode(masterKeyStr)).secretKey,
              vaultId: remoteVaultId,
            );
          } else {
            cipher = const PlaintextObjectCipher();
          }

          // 3. Provider
          SyncProvider provider;
          if (providerOverride != null) {
            provider = providerOverride!;
          } else if (providerId == 'drive') {
            final tokenSource = tokenSourceFactory != null
                ? tokenSourceFactory!()
                : GoogleAuthAndroid(secretStore: secretStore);
            provider = DriveSyncProvider(
              vaultId: remoteVaultId,
              vaultName: vaultName,
              tokenSource: tokenSource,
            );
          } else {
            _log.warning('Unsupported provider $providerId in headless runner');
            continue;
          }

          // 4. Execute sync with timeout budget
          final cancelToken = SyncCancelToken();
          final budgetTimer = Timer(budget, () => cancelToken.cancel());

          try {
            if (engineRunner != null) {
              await engineRunner!(
                store: store,
                fs: fs,
                provider: provider,
                cipher: cipher,
                deviceIdentity: deviceIdentity,
                remoteVaultId: remoteVaultId,
                trigger: SyncTrigger.background,
                cancelToken: cancelToken,
              );
            } else {
              final lock = FileSyncLock(
                p.join(vaultRootPath, '.tephra', 'cache', 'sync.lock'),
              );
              final engine = SyncEngine(
                store: store,
                fs: fs,
                provider: provider,
                cipher: cipher,
                device: deviceIdentity,
                remoteVaultId: remoteVaultId,
                lock: lock,
                clock: clock,
              );
              await engine.syncOnce(
                trigger: SyncTrigger.background,
                cancel: cancelToken,
              );
            }
          } on SyncLockedException {
            _log.info(
              'Foreground worker holds sync lock, skipping background run for $remoteVaultId',
            );
          } on AuthRevokedException {
            _log.warning('Auth revoked during background sync');
            await store.setMeta('status', SyncUiState.needsAttention.name);

            final lastNotifStr = await store.getMeta('lastNotificationAt');
            final lastNotif = lastNotifStr != null
                ? DateTime.tryParse(lastNotifStr)
                : null;
            final now = clock.now();
            if (lastNotif == null ||
                now.difference(lastNotif) >= const Duration(hours: 24)) {
              await notificationService.showNotification(
                id: 1001,
                title: 'Tephra sync',
                body: 'Tephra sync needs you to reconnect Google Drive',
              );
              await store.setMeta('lastNotificationAt', now.toIso8601String());
            }
          } catch (e, st) {
            _log.warning(
              'Error syncing vault $remoteVaultId in background',
              e,
              st,
            );
          } finally {
            budgetTimer.cancel();
          }
        } finally {
          if (store != null) {
            await store.close();
          }
        }
      }
      return true;
    } catch (e, st) {
      _log.severe('Unexpected error in HeadlessSyncRunner.runAll', e, st);
      return false;
    }
  }
}
