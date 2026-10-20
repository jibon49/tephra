// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:logging/logging.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../blobs/blob_store.dart';
import '../crypto/object_cipher.dart';
import '../history/local_history.dart';
import '../provider/sync_provider.dart';
import 'backup_manifest.dart';
import 'backup_service.dart';

final _logger = Logger('RestoreService');

/// Destination mode for restored backup files.
sealed class RestoreTarget {
  const RestoreTarget();

  /// Restores directly into the current open vault.
  static const intoVault = RestoreIntoVault();

  /// Restores files into a fresh folder on disk at [absolutePath].
  static RestoreNewFolder newFolder(String absolutePath) =>
      RestoreNewFolder(absolutePath);
}

/// Destination: Current vault.
final class RestoreIntoVault extends RestoreTarget {
  const RestoreIntoVault();
}

/// Destination: New external folder.
final class RestoreNewFolder extends RestoreTarget {
  const RestoreNewFolder(this.absolutePath);
  final String absolutePath;
}

/// Parameters specifying a restore operation.
final class RestoreRequest {
  /// Creates a [RestoreRequest].
  const RestoreRequest({
    required this.stamp,
    this.selection = const [],
    required this.target,
  });

  /// Timestamp stamp of the backup manifest to restore.
  final String stamp;

  /// Optional list of specific vault paths to restore. Empty implies the whole vault.
  final List<VaultPath> selection;

  /// Destination target.
  final RestoreTarget target;
}

/// Execution outcome report for a completed restore run.
final class RestoreReport {
  /// Creates a [RestoreReport].
  const RestoreReport({
    required this.restoredCount,
    required this.skippedCount,
    required this.renamedCount,
    required this.failedCount,
    this.failedPaths = const [],
  });

  /// Files written cleanly to disk.
  final int restoredCount;

  /// Files skipped because identical content already exists locally.
  final int skippedCount;

  /// Files restored under collision names to prevent overwriting modified local notes.
  final int renamedCount;

  /// Files that failed retrieval or verification.
  final int failedCount;

  /// Paths of failed items.
  final List<String> failedPaths;

  @override
  String toString() =>
      'RestoreReport(restored: $restoredCount, skipped: $skippedCount, renamed: $renamedCount, failed: $failedCount)';
}

/// Service executing vault restore operations from encrypted backup manifests.
final class RestoreService {
  /// Creates a [RestoreService].
  RestoreService({
    required this.provider,
    required this.cipher,
    required this.blobStore,
    required this.fs,
    this.backupService,
    this.localHistory,
    this.clock = const SystemClock(),
  });

  final SyncProvider provider;
  final ObjectCipher cipher;
  final BlobStore blobStore;
  final VaultFileSystem fs;
  final BackupService? backupService;
  final LocalHistory? localHistory;
  final Clock clock;

  /// Executes [request] and reports item counts.
  Future<RestoreReport> restore(
    RestoreRequest request, {
    void Function(int done, int total)? onProgress,
  }) async {
    _logger.info('Starting restore for backup stamp ${request.stamp}');

    // 1. Fetch and open manifest
    final manifestKey = 'backups/${request.stamp}/manifest.json.enc';
    final manifestBytes = await provider.get(manifestKey);
    final manifest = await BackupManifest.open(manifestBytes, cipher);

    // 2. Filter files
    final selectedSet = request.selection.map((p) => p.value).toSet();
    final filesToRestore = request.selection.isEmpty
        ? manifest.files
        : manifest.files.where((f) => selectedSet.contains(f.path)).toList();

    final total = filesToRestore.length;
    var done = 0;
    var restored = 0;
    var skipped = 0;
    var renamed = 0;
    var failed = 0;
    final failedPaths = <String>[];

    onProgress?.call(0, total);

    // 3. If restoring whole vault into current vault, run preRestore backup first
    if (request.selection.isEmpty &&
        request.target is RestoreIntoVault &&
        backupService != null) {
      _logger.info('Capturing preRestore backup before whole-vault restore');
      try {
        await backupService!.runBackup(kind: BackupKind.preRestore);
      } catch (e) {
        _logger.warning('Failed to capture preRestore backup: $e');
      }
    }

    // 4. Resolve destination filesystem
    final VaultFileSystem destFs;
    switch (request.target) {
      case RestoreIntoVault():
        destFs = fs;

      case RestoreNewFolder(:final absolutePath):
        final dir = Directory(absolutePath);
        if (dir.existsSync() && dir.listSync().isNotEmpty) {
          throw StateError(
            'Restore destination folder must be empty or not exist: $absolutePath',
          );
        }
        destFs = IoVaultFileSystem(absolutePath);
    }

    // 5. Restore files
    final now = clock.now().toUtc();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    for (final file in filesToRestore) {
      final vPath = VaultPath(file.path);

      try {
        // Download and verify file bytes from chunks
        final fileBytes = await blobStore.getFile(
          file.blobKeys,
          expectedPlainHash: file.hash,
        );

        if (request.target is RestoreIntoVault) {
          final stat = await destFs.stat(vPath);
          if (stat != null) {
            final currentBytes = await destFs.readBytes(vPath);
            final currentHash = contentHash(currentBytes);

            if (currentHash == file.hash) {
              // Present with exact same hash -> skip
              skipped++;
              done++;
              onProgress?.call(done, total);
              continue;
            }

            // Present with different hash -> collision name, NEVER overwrite
            final targetPath = await _resolveRestoreCollisionPath(
              destFs,
              vPath,
              dateStr,
            );
            await destFs.writeBytes(targetPath, fileBytes);
            renamed++;
          } else {
            // Absent locally -> write directly
            await destFs.writeBytes(vPath, fileBytes);
            restored++;
          }
        } else {
          // New folder: write directly
          await destFs.writeBytes(vPath, fileBytes);
          restored++;
        }
      } catch (e) {
        _logger.severe('Failed to restore file ${file.path}: $e');
        failed++;
        failedPaths.add(file.path);
      }

      done++;
      onProgress?.call(done, total);
    }

    final report = RestoreReport(
      restoredCount: restored,
      skippedCount: skipped,
      renamedCount: renamed,
      failedCount: failed,
      failedPaths: failedPaths,
    );

    _logger.info('Restore completed: $report');
    return report;
  }

  Future<VaultPath> _resolveRestoreCollisionPath(
    VaultFileSystem targetFs,
    VaultPath path,
    String dateStr,
  ) async {
    final parent = path.parent;
    final ext = path.extension;
    final stem = path.stem;

    var candidateStr = ext.isEmpty
        ? '$stem (restored $dateStr)'
        : '$stem (restored $dateStr).$ext';
    var candidate = (parent == null || parent.isRoot)
        ? VaultPath(candidateStr)
        : parent.join(candidateStr);

    var counter = 2;
    while (await targetFs.stat(candidate) != null) {
      candidateStr = ext.isEmpty
          ? '$stem (restored $dateStr) ($counter)'
          : '$stem (restored $dateStr) ($counter).$ext';
      candidate = (parent == null || parent.isRoot)
          ? VaultPath(candidateStr)
          : parent.join(candidateStr);
      counter++;
    }

    return candidate;
  }
}
