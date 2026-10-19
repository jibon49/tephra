// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:tephra_core/tephra_core.dart';

import '../crypto/object_cipher.dart';
import '../crypto/object_purpose.dart';
import '../model/hlc.dart';
import '../model/journal_entry.dart';
import '../provider/sync_provider.dart';
import '../store/sync_state_store.dart';
import 'remote_history.dart';
import 'remote_layout.dart';

final _logger = Logger('SnapshotStore');

/// Manages creation, compaction, and bootstrap from remote compacted snapshots.
final class SnapshotStore {
  /// Creates a [SnapshotStore].
  SnapshotStore({
    required this.provider,
    required this.cipher,
    required this.store,
    required this.hlcClock,
    this.clock = const SystemClock(),
  });

  /// Remote storage provider.
  final SyncProvider provider;

  /// Object cipher used to seal and open snapshots.
  final ObjectCipher cipher;

  /// Local sync state SQLite store.
  final SyncStateStore store;

  /// Hybrid Logical Clock.
  final HlcClock hlcClock;

  /// Clock.
  final Clock clock;

  /// Local device identifier.
  String get deviceId => hlcClock.deviceId;

  /// Returns true if [lastSeq] crossed a multiple of 500 since [lastSnapshotSeq].
  static bool shouldSnapshot({
    required int lastSeq,
    required int lastSnapshotSeq,
  }) {
    if (lastSeq < 500) return false;
    return lastSeq ~/ 500 > lastSnapshotSeq ~/ 500;
  }

  /// Compacts current state into a snapshot if the 500-sequence threshold was crossed.
  Future<String?> maybeSnapshot({
    required int lastSeq,
    required RemoteHistory history,
    required Map<String, int> covers,
  }) async {
    final lastSnapshotStr = await store.getMeta('lastSnapshotSeq');
    final lastSnapshotSeq = lastSnapshotStr != null
        ? int.parse(lastSnapshotStr)
        : 0;

    if (!shouldSnapshot(lastSeq: lastSeq, lastSnapshotSeq: lastSnapshotSeq)) {
      return null;
    }

    return writeSnapshot(lastSeq: lastSeq, history: history, covers: covers);
  }

  /// Compiles and uploads a new snapshot covering current leaves and LCAs.
  ///
  /// Prunes older snapshots so only the newest 3 written by this device remain.
  Future<String> writeSnapshot({
    required int lastSeq,
    required RemoteHistory history,
    required Map<String, int> covers,
  }) async {
    final snapshotEntries = <String, JournalEntry>{};

    for (final path in history.allPaths) {
      final leaves = history.leaves(path);
      for (final e in leaves) {
        snapshotEntries[e.entryId] = e;
      }

      // If path has a fork, include lowest common ancestors of leaves
      if (leaves.length > 1) {
        for (var i = 0; i < leaves.length; i++) {
          for (var j = i + 1; j < leaves.length; j++) {
            final lca = history.lowestCommonAncestor(
              leaves[i].entryId,
              leaves[j].entryId,
              path,
            );
            if (lca != null) {
              snapshotEntries[lca.entryId] = lca;
            }
          }
        }
      }
    }

    final payload = {
      'v': 1,
      'deviceId': deviceId,
      'seq': lastSeq,
      'createdAt': clock.now().toUtc().toIso8601String(),
      'hlc': hlcClock.tick().encoded,
      'covers': covers,
      'entries': snapshotEntries.values
          .map((e) => e.toJson(includeDeviceId: true))
          .toList(),
    };

    final jsonBytes = utf8.encode(jsonEncode(payload));
    final compressedBytes = gzip.encode(jsonBytes);
    final sealedBytes = await cipher.seal(
      compressedBytes,
      ObjectPurpose.snapshot,
    );

    final snapshotKey = RemoteLayout.snapshot(deviceId, lastSeq);
    await provider.put(snapshotKey, sealedBytes);

    // Prune older snapshots for this device (keep newest 3)
    await _pruneOldSnapshots();

    await store.setMeta('lastSnapshotSeq', lastSeq.toString());
    return snapshotKey;
  }

