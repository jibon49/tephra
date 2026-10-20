// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import 'package:tephra_core/tephra_core.dart';

import '../crypto/object_cipher.dart';
import '../crypto/object_purpose.dart';
import '../errors/sync_exceptions.dart';
import '../executor/crash_injector.dart';
import '../model/hlc.dart';
import '../model/journal_batch.dart';
import '../model/journal_entry.dart';
import '../provider/sync_provider.dart';
import '../store/sync_state_store.dart';
import 'remote_layout.dart';

/// Manages staging, sealing, crash-safe committing, and recovery of local journal batches.
final class JournalWriter {
  /// Creates a [JournalWriter].
  JournalWriter({
    required this.provider,
    required this.cipher,
    required this.store,
    required this.hlcClock,
    this.clock = const SystemClock(),
    this.crashInjector,
  });

  /// Remote storage provider.
  final SyncProvider provider;

  /// Object cipher used to seal journal batches.
  final ObjectCipher cipher;

  /// Local sync state SQLite store.
  final SyncStateStore store;

  /// Hybrid Logical Clock for timestamping mutations.
  final HlcClock hlcClock;

  /// Clock for batch creation timestamps.
  final Clock clock;

  /// Crash injector for simulating failures at named cycle points.
  final CrashInjector? crashInjector;

  final List<JournalEntry> _staged = [];
  int? _currentSeq;

  /// Local device identifier.
  String get deviceId => hlcClock.deviceId;

  /// Currently staged in-memory journal entries.
  List<JournalEntry> get staged => List.unmodifiable(_staged);

  /// Stages a new mutation in memory with the next sequential sequence number and HLC tick.
  Future<JournalEntry> stage({
    required String op,
    required String path,
    String? fromPath,
    String? hash,
    int? size,
    int? mtime,
    List<String>? blobKeys,
    String? parent,
    String? targetParent,
    String? mergedParent,
  }) async {
    if (_currentSeq == null) {
      final nextSeqStr = await store.getMeta('nextSeq');
      _currentSeq = nextSeqStr != null ? int.parse(nextSeqStr) : 1;
    }

    final seq = _currentSeq!;
    _currentSeq = seq + 1;

    final hlc = hlcClock.tick();
    final now = clock.now().toUtc().millisecondsSinceEpoch;

    final entry = JournalEntry(
      entryId: '$deviceId:$seq',
      deviceId: deviceId,
      seq: seq,
      hlc: hlc.encoded,
      op: op,
      path: path,
      fromPath: fromPath,
      hash: hash,
      size: size,
      mtime: mtime,
      blobKeys: blobKeys,
      parent: parent,
      targetParent: targetParent,
      mergedParent: mergedParent,
      time: now,
    );

    _staged.add(entry);
    return entry;
  }

  /// Commits all staged entries as an append-only remote journal batch.
  ///
  /// **The Commit Point:**
  /// 1. Builds and serializes [JournalBatch].
  /// 2. Seals the batch with [cipher] under [ObjectPurpose.journal].
  /// 3. First writes the sealed bytes to `pending_ops` table.
  /// 4. Uploads to `provider.put(key, bytes)`.
  /// 5. In a single atomic transaction: advances `meta.nextSeq = lastSeq + 1`,
  ///    removes the pending op, and inserts entries into `remote_entries`.
  Future<JournalBatch?> commit() async {
    if (_staged.isEmpty) return null;

    final batch = JournalBatch(
      deviceId: deviceId,
      firstSeq: _staged.first.seq,
      lastSeq: _staged.last.seq,
      createdAt: clock.now().toUtc(),
      entries: List.unmodifiable(_staged),
    );

    final key = RemoteLayout.journal(deviceId, batch.firstSeq);
    final batchJsonBytes = utf8.encode(jsonEncode(batch.toJson()));
    final sealedBytes = await cipher.seal(
      batchJsonBytes,
      ObjectPurpose.journal,
    );

    // 1. Record pending op for crash recovery
    final payloadJson = jsonEncode({
      'firstSeq': batch.firstSeq,
      'lastSeq': batch.lastSeq,
      'key': key,
      'bytesBase64': base64Encode(sealedBytes),
      'entries': _staged.map((e) => e.toJson(includeDeviceId: true)).toList(),
    });
    final opId = await store.addPendingOp('journalBatch', payloadJson);

    // 2. Put to remote provider
    crashInjector?.call(CrashPoint.beforeJournalPut, null);
    await provider.put(key, sealedBytes);
    crashInjector?.call(CrashPoint.afterJournalPut, null);

    // 3. Atomically finalize in SQLite
    final entriesToInsert = List<JournalEntry>.from(_staged);
    await store.transaction(() async {
      await store.setMeta('nextSeq', (batch.lastSeq + 1).toString());
      await store.removePendingOp(opId);
      await store.insertRemoteEntries(entriesToInsert);
      store.cachedRemoteHistory?.addEntries(entriesToInsert);
    });

    _staged.clear();
    return batch;
  }

  /// Recovers any pending uncompleted journal batch operations.
  ///
  /// Checks whether the remote key already exists:
  /// - If present and identical: finishes the transaction without re-upload.
  /// - If present with different bytes: throws [DeviceCloneDetectedException].
  /// - If absent: uploads the stored bytes and finishes the transaction.
  Future<List<JournalBatch>> recover() async {
    final recoveredBatches = <JournalBatch>[];
    final ops = await store.pendingOps();
    for (final op in ops) {
      if (op.kind != 'journalBatch') continue;

      final payload = jsonDecode(op.payload) as Map<String, Object?>;
      final lastSeq = (payload['lastSeq'] as num).toInt();
      final key = payload['key'] as String;
      final storedBytes = base64Decode(payload['bytesBase64'] as String);

      final List<JournalEntry> entries;
      if (payload['entries'] is List) {
        entries = (payload['entries'] as List).map((e) {
          return JournalEntry.fromJson(
            (e as Map).cast<String, Object?>(),
            defaultDeviceId: deviceId,
          );
        }).toList();
      } else {
        final decrypted = await cipher.open(storedBytes, ObjectPurpose.journal);
        final batch = JournalBatch.fromJson(
          jsonDecode(utf8.decode(decrypted)) as Map<String, Object?>,
        );
        entries = batch.entries;
      }

      List<int>? remoteBytes;
      try {
        remoteBytes = await provider.get(key);
      } on RemoteNotFoundException {
        remoteBytes = null;
      }

      if (remoteBytes != null) {
        if (!_bytesEqual(remoteBytes, storedBytes)) {
          throw const DeviceCloneDetectedException(
            'Journal batch already exists remotely with different contents',
          );
        }
        await store.transaction(() async {
          await store.setMeta('nextSeq', (lastSeq + 1).toString());
          await store.removePendingOp(op.id);
          await store.insertRemoteEntries(entries);
        });
      } else {
        await provider.put(key, storedBytes);
        await store.transaction(() async {
          await store.setMeta('nextSeq', (lastSeq + 1).toString());
          await store.removePendingOp(op.id);
          await store.insertRemoteEntries(entries);
        });
      }

      final firstSeq =
          (payload['firstSeq'] as num?)?.toInt() ??
          (entries.isNotEmpty ? entries.first.seq : 1);
      final batch = JournalBatch(
        deviceId: deviceId,
        firstSeq: firstSeq,
        lastSeq: lastSeq,
        createdAt: clock.now().toUtc(),
        entries: entries,
      );
      recoveredBatches.add(batch);

      _currentSeq = lastSeq + 1;
    }
    return recoveredBatches;
  }

  static bool _bytesEqual(List<int> a, List<int> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
