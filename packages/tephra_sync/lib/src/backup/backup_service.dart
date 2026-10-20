// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../blobs/blob_store.dart';
import '../crypto/object_cipher.dart';
import '../engine/sync_lock.dart';
import '../errors/sync_exceptions.dart';
import '../local/local_scanner.dart';
import '../model/backup_record.dart';
import '../model/selective_sync_rules.dart';
import '../provider/sync_provider.dart';
import '../remote/remote_layout.dart';
import '../store/sync_state_store.dart';
import 'backup_manifest.dart';
import 'backup_retention.dart';

final _logger = Logger('BackupService');

/// Progress update during an active backup run.
final class BackupProgress {
  /// Creates a [BackupProgress] report.
  const BackupProgress({
    required this.doneFiles,
    required this.totalFiles,
    required this.doneBytes,
    required this.totalBytes,
  });

  /// Files processed so far.
  final int doneFiles;

  /// Total files identified to back up.
  final int totalFiles;

  /// Bytes processed so far.
  final int doneBytes;

  /// Aggregate bytes of all participating files.
  final int totalBytes;
}

/// Summary outcome of a completed backup run.
final class BackupResult {
  /// Creates a [BackupResult].
  const BackupResult({
    required this.manifest,
    required this.manifestKey,
    required this.prunedCount,
  });

  /// The generated and uploaded manifest.
  final BackupManifest manifest;

  /// Remote storage key where the manifest was written.
  final String manifestKey;

  /// Number of older manifests written by this device that were pruned.
  final int prunedCount;
}

/// Manages point-in-time encrypted snapshot backups of the local vault.
final class BackupService {
  /// Creates a [BackupService].
  BackupService({
    required this.vaultId,
    required this.deviceId,
    required this.deviceName,
    required this.fs,
    required this.blobStore,
    required this.provider,
    required this.cipher,
    required this.store,
    required this.syncLock,
    this.clock = const SystemClock(),
  });

  /// Unique identifier of the vault.
  final String vaultId;

  /// Local device identifier.
  final String deviceId;

  /// Human-readable device name.
  final String deviceName;

  /// Filesystem being backed up.
  final VaultFileSystem fs;

  /// Content-addressed blob store with FastCDC deduplication.
  final BlobStore blobStore;

  /// Remote storage provider.
  final SyncProvider provider;

  /// Object cipher used to seal and open manifests.
  final ObjectCipher cipher;

  /// Local state database.
  final SyncStateStore store;

  /// Mutual exclusion lock ensuring sync and backup do not execute concurrently.
  final SyncLock syncLock;

  /// Clock for timestamps.
  final Clock clock;

  /// Executes a point-in-time vault backup.
  ///
  /// Acquires [syncLock], scans participating files, chunks and deduplicates via [blobStore],
  /// writes the [BackupManifest] last, updates metadata in [store], and prunes older manifests
  /// per [BackupRetentionSettings].
  Future<BackupResult> runBackup({
    required BackupKind kind,
    SelectiveSyncRules? rules,
    void Function(BackupProgress progress)? onProgress,
  }) async {
    final acquired = await syncLock.tryAcquire();
    if (!acquired) {
      throw const SyncLockedException('Sync or backup already in progress');
    }

    try {
      _logger.info('Starting backup (kind: ${kind.name}) for vault $vaultId');

      SelectiveSyncRules effectiveRules = rules ?? const SelectiveSyncRules();
      if (rules == null) {
        final rulesJson = await store.getMeta('selectiveSyncRules');
        if (rulesJson != null) {
          try {
            effectiveRules = SelectiveSyncRules.fromJson(
              jsonDecode(rulesJson) as Map<String, dynamic>,
            );
          } catch (_) {}
        }
      }

      final scanner = LocalScanner(fs: fs, store: store);
      final scanned = await scanner.scan(effectiveRules);

      final sortedEntries = scanned.values.toList()
        ..sort((a, b) => a.path.value.compareTo(b.path.value));

      final totalFiles = sortedEntries.length;
      final totalBytes = sortedEntries.fold<int>(0, (sum, f) => sum + f.size);

      var doneFiles = 0;
      var doneBytes = 0;

      onProgress?.call(
        BackupProgress(
          doneFiles: doneFiles,
          totalFiles: totalFiles,
          doneBytes: doneBytes,
          totalBytes: totalBytes,
        ),
      );

      final manifestFiles = <BackupManifestFile>[];

      for (final fileState in sortedEntries) {
        final bytes = await fs.readBytes(fileState.path);
        final blobKeys = await blobStore.putFile(
          bytes,
          plainHash: fileState.hash,
        );

        manifestFiles.add(
          BackupManifestFile(
            path: fileState.path.value,
            hash: fileState.hash,
            size: fileState.size,
            mtime: fileState.mtimeMs,
            blobKeys: blobKeys,
          ),
        );

        doneFiles++;
        doneBytes += fileState.size;

        onProgress?.call(
          BackupProgress(
            doneFiles: doneFiles,
            totalFiles: totalFiles,
            doneBytes: doneBytes,
            totalBytes: totalBytes,
          ),
        );
      }

      final now = clock.now().toUtc();
      final manifest = BackupManifest(
        vaultId: vaultId,
        createdAt: now,
        deviceId: deviceId,
        deviceName: deviceName,
        kind: kind,
        fileCount: totalFiles,
        totalBytes: totalBytes,
        files: manifestFiles,
      );

      // Write manifest LAST: crash before leaves only unreferenced blobs (collected later by GC)
      final manifestKey = RemoteLayout.backupManifest(now);
      final sealedBytes = await manifest.seal(cipher);
      await provider.put(manifestKey, sealedBytes);

      // Record in local database
      await store.putBackup(
        BackupRecord(
          stamp: manifest.stamp,
          manifestKey: manifestKey,
          fileCount: totalFiles,
          totalBytes: totalBytes,
          createdAt: now.millisecondsSinceEpoch,
        ),
      );
      await store.setMeta(
        'lastBackupAt',
        now.millisecondsSinceEpoch.toString(),
      );

      _logger.info(
        'Backup successfully completed: $manifestKey (${manifest.files.length} files, ${manifest.totalBytes} bytes)',
      );

      // Prune older manifests written by this device
      final prunedCount = await _pruneOlderBackups(now);

      return BackupResult(
        manifest: manifest,
        manifestKey: manifestKey,
        prunedCount: prunedCount,
      );
    } finally {
      await syncLock.release();
    }
  }