  Future<void> _pruneOldSnapshots() async {
    final prefix = RemoteLayout.deviceSnapshotsPrefix(deviceId);
    final objects = await provider.list(prefix);

    final snapshots = <(int seq, String key)>[];
    for (final obj in objects) {
      final parsed = RemoteLayout.parse(obj.key);
      if (parsed is SnapshotKey && parsed.deviceId == deviceId) {
        snapshots.add((parsed.seq, obj.key));
      }
    }

    snapshots.sort((a, b) => a.$1.compareTo(b.$1));

    if (snapshots.length > 3) {
      final toDelete = snapshots.take(snapshots.length - 3);
      for (final item in toDelete) {
        try {
          await provider.delete(item.$2);
        } catch (e) {
          _logger.warning('Failed to delete old snapshot ${item.$2}: $e');
        }
      }
    }
  }

  /// Bootstraps local sync database from the most comprehensive remote snapshot.
  ///
  /// If the local `remote_entries` table is already populated, does nothing.
  /// Otherwise, selects the candidate snapshot with the greatest sum of `covers`
  /// values (ties broken by greatest HLC), inserts its entries, and sets cursors.
  Future<bool> bootstrap() async {
    final existing = await store.allEntries();
    if (existing.isNotEmpty) {
      return false; // Already populated
    }

    final objects = await provider.list(RemoteLayout.snapshotsPrefix);
    final snapshotKeys = <String>[];
    for (final obj in objects) {
      final parsed = RemoteLayout.parse(obj.key);
      if (parsed is SnapshotKey) {
        snapshotKeys.add(obj.key);
      }
    }

    if (snapshotKeys.isEmpty) {
      return false; // No remote snapshots available
    }

    Map<String, Object?>? bestSnapshot;
    var bestCoversSum = -1;
    Hlc? bestHlc;

    for (final key in snapshotKeys) {
      try {
        final sealedBytes = await provider.get(key);
        final decryptedBytes = await cipher.open(
          sealedBytes,
          ObjectPurpose.snapshot,
        );
        final decompressed = gzip.decode(decryptedBytes);
        final json =
            jsonDecode(utf8.decode(decompressed)) as Map<String, Object?>;

        final covers = (json['covers'] as Map).cast<String, Object?>();
        var sum = 0;
        for (final val in covers.values) {
          sum += (val as num).toInt();
        }

        final hlcStr = json['hlc'] as String;
        final hlc = Hlc.parse(hlcStr);

        var isBetter = false;
        if (sum > bestCoversSum) {
          isBetter = true;
        } else if (sum == bestCoversSum && bestHlc != null && hlc > bestHlc) {
          isBetter = true;
        }

        if (isBetter) {
          bestSnapshot = json;
          bestCoversSum = sum;
          bestHlc = hlc;
        }
      } catch (e) {
        _logger.warning('Skipping unreadable or corrupt snapshot $key: $e');
      }
    }

    if (bestSnapshot == null) {
      return false;
    }

    // Apply winning snapshot
    final rawEntries = bestSnapshot['entries'] as List<Object?>;
    final entries = <JournalEntry>[];
    for (final raw in rawEntries) {
      if (raw is Map) {
        final entry = JournalEntry.fromJson(raw.cast<String, Object?>());
        entries.add(entry);
        try {
          hlcClock.observe(Hlc.parse(entry.hlc));
        } catch (_) {}
      }
    }

    await store.insertRemoteEntries(entries);

    final covers = (bestSnapshot['covers'] as Map).cast<String, Object?>();
    for (final entry in covers.entries) {
      final devId = entry.key;
      final seq = (entry.value as num).toInt();
      await store.setCursor(devId, seq);
    }

    return true;
  }
}
