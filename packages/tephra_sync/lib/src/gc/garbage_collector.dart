// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:tephra_core/tephra_core.dart';

import '../backup/backup_manifest.dart';
import '../crypto/object_cipher.dart';
import '../crypto/object_purpose.dart';
import '../history/history_retention.dart';
import '../model/hlc.dart';
import '../model/journal_entry.dart';
import '../provider/remote_object.dart';
import '../provider/sync_provider.dart';
import '../remote/remote_history.dart';
import '../remote/remote_layout.dart';
import '../store/sync_state_store.dart';
import 'gc_lease.dart';
import 'gc_state.dart';

final _logger = Logger('GarbageCollector');

/// Summary report of a completed garbage collection run.
final class GcReport {
  /// Creates a [GcReport].
  const GcReport({
    required this.deletedBlobs,
    required this.deletedBytes,
    required this.candidateBlobs,
    required this.liveBlobs,
  });

  /// Total blobs deleted during this sweep.
  final int deletedBlobs;

  /// Approximate total bytes reclaimed.
  final int deletedBytes;

  /// Number of unreferenced blobs currently in candidate grace period.
  final int candidateBlobs;

  /// Number of active blobs confirmed live and referenced.
  final int liveBlobs;
}

/// Mark-and-sweep distributed garbage collector with distributed leases and two-phase safety.
final class GarbageCollector {
  /// Creates a [GarbageCollector].
  GarbageCollector({
    required this.vaultId,
    required this.deviceId,
    required this.provider,
    required this.cipher,
    required this.store,
    required this.hlcClock,
    this.clock = const SystemClock(),
  });

  final String vaultId;
  final String deviceId;
  final SyncProvider provider;
  final ObjectCipher cipher;
  final SyncStateStore store;
  final HlcClock hlcClock;
  final Clock clock;

  /// Determines whether GC is eligible to run on this device.
  static Future<bool> isEligible({
    required SyncStateStore store,
    required bool isUnmetered,
    required bool isWindowsOrAndroidCharging,
    DateTime? now,
  }) async {
    if (!isUnmetered || !isWindowsOrAndroidCharging) {
      return false;
    }

    final mode = await store.getMeta('mode');
    if (mode == 'off') return false;

    // Never during first sync
    final firstSyncPending = await store.getMeta('firstSyncPending');
    if (firstSyncPending == 'true') return false;

    final lastGcStr = await store.getMeta('lastGcAt');
    if (lastGcStr == null) return true;

    final lastGcMs = int.tryParse(lastGcStr);
    if (lastGcMs == null) return true;

    final lastGc = DateTime.fromMillisecondsSinceEpoch(lastGcMs, isUtc: true);
    final referenceNow = now?.toUtc() ?? DateTime.now().toUtc();

    return referenceNow.difference(lastGc) >= const Duration(days: 7);
  }

  /// Claims a distributed lease under `locks/gc-<deviceId>.json.enc`.
  Future<GcLease> claimLease() async {
    final now = clock.now().toUtc();
    final lease = GcLease(
      deviceId: deviceId,
      hlc: hlcClock.tick(),
      createdAt: now,
    );

    final key = RemoteLayout.gcLease(deviceId);
    final sealed = await lease.seal(cipher);
    await provider.put(key, sealed);
    return lease;
  }

  /// Evaluates whether this device won the distributed GC lease.
  ///
  /// Live leases are those modified within 30 minutes of this device's lease.
  /// The winner is the smallest `(hlc, deviceId)`.
  Future<bool> resolveLeaseWinner({required GcLease myLease}) async {
    final myKey = RemoteLayout.gcLease(deviceId);
    final allLocks = await provider.list(RemoteLayout.locksPrefix);

    RemoteObject? myLockObj;
    for (final obj in allLocks) {
      if (obj.key == myKey) {
        myLockObj = obj;
        break;
      }
    }

    if (myLockObj == null) {
      return false;
    }

    final liveWindowStart = myLockObj.modified.subtract(
      const Duration(minutes: 30),
    );
    final liveLeases = <GcLease>[];

    for (final obj in allLocks) {
      if (!obj.key.startsWith('locks/gc-') ||
          !obj.key.endsWith('.json.enc') ||
          obj.key == RemoteLayout.gcState) {
        continue;
      }

      if (obj.modified.isBefore(liveWindowStart)) {
        continue; // Expired lease
      }

      try {
        final bytes = await provider.get(obj.key);
        final lease = await GcLease.open(bytes, cipher);
        liveLeases.add(lease);
      } catch (e) {
        _logger.warning('Failed to open lock ${obj.key}: $e');
      }
    }

    if (liveLeases.isEmpty) return true;

    liveLeases.sort();
    final winner = liveLeases.first;
    return winner.deviceId == deviceId;
  }

