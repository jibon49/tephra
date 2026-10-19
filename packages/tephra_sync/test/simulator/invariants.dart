// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:io';

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_sync/tephra_sync.dart';

import 'sim_device.dart';

/// Thrown when a simulator invariant is violated.
final class InvariantViolationException implements Exception {
  InvariantViolationException(this.message);

  final String message;

  @override
  String toString() => 'InvariantViolationException: $message';
}

/// Verification routines for simulator runs.
abstract final class SimulatorInvariants {
  /// Asserts no data loss across all devices, trash, local history, and remote history.
  static Future<void> checkNoLoss({
    required Map<String, List<int>> mustSurvive,
    required List<SimDevice> devices,
    required SyncProvider provider,
    required ObjectCipher cipher,
  }) async {
    final availableHashes = <String>{};

    // 1. Gather hashes from all devices' files, .trash, and .tephra/history
    for (final dev in devices) {
      // Normal files in vault
      try {
        final entries = await dev.fs.list(recursive: true);
        for (final e in entries) {
          if (!e.isFolder) {
            final bytes = await dev.fs.readBytes(e.path);
            availableHashes.add(contentHash(bytes));
          }
        }
      } catch (_) {}

      // .trash folder
      try {
        final trashEntries = await dev.fs.list(
          folder: VaultPath('.trash'),
          recursive: true,
        );
        for (final e in trashEntries) {
          if (!e.isFolder) {
            final bytes = await dev.fs.readBytes(e.path);
            availableHashes.add(contentHash(bytes));
          }
        }
      } catch (_) {}

      // .tephra/history folder
      try {
        final historyEntries = await dev.fs.list(
          folder: VaultPath('.tephra/history'),
          recursive: true,
        );
        for (final e in historyEntries) {
          if (!e.isFolder && e.path.value.endsWith('.gz')) {
            final gzipped = await dev.fs.readBytes(e.path);
            try {
              final decompressed = gzip.decode(gzipped);
              availableHashes.add(contentHash(decompressed));
            } catch (_) {}
          }
        }
      } catch (_) {}
    }

    // 2. Any hashes still missing, check remote journal history
    final missing = mustSurvive.keys.toSet().difference(availableHashes);
    if (missing.isNotEmpty) {
      final journalObjs = await provider.list(RemoteLayout.journalsPrefix);
      final remoteHashesWithValidBlobs = <String>{};

      for (final obj in journalObjs) {
        if (!obj.key.endsWith('.json.enc')) continue;
        try {
          final encBytes = await provider.get(obj.key);
          final rawJson = await cipher.open(encBytes, ObjectPurpose.journal);
          final jsonMap =
              jsonDecode(utf8.decode(rawJson)) as Map<String, dynamic>;
          final batch = JournalBatch.fromJson(jsonMap);

          for (final entry in batch.entries) {
            if (entry.hash != null && missing.contains(entry.hash)) {
              var allBlobsPresent = true;
              for (final bk in entry.blobKeys ?? const <String>[]) {
                try {
                  final blobBytes = await provider.get(bk);
                  if (blobBytes.isEmpty) {
                    allBlobsPresent = false;
                    break;
                  }
                } catch (_) {
                  allBlobsPresent = false;
                  break;
                }
              }
              if (allBlobsPresent) {
                remoteHashesWithValidBlobs.add(entry.hash!);
              }
            }
          }
        } catch (_) {}
      }

      availableHashes.addAll(remoteHashesWithValidBlobs);
    }

    final lostHashes = mustSurvive.keys.toSet().difference(availableHashes);
    if (lostHashes.isNotEmpty) {
      final sample = lostHashes.first;
      final bytes = mustSurvive[sample];
      final text = bytes != null
          ? utf8.decode(bytes, allowMalformed: true)
          : 'null';
      throw InvariantViolationException(
        'NO-LOSS VIOLATION: ${lostHashes.length} versions lost: $lostHashes\nSample ($sample):\n$text',
      );
    }
  }

  /// Asserts convergence: all devices have the exact same participating path -> hash map,
  /// matching the remote live heads, with zero forks.
  static Future<void> checkConvergence({
    required List<SimDevice> devices,
    required SyncProvider provider,
    required ObjectCipher cipher,
  }) async {
    // Collect all entries from remote journals
    final journalObjs = await provider.list(RemoteLayout.journalsPrefix);
    final allEntries = <JournalEntry>[];

    for (final obj in journalObjs) {
      if (!obj.key.endsWith('.json.enc')) continue;
      final encBytes = await provider.get(obj.key);
      final rawJson = await cipher.open(encBytes, ObjectPurpose.journal);
      final jsonMap = jsonDecode(utf8.decode(rawJson)) as Map<String, dynamic>;
      final batch = JournalBatch.fromJson(jsonMap);
      allEntries.addAll(batch.entries);
    }

    final remoteHistory = RemoteHistory(allEntries);

    // Assert no live path has a fork in remote history
    for (final path in remoteHistory.livePaths()) {
      if (remoteHistory.isForked(path)) {
        throw InvariantViolationException(
          'CONVERGENCE VIOLATION: Remote history is forked for live path: $path',
        );
      }
    }

    // Expected live paths and hashes from remote heads
    final expectedRemoteMap = <String, String>{};
    for (final path in remoteHistory.livePaths()) {
      final head = remoteHistory.head(path);
      if (head != null && head.hash != null && head.op != 'delete') {
        expectedRemoteMap[path] = head.hash!;
      }
    }

    // Check each device's participating files
    const rules = SelectiveSyncRules();
    for (final dev in devices) {
      final devMap = <String, String>{};
      final entries = await dev.fs.list(recursive: true);
      for (final e in entries) {
        if (!e.isFolder && SyncPathRules.participates(e.path, e.size, rules)) {
          final bytes = await dev.fs.readBytes(e.path);
          devMap[e.path.value] = contentHash(bytes);
        }
      }

      if (devMap.length != expectedRemoteMap.length) {
        throw InvariantViolationException(
          'CONVERGENCE VIOLATION: Device ${dev.name} has ${devMap.length} files, '
          'expected ${expectedRemoteMap.length}.\n'
          'Device files: $devMap\nExpected files: $expectedRemoteMap',
        );
      }

      for (final entry in expectedRemoteMap.entries) {
        final devHash = devMap[entry.key];
        if (devHash == null) {
          throw InvariantViolationException(
            'CONVERGENCE VIOLATION: Device ${dev.name} is missing path ${entry.key}',
          );
        }
        if (devHash != entry.value) {
          throw InvariantViolationException(
            'CONVERGENCE VIOLATION: Device ${dev.name} path ${entry.key} hash mismatch: $devHash != ${entry.value}',
          );
        }
      }
    }
  }
}
