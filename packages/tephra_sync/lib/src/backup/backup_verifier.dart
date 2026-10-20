// © 2026 Tephra. All rights reserved.

import 'dart:math';

import 'package:logging/logging.dart';
import 'package:tephra_core/tephra_core.dart';

import '../crypto/object_cipher.dart';
import '../crypto/object_purpose.dart';
import '../model/backup_record.dart';
import '../provider/sync_provider.dart';
import '../remote/remote_layout.dart';
import '../store/sync_state_store.dart';
import 'backup_manifest.dart';

final _logger = Logger('BackupVerifier');

/// Performs sampled integrity verification of remote vault backups.
final class BackupVerifier {
  /// Creates a [BackupVerifier].
  BackupVerifier({
    required this.provider,
    required this.cipher,
    required this.store,
    Random? random,
    this.clock = const SystemClock(),
  }) : _random = random ?? Random();

  final SyncProvider provider;
  final ObjectCipher cipher;
  final SyncStateStore store;
  final Random _random;
  final Clock clock;

  /// Verifies a sample of blobs in the backup at [stamp], or the newest backup if [stamp] is null.
  Future<BackupVerificationRecord> verify({String? stamp}) async {
    _logger.info('Starting backup verification (stamp: ${stamp ?? 'latest'})');

    // 1. Locate manifest key
    String? manifestKey;
    if (stamp != null) {
      manifestKey = 'backups/$stamp/manifest.json.enc';
    } else {
      final remoteList = await provider.list(RemoteLayout.backupsPrefix);
      final manifestObjects =
          remoteList.where((o) => o.key.endsWith('/manifest.json.enc')).toList()
            ..sort((a, b) => b.key.compareTo(a.key));

      if (manifestObjects.isEmpty) {
        throw StateError('No backup manifests found to verify');
      }
      manifestKey = manifestObjects.first.key;
    }

    // 2. Open and parse manifest
    final manifestBytes = await provider.get(manifestKey);
    final manifest = await BackupManifest.open(manifestBytes, cipher);

    // 3. Collect unique blob keys
    final allKeys = <String>{};
    final oneChunkFiles = <String, BackupManifestFile>{};

    for (final f in manifest.files) {
      allKeys.addAll(f.blobKeys);
      if (f.blobKeys.length == 1) {
        oneChunkFiles[f.blobKeys.first] = f;
      }
    }

    // 4. Sample 5% of keys (min 20, max 500, all if fewer than 20)
    final total = allKeys.length;
    int sampleCount;
    if (total <= 20) {
      sampleCount = total;
    } else {
      sampleCount = (total * 0.05).ceil();
      if (sampleCount < 20) sampleCount = 20;
      if (sampleCount > 500) sampleCount = 500;
      if (sampleCount > total) sampleCount = total;
    }

    final keyList = allKeys.toList()..shuffle(_random);
    final sampledKeys = keyList.take(sampleCount).toList();

    var okCount = 0;
    final failedKeys = <String>[];

    // 5. Download and verify each sampled blob
    for (final key in sampledKeys) {
      try {
        final bytes = await provider.get(key);
        final opened = await cipher.open(bytes, ObjectPurpose.blob);

        // Check content-addressed hash in key
        final expectedHash = _parseHexHash(key);
        final actualHash = contentHash(opened);

        if (expectedHash != null && actualHash != expectedHash) {
          _logger.warning(
            'Blob $key content hash mismatch: expected $expectedHash, got $actualHash',
          );
          failedKeys.add(key);
          continue;
        }

        // For single-chunk files, verify plain file hash match
        final file = oneChunkFiles[key];
        if (file != null && actualHash != file.hash) {
          _logger.warning(
            'File ${file.path} hash mismatch on single blob $key',
          );
          failedKeys.add(key);
          continue;
        }

        okCount++;
      } catch (e) {
        _logger.warning('Failed to download or decrypt blob $key: $e');
        failedKeys.add(key);
      }
    }

    final now = clock.now().toUtc();
    final record = BackupVerificationRecord(
      time: now.millisecondsSinceEpoch,
      stamp: manifest.stamp,
      sampled: sampledKeys.length,
      ok: okCount,
      failed: failedKeys.length,
      failedKeys: failedKeys,
    );

    await store.addBackupVerification(record);
    await store.setMeta(
      'lastVerificationAt',
      now.millisecondsSinceEpoch.toString(),
    );

    if (failedKeys.isNotEmpty) {
      _logger.severe(
        'Backup verification FAILED for ${manifest.stamp}: ${failedKeys.length} corrupted or missing blobs',
      );
    } else {
      _logger.info(
        'Backup verification PASSED for ${manifest.stamp} ($okCount / ${sampledKeys.length} blobs ok)',
      );
    }

    return record;
  }

  String? _parseHexHash(String key) {
    if (key.startsWith('blobs/')) {
      final sub = key.substring('blobs/'.length);
      if (sub.length == 64) return sub.toLowerCase();
    }
    return null;
  }
}
