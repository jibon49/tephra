// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../errors/sync_exceptions.dart';
import '../model/selective_sync_rules.dart';
import '../store/sync_state_store.dart';
import 'local_file_state.dart';
import 'sync_path_rules.dart';

/// Concurrency limiter restricting parallel hashing operations to [maxCount].
final class _Semaphore {
  _Semaphore(this.maxCount) : _available = maxCount;

  final int maxCount;
  int _available;
  final List<Completer<void>> _waiters = [];

  Future<T> run<T>(Future<T> Function() action) async {
    if (_available <= 0) {
      final completer = Completer<void>();
      _waiters.add(completer);
      await completer.future;
    }
    _available--;
    try {
      return await action();
    } finally {
      _available++;
      if (_waiters.isNotEmpty) {
        final next = _waiters.removeAt(0);
        next.complete();
      }
    }
  }
}

/// Scans local vault filesystem, computing and caching content hashes for
/// files that participate in synchronization.
final class LocalScanner {
  /// Creates a [LocalScanner].
  LocalScanner({required this.fs, required this.store});

  /// Filesystem being scanned.
  final VaultFileSystem fs;

  /// Sync state store containing hash cache.
  final SyncStateStore store;

  /// Scans the vault root and returns `path → LocalFileState` for participating files.
  ///
  /// Throws [VaultFolderUnavailableException] if the root cannot be statted or listed.
  Future<Map<VaultPath, LocalFileState>> scan(SelectiveSyncRules rules) async {
    final VaultEntry? rootStat;
    try {
      rootStat = await fs.stat(VaultPath.root);
    } catch (e) {
      throw VaultFolderUnavailableException('Failed to stat vault root: $e');
    }

    if (rootStat == null || !rootStat.isFolder) {
      throw const VaultFolderUnavailableException(
        'Vault root does not exist or is not a folder',
      );
    }

    final List<VaultEntry> entries;
    try {
      entries = await fs.list(folder: VaultPath.root, recursive: true);
    } catch (e) {
      throw VaultFolderUnavailableException('Failed to list vault folder: $e');
    }

    // Filter to files that participate in sync
    final seen = <VaultPath>{};
    final candidates = <VaultEntry>[];
    for (final entry in entries) {
      if (entry.isFolder) continue;
      if (SyncPathRules.participates(entry.path, entry.size, rules)) {
        if (seen.add(entry.path)) {
          candidates.add(entry);
        }
      }
    }

    // Explicitly check synced .tephra files (ignored by default in VaultFileSystem.list)
    for (final tephraFile in SyncPathRules.syncedTephraFiles) {
      final vp = VaultPath(tephraFile);
      if (seen.contains(vp)) continue;
      try {
        final entry = await fs.stat(vp);
        if (entry != null && !entry.isFolder) {
          if (SyncPathRules.participates(entry.path, entry.size, rules)) {
            if (seen.add(entry.path)) {
              candidates.add(entry);
            }
          }
        }
      } catch (_) {
        // Ignored if stat fails on non-existent file
      }
    }

    final semaphore = _Semaphore(4);
    final results = <VaultPath, LocalFileState>{};

    final futures = candidates.map(
      (entry) => semaphore.run(() async {
        final mtimeMs = entry.modified.millisecondsSinceEpoch;
        final cached = await store.cachedHash(
          entry.path.value,
          entry.size,
          mtimeMs,
        );

        final String hash;
        if (cached != null) {
          hash = cached;
        } else {
          final bytes = await fs.readBytes(entry.path);
          hash = contentHash(bytes);
          await store.putCachedHash(
            entry.path.value,
            entry.size,
            mtimeMs,
            hash,
          );
        }

        return LocalFileState(
          path: entry.path,
          hash: hash,
          size: entry.size,
          mtimeMs: mtimeMs,
        );
      }),
    );

    final states = await Future.wait(futures);
    for (final state in states) {
      results[state.path] = state;
    }

    return results;
  }
}