  /// Lists all accessible backup manifests sorted newest first.
  Future<List<BackupManifest>> listBackups() async {
    final manifests = <BackupManifest>[];

    try {
      final remoteList = await provider.list(RemoteLayout.backupsPrefix);
      for (final obj in remoteList) {
        if (!obj.key.endsWith('/manifest.json.enc')) continue;

        try {
          final bytes = await provider.get(obj.key);
          final manifest = await BackupManifest.open(bytes, cipher);
          manifests.add(manifest);

          // Keep local cache up to date
          await store.putBackup(
            BackupRecord(
              stamp: manifest.stamp,
              manifestKey: obj.key,
              fileCount: manifest.fileCount,
              totalBytes: manifest.totalBytes,
              createdAt: manifest.createdAt.millisecondsSinceEpoch,
            ),
          );
        } catch (e) {
          _logger.warning('Failed to load backup manifest ${obj.key}: $e');
        }
      }
    } catch (e) {
      _logger.warning('Failed to list remote backup manifests: $e');
    }

    if (manifests.isEmpty) {
      // Fallback: check SQLite cache
      final cachedRecords = await store.backups();
      for (final r in cachedRecords) {
        try {
          final bytes = await provider.get(r.manifestKey);
          final manifest = await BackupManifest.open(bytes, cipher);
          manifests.add(manifest);
        } catch (_) {}
      }
    }

    manifests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return manifests;
  }

  /// Evaluates retention policy and removes manifests written by this device that are not kept.
  Future<int> _pruneOlderBackups(DateTime now) async {
    try {
      final allManifests = await listBackups();
      final myManifests = allManifests
          .where((m) => m.deviceId == deviceId)
          .toList();

      if (myManifests.length <= 1) {
        return 0;
      }

      final retentionJson = await store.getMeta('backupRetention');
      final retention = retentionJson != null
          ? BackupRetentionSettings.fromJson(
              jsonDecode(retentionJson) as Map<String, dynamic>,
            )
          : const BackupRetentionSettings();

      final keptStamps = BackupRetention.selectManifests(
        myManifests,
        hourly: retention.hourly,
        daily: retention.daily,
        monthly: retention.monthly,
        now: now,
      );

      var pruned = 0;
      for (final m in myManifests) {
        if (!keptStamps.contains(m.stamp)) {
          final key = RemoteLayout.backupManifest(m.createdAt);
          _logger.info('Pruning expired backup manifest $key (${m.stamp})');
          await provider.delete(key);
          await store.removeBackup(m.stamp);
          pruned++;
        }
      }

      return pruned;
    } catch (e) {
      _logger.warning('Failed to prune older backups: $e');
      return 0;
    }
  }
}
