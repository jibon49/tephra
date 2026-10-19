// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:tephra_core/tephra_core.dart';

import '../crypto/object_cipher.dart';
import '../crypto/object_purpose.dart';
import '../errors/crypto_exceptions.dart';
import '../errors/sync_exceptions.dart';
import '../model/hlc.dart';
import '../model/journal_batch.dart';
import '../model/journal_entry.dart';
import '../provider/sync_provider.dart';
import '../store/sync_state_store.dart';
import 'remote_history.dart';
import 'remote_layout.dart';

final _logger = Logger('JournalReader');

/// Reads and validates remote journal batches across all participant devices.
final class JournalReader {
  /// Creates a [JournalReader].
  JournalReader({
    required this.provider,
    required this.cipher,
    required this.store,
    required this.hlcClock,
    this.clock = const SystemClock(),
  });

  /// Remote storage provider.
  final SyncProvider provider;

  /// Object cipher used to open journal batches.
  final ObjectCipher cipher;

  /// Local sync state SQLite store.
  final SyncStateStore store;

  /// Hybrid Logical Clock updated by observed remote timestamps.
  final HlcClock hlcClock;

  /// Clock.
  final Clock clock;

  /// Local device identifier.
  String get myDeviceId => hlcClock.deviceId;

  RemoteHistory? _history;

  /// Cached [RemoteHistory] representing the latest observed remote state.
  RemoteHistory get history =>
      _history ?? store.cachedRemoteHistory ?? RemoteHistory(const []);

  /// Discovers and processes all new remote journal batches.
  ///
  /// If [changedKeys] is provided, only processes devices with updated keys.
  /// Reads batches strictly sequentially without skipping gaps.
  /// Ignores entries from revoked devices beyond their `lastAcceptedSeq`.
  /// Recomputes and materializes all `remote_heads` upon completion.
  Future<void> refresh({Set<String>? changedKeys}) async {
    final deviceIds = <String>{};

    if (changedKeys != null) {
      for (final key in changedKeys) {
        final parsed = RemoteLayout.parse(key);
        if (parsed is JournalKey) {
          deviceIds.add(parsed.deviceId);
        }
      }
    } else {
      final objects = await provider.list(RemoteLayout.journalsPrefix);
      for (final obj in objects) {
        final parsed = RemoteLayout.parse(obj.key);
        if (parsed is JournalKey) {
          deviceIds.add(parsed.deviceId);
        }
      }
    }

    // Always check devices that already have cursors in the database
    final existingCursors = await store.allCursors();
    for (final c in existingCursors) {
      deviceIds.add(c.deviceId);
    }

    final sortedDeviceIds = deviceIds.toList()..sort();

    final newlyAccepted = <JournalEntry>[];
    for (final deviceId in sortedDeviceIds) {
      final entries = await _refreshDevice(deviceId);
      newlyAccepted.addAll(entries);
    }

    if (newlyAccepted.isEmpty && store.cachedRemoteHistory != null) {
      _history = store.cachedRemoteHistory;
      return;
    }

    if (store.cachedRemoteHistory == null) {
      // First load: recompute full history and materialize remote_heads
      final allEntries = await store.allEntries();
      final history = RemoteHistory(allEntries);
      store.cachedRemoteHistory = history;
      _history = history;
      final headsMap = <String, (String, bool)>{};

      for (final path in history.allPaths) {
        final head = history.head(path);
        if (head != null) {
          headsMap[path] = (head.entryId, history.isForked(path));
        }
      }

      await store.replaceHeads(headsMap);
    } else {
      // Incremental update: update only touched paths
      final history = store.cachedRemoteHistory!;
      _history = history;
      final touchedPaths = history.addEntries(newlyAccepted);
      final changedHeads = <String, (String, bool)?>{};

      for (final path in touchedPaths) {
        final head = history.head(path);
        if (head != null) {
          changedHeads[path] = (head.entryId, history.isForked(path));
        } else {
          changedHeads[path] = null;
        }
      }

      await store.updateHeads(changedHeads);
    }
  }