  /// Releases this device's distributed GC lease.
  Future<void> releaseLease() async {
    try {
      await provider.delete(RemoteLayout.gcLease(deviceId));
    } catch (_) {}
  }

  /// Executes the full mark-and-sweep garbage collection cycle.
  ///
  /// If [skipLeaseWait] is true, executes immediately without a 2-minute delay (useful for testing).
  Future<GcReport?> runGc({bool skipLeaseWait = false}) async {
    _logger.info('Starting GC for vault $vaultId');
    final myLease = await claimLease();

    try {
      if (!skipLeaseWait) {
        await Future<void>.delayed(const Duration(minutes: 2));
      }

      final isWinner = await resolveLeaseWinner(myLease: myLease);
      if (!isWinner) {
        _logger.info('Did not win GC lease; aborting GC run');
        await releaseLease();
        return null;
      }

      // MARK PHASE: Compute live set of blobs
      final liveBlobs = await _markLiveBlobs();
      if (liveBlobs == null) {
        _logger.severe('Aborting GC: Failed to mark live blobs safely');
        return null;
      }

      // SWEEP PHASE: Two-phase candidate check and cleanup
      final report = await _sweepBlobs(liveBlobs);

      final now = clock.now().toUtc();
      await store.setMeta('lastGcAt', now.millisecondsSinceEpoch.toString());

      return report;
    } finally {
      await releaseLease();
    }
  }