  Future<List<JournalEntry>> _refreshDevice(String deviceId) async {
    final allAcceptedEntries = <JournalEntry>[];
    final cursor = await store.cursor(deviceId);
    var revokedAfterSeq = cursor?.revokedAfterSeq;

    // Check remote revocation status if not already recorded
    if (revokedAfterSeq == null) {
      try {
        final revBytes = await provider.get(
          RemoteLayout.deviceRevocation(deviceId),
        );
        final decrypted = await cipher.open(revBytes, ObjectPurpose.device);
        final json = jsonDecode(utf8.decode(decrypted)) as Map<String, Object?>;
        revokedAfterSeq = (json['lastAcceptedSeq'] as num?)?.toInt();
        await store.setCursor(
          deviceId,
          cursor?.lastSeq ?? 0,
          revokedAfterSeq: revokedAfterSeq,
        );
      } on RemoteNotFoundException {
        // Device is not revoked
      } catch (e) {
        _logger.warning('Failed to read revocation status for $deviceId: $e');
      }
    }

    var nextSeq = (cursor?.lastSeq ?? 0) + 1;

    while (true) {
      final batchKey = RemoteLayout.journal(deviceId, nextSeq);

      final List<int> batchBytes;
      try {
        batchBytes = await provider.get(batchKey);
      } on RemoteNotFoundException {
        // Next expected batch is not present: stop reading without skipping
        break;
      }

      final List<int> decrypted;
      try {
        decrypted = await cipher.open(batchBytes, ObjectPurpose.journal);
      } on TamperedDataException catch (e) {
        _logger.severe(
          'Damaged remote data: tampered journal batch from device $deviceId at seq $nextSeq: $e',
        );
        break; // Stop reading this device at the damaged point
      } on CryptoException catch (e) {
        _logger.severe(
          'Damaged remote data: failed to decrypt journal batch from device $deviceId at seq $nextSeq: $e',
        );
        break;
      } catch (e) {
        _logger.severe(
          'Damaged remote data: unexpected error opening batch from device $deviceId at seq $nextSeq: $e',
        );
        break;
      }

      final JournalBatch batch;
      try {
        final json = jsonDecode(utf8.decode(decrypted));
        if (json is! Map) {
          throw const RemoteFormatException(
            'Journal batch must be a JSON object',
          );
        }
        batch = JournalBatch.fromJson(json.cast<String, Object?>());
      } on FormatException catch (e) {
        _logger.severe(
          'Malformed journal batch JSON from device $deviceId at seq $nextSeq: $e',
        );
        break;
      }

      if (batch.deviceId != deviceId) {
        throw RemoteFormatException(
          'Journal batch deviceId mismatch: folder $deviceId != payload ${batch.deviceId}',
        );
      }
      if (batch.firstSeq != nextSeq) {
        throw RemoteFormatException(
          'Expected firstSeq $nextSeq but batch started at ${batch.firstSeq}',
        );
      }

      // Clone detection for own device
      if (deviceId == myDeviceId) {
        final metaNextSeqStr = await store.getMeta('nextSeq');
        final metaNextSeq = metaNextSeqStr != null
            ? int.parse(metaNextSeqStr)
            : 1;
        if (batch.firstSeq >= metaNextSeq) {
          final ops = await store.pendingOps();
          final hasPending = ops.any((op) {
            if (op.kind != 'journalBatch') return false;
            try {
              final p = jsonDecode(op.payload) as Map<String, Object?>;
              return p['key'] == batchKey;
            } catch (_) {
              return false;
            }
          });

          if (!hasPending) {
            throw const DeviceCloneDetectedException(
              'Unrecognized batch found in own journal folder without pending op',
            );
          }
        }
      }

      // Filter entries if device is revoked
      final acceptedEntries = <JournalEntry>[];
      for (final entry in batch.entries) {
        if (revokedAfterSeq != null && entry.seq > revokedAfterSeq) {
          // Ignored beyond lastAcceptedSeq
          continue;
        }
        acceptedEntries.add(entry);
        try {
          hlcClock.observe(Hlc.parse(entry.hlc));
        } catch (_) {
          // Continue on malformed HLC
        }
      }

      await store.insertRemoteEntries(acceptedEntries);
      allAcceptedEntries.addAll(acceptedEntries);
      await store.setCursor(
        deviceId,
        batch.lastSeq,
        revokedAfterSeq: revokedAfterSeq,
      );

      nextSeq = batch.lastSeq + 1;
    }
    return allAcceptedEntries;
  }
}