  /// Marks all referenced blobs across journals, snapshots, manifests, and revoked entries.
  ///
  /// Returns `null` if any read or decryption failure occurs, indicating an abort.
  Future<Set<String>?> _markLiveBlobs() async {
    final liveBlobs = <String>{};

    try {
      // 0. Discover revoked devices
      final deviceObjects = await provider.list(RemoteLayout.devicesPrefix);
      final revokedDeviceIds = <String>{};
      for (final obj in deviceObjects) {
        if (obj.key.endsWith('.revoked.json.enc') &&
            obj.key.startsWith(RemoteLayout.devicesPrefix)) {
          final prefixLen = RemoteLayout.devicesPrefix.length;
          final suffixLen = '.revoked.json.enc'.length;
          final devId = obj.key.substring(
            prefixLen,
            obj.key.length - suffixLen,
          );
          revokedDeviceIds.add(devId.toLowerCase());
        }
      }

      // 1. Read all journal batches of all devices from seq 1
      final allJournalObjects = await provider.list(
        RemoteLayout.journalsPrefix,
      );
      final entriesById = <String, JournalEntry>{};

      for (final obj in allJournalObjects) {
        if (!obj.key.endsWith('.json.enc')) continue;

        final bytes = await provider.get(obj.key);
        final opened = await cipher.open(bytes, ObjectPurpose.journal);
        final map = jsonDecode(utf8.decode(opened)) as Map<String, dynamic>;
        final rawEntries = (map['entries'] as List? ?? const []);
        final batchDeviceId = map['deviceId'] as String? ?? 'dev';

        for (final item in rawEntries) {
          final entry = JournalEntry.fromJson(
            item as Map<String, dynamic>,
            defaultDeviceId: batchDeviceId,
          );
          entriesById[entry.entryId] = entry;

          // Keep blobs referenced by entries of revoked devices
          if (revokedDeviceIds.contains(entry.deviceId.toLowerCase()) &&
              entry.blobKeys != null) {
            liveBlobs.addAll(entry.blobKeys!);
          }
        }
      }

      // Compute live heads, leaves, and versions kept by HistoryRetention
      final allEntries = entriesById.values.toList();
      final history = RemoteHistory(allEntries);
      const retention = HistoryRetention();
      final retainedIds = retention.retainAllEntries(
        history: history,
        now: clock.now().toUtc(),
      );

      for (final id in retainedIds) {
        final entry = entriesById[id];
        if (entry != null && entry.blobKeys != null) {
          liveBlobs.addAll(entry.blobKeys!);
        }
      }

      // 2. Read all snapshots
      final snapshotObjects = await provider.list(RemoteLayout.snapshotsPrefix);
      for (final obj in snapshotObjects) {
        if (!obj.key.endsWith('.json.enc')) continue;

        final bytes = await provider.get(obj.key);
        final opened = await cipher.open(bytes, ObjectPurpose.snapshot);
        final decompressed = gzip.decode(opened);
        final map =
            jsonDecode(utf8.decode(decompressed)) as Map<String, dynamic>;
        final rawEntries = (map['entries'] as List? ?? const []);

        for (final item in rawEntries) {
          final entry = JournalEntry.fromJson(
            item as Map<String, dynamic>,
            defaultDeviceId: map['deviceId'] as String? ?? 'dev',
          );
          if (entry.blobKeys != null) {
            liveBlobs.addAll(entry.blobKeys!);
          }
        }
      }

      // 3. Read all backup manifests
      final backupObjects = await provider.list(RemoteLayout.backupsPrefix);
      for (final obj in backupObjects) {
        if (!obj.key.endsWith('/manifest.json.enc')) continue;

        final bytes = await provider.get(obj.key);
        final manifest = await BackupManifest.open(bytes, cipher);
        for (final f in manifest.files) {
          liveBlobs.addAll(f.blobKeys);
        }
      }

      return liveBlobs;
    } catch (e, st) {
      _logger.severe('Critical error marking live blobs during GC: $e', e, st);
      return null;
    }
  }

  /// Performs two-phase sweep of unreferenced blobs.
  Future<GcReport> _sweepBlobs(Set<String> liveBlobs) async {
    final now = clock.now().toUtc();
    GcState currentState = GcState(updatedAt: now);

    try {
      final stateBytes = await provider.get(RemoteLayout.gcState);
      currentState = await GcState.open(stateBytes, cipher);
    } catch (_) {}

    final allBlobs = await provider.list(RemoteLayout.blobsPrefix);
    final newCandidates = <String, DateTime>{};

    var deletedCount = 0;
    var deletedBytes = 0;

    for (final blob in allBlobs) {
      if (!blob.key.startsWith('blobs/')) continue;

      if (liveBlobs.contains(blob.key)) {
        // Referenced: if previously a candidate, it is automatically saved and omitted
        continue;
      }

      // Check server creation age: skip if younger than 7 days
      final age = now.difference(blob.modified);
      if (age < const Duration(days: 7)) {
        continue;
      }

      if (currentState.candidates.containsKey(blob.key)) {
        final firstSeen = currentState.candidates[blob.key]!;
        final candidateAge = now.difference(firstSeen);

        if (candidateAge >= const Duration(hours: 24) && deletedCount < 5000) {
          // Candidate for >= 24h: delete!
          await provider.delete(blob.key);
          deletedCount++;
          deletedBytes += blob.size;
        } else {
          newCandidates[blob.key] = firstSeen;
        }
      } else {
        // Newly discovered unreferenced blob older than 7 days: add as candidate
        newCandidates[blob.key] = now;
      }
    }

    // Write updated state
    final updatedState = GcState(updatedAt: now, candidates: newCandidates);
    final sealedState = await updatedState.seal(cipher);
    await provider.put(RemoteLayout.gcState, sealedState);

    return GcReport(
      deletedBlobs: deletedCount,
      deletedBytes: deletedBytes,
      candidateBlobs: newCandidates.length,
      liveBlobs: liveBlobs.length,
    );
  }
}
