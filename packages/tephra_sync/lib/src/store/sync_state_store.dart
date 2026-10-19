// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';

import '../model/backup_record.dart';
import '../model/base_state.dart';
import '../model/blob_index_record.dart';
import '../model/conflict_record.dart';
import '../model/journal_cursor.dart';
import '../model/journal_entry.dart';
import '../model/pending_op.dart';
import '../model/sync_log_entry.dart';
import 'open_sync_database.dart';
import 'sync_database.dart';

/// Clean async interface encapsulating all persistence for Tephra sync.
///
/// Wraps [TephraSyncDatabase] and converts all Drift rows to immutable model types.
final class SyncStateStore {
  SyncStateStore._(this._db);

  final TephraSyncDatabase _db;

  /// Opens or creates a file-backed sync database at [filePath].
  static Future<SyncStateStore> open(String filePath) async {
    final db = await openSyncDatabase(filePath);
    return SyncStateStore._(db);
  }

  /// Opens an in-memory sync database for tests.
  static Future<SyncStateStore> openMemory() async {
    final db = await openMemorySyncDatabase();
    return SyncStateStore._(db);
  }

  /// Closes the underlying database.
  Future<void> close() => _db.close();

  /// Executes [action] inside an atomic database transaction.
  Future<T> transaction<T>(Future<T> Function() action) =>
      _db.transaction(action);

  // ---------------------------------------------------------------------------
  // Meta
  // ---------------------------------------------------------------------------

  /// Retrieves a string metadata value for [key], or null if absent.
  Future<String?> getMeta(String key) async {
    final query = _db.select(_db.syncMeta)..where((t) => t.key.equals(key));
    final row = await query.getSingleOrNull();
    return row?.value;
  }

  /// Sets or updates metadata [key] with [value].
  Future<void> setMeta(String key, String value) async {
    await _db
        .into(_db.syncMeta)
        .insertOnConflictUpdate(
          SyncMetaCompanion.insert(key: key, value: value),
        );
  }

  /// Removes metadata [key].
  Future<void> removeMeta(String key) async {
    await (_db.delete(_db.syncMeta)..where((t) => t.key.equals(key))).go();
  }

  /// Returns all metadata key-value pairs.
  Future<Map<String, String>> allMeta() async {
    final rows = await _db.select(_db.syncMeta).get();
    return {for (final r in rows) r.key: r.value};
  }

  // ---------------------------------------------------------------------------
  // Synced Files (Bases)
  // ---------------------------------------------------------------------------

  /// Retrieves the synced base state for [path], or null if absent.
  Future<BaseState?> base(String path) async {
    final query = _db.select(_db.syncedFiles)
      ..where((t) => t.path.equals(path));
    final row = await query.getSingleOrNull();
    if (row == null) return null;
    return _baseStateFromRow(row);
  }

  /// Retrieves all synced file base states.
  Future<List<BaseState>> allBases() async {
    final rows = await _db.select(_db.syncedFiles).get();
    return rows.map(_baseStateFromRow).toList();
  }

  /// Stores or updates a file's base state.
  Future<void> putBase(BaseState base) async {
    await _db
        .into(_db.syncedFiles)
        .insertOnConflictUpdate(
          SyncedFilesCompanion.insert(
            path: base.path,
            caseKey: base.caseKey,
            hash: base.hash,
            size: base.size,
            mtime: base.mtime,
            version: base.version,
            blobKeys: jsonEncode(base.blobKeys),
            syncedAt: base.syncedAt,
          ),
        );
  }

  /// Removes a file's base state and any associated cached base text.
  Future<void> removeBase(String path) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.syncedFiles,
      )..where((t) => t.path.equals(path))).go();
      await (_db.delete(_db.bases)..where((t) => t.path.equals(path))).go();
    });
  }

  BaseState _baseStateFromRow(SyncedFileRow r) {
    return BaseState(
      path: r.path,
      caseKey: r.caseKey,
      hash: r.hash,
      size: r.size,
      mtime: r.mtime,
      version: r.version,
      blobKeys: (jsonDecode(r.blobKeys) as List<Object?>).cast<String>(),
      syncedAt: r.syncedAt,
    );
  }

  // ---------------------------------------------------------------------------
  // Base Text (Gzip compressed UTF-8)
  // ---------------------------------------------------------------------------

  /// Retrieves and decompresses the last synced text for [path], or null.
  Future<String?> baseText(String path) async {
    final query = _db.select(_db.bases)..where((t) => t.path.equals(path));
    final row = await query.getSingleOrNull();
    if (row == null) return null;
    final decompressed = gzip.decode(row.textGz);
    return utf8.decode(decompressed);
  }

  /// Stores gzip-compressed normalized text for [path] with matching [hash].
  Future<void> putBaseText(String path, String hash, String text) async {
    final normalized = text.replaceAll('\r\n', '\n');
    final compressed = Uint8List.fromList(gzip.encode(utf8.encode(normalized)));
    await _db
        .into(_db.bases)
        .insertOnConflictUpdate(
          BasesCompanion.insert(path: path, hash: hash, textGz: compressed),
        );
  }

  /// Removes base text for [path].
  Future<void> removeBaseText(String path) async {
    await (_db.delete(_db.bases)..where((t) => t.path.equals(path))).go();
  }

  // ---------------------------------------------------------------------------
  // Local Hash Cache
  // ---------------------------------------------------------------------------

  /// Looks up cached hash for [path] matching exact [size] and [mtime].
  Future<String?> cachedHash(String path, int size, int mtime) async {
    final query = _db.select(_db.localHashCache)
      ..where(
        (t) =>
            t.path.equals(path) & t.size.equals(size) & t.mtime.equals(mtime),
      );
    final row = await query.getSingleOrNull();
    return row?.hash;
  }

  /// Caches the hash for [path] with given [size] and [mtime].
  Future<void> putCachedHash(
    String path,
    int size,
    int mtime,
    String hash,
  ) async {
    await _db
        .into(_db.localHashCache)
        .insertOnConflictUpdate(
          LocalHashCacheCompanion.insert(
            path: path,
            size: size,
            mtime: mtime,
            hash: hash,
          ),
        );
  }

  /// Removes cached hash for [path].
  Future<void> removeCachedHash(String path) async {
    await (_db.delete(
      _db.localHashCache,
    )..where((t) => t.path.equals(path))).go();
  }

  // ---------------------------------------------------------------------------
  // Remote Entries
  // ---------------------------------------------------------------------------

  /// Inserts a batch of journal entries in a single atomic transaction.
  Future<void> insertRemoteEntries(List<JournalEntry> entries) async {
    if (entries.isEmpty) return;
    await _db.transaction(() async {
      for (final e in entries) {
        await _db
            .into(_db.remoteEntries)
            .insertOnConflictUpdate(
              RemoteEntriesCompanion.insert(
                entryId: e.entryId,
                deviceId: e.deviceId,
                seq: e.seq,
                hlc: e.hlc,
                op: e.op,
                path: e.path,
                fromPath: Value(e.fromPath),
                hash: Value(e.hash),
                size: Value(e.size),
                mtime: Value(e.mtime),
                blobKeys: Value(
                  e.blobKeys == null ? null : jsonEncode(e.blobKeys),
                ),
                parent: Value(e.parent),
                targetParent: Value(e.targetParent),
                mergedParent: Value(e.mergedParent),
                time: e.time,
              ),
            );
      }
    });
  }

  /// Returns all journal entries touching [path] (either target [path] or [fromPath]).
  Future<List<JournalEntry>> entriesForPath(String path) async {
    final query = _db.select(_db.remoteEntries)
      ..where((t) => t.path.equals(path) | t.fromPath.equals(path))
      ..orderBy([(t) => OrderingTerm.asc(t.time)]);
    final rows = await query.get();
    return rows.map(_journalEntryFromRow).toList();
  }

  /// Returns a specific journal entry by [entryId], or null.
  Future<JournalEntry?> entry(String entryId) async {
    final query = _db.select(_db.remoteEntries)
      ..where((t) => t.entryId.equals(entryId));
    final row = await query.getSingleOrNull();
    return row == null ? null : _journalEntryFromRow(row);
  }

  /// Returns all known journal entries sorted ascending by time.
  Future<List<JournalEntry>> allEntries() async {
    final query = _db.select(_db.remoteEntries)
      ..orderBy([(t) => OrderingTerm.asc(t.time)]);
    final rows = await query.get();
    return rows.map(_journalEntryFromRow).toList();
  }

  JournalEntry _journalEntryFromRow(RemoteEntryRow r) {
    return JournalEntry(
      entryId: r.entryId,
      deviceId: r.deviceId,
      seq: r.seq,
      hlc: r.hlc,
      op: r.op,
      path: r.path,
      fromPath: r.fromPath,
      hash: r.hash,
      size: r.size,
      mtime: r.mtime,
      blobKeys: r.blobKeys == null
          ? null
          : (jsonDecode(r.blobKeys!) as List<Object?>).cast<String>(),
      parent: r.parent,
      targetParent: r.targetParent,
      mergedParent: r.mergedParent,
      time: r.time,
    );
  }

  // ---------------------------------------------------------------------------
  // Remote Heads
  // ---------------------------------------------------------------------------

  /// Atomically replaces all current remote heads.
  Future<void> replaceHeads(
    Map<String, (String entryId, bool isFork)> heads,
  ) async {
    await _db.transaction(() async {
      await _db.delete(_db.remoteHeads).go();
      for (final entry in heads.entries) {
        await _db
            .into(_db.remoteHeads)
            .insert(
              RemoteHeadsCompanion.insert(
                path: entry.key,
                entryId: entry.value.$1,
                isFork: entry.value.$2 ? 1 : 0,
              ),
            );
      }
    });
  }

  /// Returns all current materialized remote heads.
  Future<Map<String, (String entryId, bool isFork)>> heads() async {
    final rows = await _db.select(_db.remoteHeads).get();
    return {for (final r in rows) r.path: (r.entryId, r.isFork == 1)};
  }

  /// Returns the current head for [path], or null if absent.
  Future<(String entryId, bool isFork)?> head(String path) async {
    final query = _db.select(_db.remoteHeads)
      ..where((t) => t.path.equals(path));
    final row = await query.getSingleOrNull();
    if (row == null) return null;
    return (row.entryId, row.isFork == 1);
  }

  // ---------------------------------------------------------------------------
  // Journal Cursors
  // ---------------------------------------------------------------------------

  /// Retrieves the journal cursor for [deviceId], or null if never seen.
  Future<JournalCursor?> cursor(String deviceId) async {
    final query = _db.select(_db.journalCursors)
      ..where((t) => t.deviceId.equals(deviceId));
    final row = await query.getSingleOrNull();
    if (row == null) return null;
    return JournalCursor(
      deviceId: row.deviceId,
      lastSeq: row.lastSeq,
      deviceName: row.deviceName,
      platform: row.platform,
      lastSeenAt: row.lastSeenAt,
      revokedAfterSeq: row.revokedAfterSeq,
    );
  }

  /// Sets or updates the journal progress cursor for [deviceId].
  Future<void> setCursor(
    String deviceId,
    int lastSeq, {
    String? deviceName,
    String? platform,
    int? lastSeenAt,
    int? revokedAfterSeq,
  }) async {
    await _db
        .into(_db.journalCursors)
        .insertOnConflictUpdate(
          JournalCursorsCompanion.insert(
            deviceId: deviceId,
            lastSeq: lastSeq,
            deviceName: Value(deviceName),
            platform: Value(platform),
            lastSeenAt: Value(lastSeenAt),
            revokedAfterSeq: Value(revokedAfterSeq),
          ),
        );
  }

  /// Returns all registered device cursors.
  Future<List<JournalCursor>> allCursors() async {
    final rows = await _db.select(_db.journalCursors).get();
    return rows
        .map(
          (r) => JournalCursor(
            deviceId: r.deviceId,
            lastSeq: r.lastSeq,
            deviceName: r.deviceName,
            platform: r.platform,
            lastSeenAt: r.lastSeenAt,
            revokedAfterSeq: r.revokedAfterSeq,
          ),
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Pending Ops
  // ---------------------------------------------------------------------------

  /// Records a new pending operation for crash recovery.
  Future<int> addPendingOp(String kind, String payload) async {
    return _db
        .into(_db.pendingOps)
        .insert(
          PendingOpsCompanion.insert(
            kind: kind,
            payload: payload,
            state: 'pending',
            createdAt: DateTime.now().toUtc().millisecondsSinceEpoch,
            attempts: 0,
          ),
        );
  }

  /// Returns all pending operations ordered ascending by id.
  Future<List<PendingOp>> pendingOps() async {
    final rows = await _db.select(_db.pendingOps).get();
    return rows
        .map(
          (r) => PendingOp(
            id: r.id,
            kind: r.kind,
            payload: r.payload,
            state: r.state,
            createdAt: r.createdAt,
            attempts: r.attempts,
            lastError: r.lastError,
          ),
        )
        .toList();
  }

  /// Updates execution state, attempt counter, or error message of [id].
  Future<void> updatePendingOp(
    int id, {
    String? state,
    int? attempts,
    String? lastError,
  }) async {
    await (_db.update(_db.pendingOps)..where((t) => t.id.equals(id))).write(
      PendingOpsCompanion(
        state: state == null ? const Value.absent() : Value(state),
        attempts: attempts == null ? const Value.absent() : Value(attempts),
        lastError: lastError == null ? const Value.absent() : Value(lastError),
      ),
    );
  }

  /// Removes completed pending operation [id].
  Future<void> removePendingOp(int id) async {
    await (_db.delete(_db.pendingOps)..where((t) => t.id.equals(id))).go();
  }

  // ---------------------------------------------------------------------------
  // Remote File IDs (Drive Cache)
  // ---------------------------------------------------------------------------

  /// Retrieves the cached Google Drive file ID for [key], or null.
  Future<String?> fileId(String key) async {
    final query = _db.select(_db.remoteFileIds)
      ..where((t) => t.key.equals(key));
    final row = await query.getSingleOrNull();
    return row?.fileId;
  }

  /// Caches a Google Drive file ID for [key].
  Future<void> putFileId(
    String key,
    String fileId, {
    int? size,
    int? createdAt,
  }) async {
    await _db
        .into(_db.remoteFileIds)
        .insertOnConflictUpdate(
          RemoteFileIdsCompanion.insert(
            key: key,
            fileId: fileId,
            size: Value(size),
            createdAt: Value(createdAt),
          ),
        );
  }

  /// Removes cached file ID for [key].
  Future<void> removeFileId(String key) async {
    await (_db.delete(_db.remoteFileIds)..where((t) => t.key.equals(key))).go();
  }

  // ---------------------------------------------------------------------------
  // Blob Index (Deduplication)
  // ---------------------------------------------------------------------------

  /// Looks up an existing remote blob key matching [plainHash].
  Future<String?> blobForPlainHash(String plainHash) async {
    final query = _db.select(_db.blobIndex)
      ..where((t) => t.plainHash.equals(plainHash))
      ..orderBy([(t) => OrderingTerm.desc(t.seenAt)])
      ..limit(1);
    final row = await query.getSingleOrNull();
    return row?.blobKey;
  }

  /// Records a plaintext-to-blob mapping in the deduplication index.
  Future<void> putBlobIndex(
    String plainHash,
    String blobKey,
    int size,
    int seenAt,
  ) async {
    await _db
        .into(_db.blobIndex)
        .insertOnConflictUpdate(
          BlobIndexCompanion.insert(
            plainHash: plainHash,
            blobKey: blobKey,
            size: size,
            seenAt: seenAt,
          ),
        );
  }

  /// Updates the `seenAt` timestamp of a verified existing [blobKey].
  Future<void> touchBlob(String blobKey, int seenAt) async {
    await (_db.update(_db.blobIndex)..where((t) => t.blobKey.equals(blobKey)))
        .write(BlobIndexCompanion(seenAt: Value(seenAt)));
  }

  /// Returns all cached blob records.
  Future<List<BlobIndexRecord>> allBlobs() async {
    final rows = await _db.select(_db.blobIndex).get();
    return rows
        .map(
          (r) => BlobIndexRecord(
            plainHash: r.plainHash,
            blobKey: r.blobKey,
            size: r.size,
            seenAt: r.seenAt,
          ),
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Sync Log
  // ---------------------------------------------------------------------------

  /// Appends an event to the sync log, capping total rows at 5,000.
  Future<void> appendLog(SyncLogEntry entry) async {
    await _db.transaction(() async {
      await _db
          .into(_db.syncLog)
          .insert(
            SyncLogCompanion.insert(
              time: entry.time,
              level: entry.level,
              kind: entry.kind,
              path: Value(entry.path),
              otherPath: Value(entry.otherPath),
              deviceName: Value(entry.deviceName),
              detail: Value(entry.detail),
            ),
          );

      // Check log size and trim oldest entries beyond 5,000
      final countQuery = _db.syncLog.id.count();
      final countRow = await (_db.selectOnly(
        _db.syncLog,
      )..addColumns([countQuery])).getSingle();
      final total = countRow.read(countQuery) ?? 0;
      if (total > 5000) {
        final toDelete = total - 5000;
        final oldestRows =
            await (_db.select(_db.syncLog)
                  ..orderBy([(t) => OrderingTerm.asc(t.id)])
                  ..limit(toDelete))
                .get();
        if (oldestRows.isNotEmpty) {
          final maxIdToDelete = oldestRows.last.id;
          await (_db.delete(
            _db.syncLog,
          )..where((t) => t.id.isSmallerOrEqualValue(maxIdToDelete))).go();
        }
      }
    });
  }

  /// Retrieves recent sync log entries up to [limit] (default 100), ordered newest first.
  Future<List<SyncLogEntry>> log({int limit = 100}) async {
    final query = _db.select(_db.syncLog)
      ..orderBy([(t) => OrderingTerm.desc(t.time)])
      ..limit(limit);
    final rows = await query.get();
    return rows
        .map(
          (r) => SyncLogEntry(
            id: r.id,
            time: r.time,
            level: r.level,
            kind: r.kind,
            path: r.path,
            otherPath: r.otherPath,
            deviceName: r.deviceName,
            detail: r.detail,
          ),
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Conflicts
  // ---------------------------------------------------------------------------

  /// Records a new conflict.
  Future<int> addConflict(ConflictRecord conflict) async {
    return _db
        .into(_db.conflicts)
        .insert(
          ConflictsCompanion.insert(
            time: conflict.time,
            path: conflict.path,
            copyPath: conflict.copyPath,
            kind: conflict.kind,
            otherDevice: conflict.otherDevice,
            resolved: conflict.resolved ? 1 : 0,
          ),
        );
  }

  /// Lists conflict records, optionally filtering to unresolved only.
  Future<List<ConflictRecord>> conflicts({bool unresolvedOnly = false}) async {
    final query = _db.select(_db.conflicts);
    if (unresolvedOnly) {
      query.where((t) => t.resolved.equals(0));
    }
    query.orderBy([(t) => OrderingTerm.desc(t.time)]);
    final rows = await query.get();
    return rows
        .map(
          (r) => ConflictRecord(
            id: r.id,
            time: r.time,
            path: r.path,
            copyPath: r.copyPath,
            kind: r.kind,
            otherDevice: r.otherDevice,
            resolved: r.resolved == 1,
          ),
        )
        .toList();
  }

  /// Marks conflict [id] as resolved.
  Future<void> resolveConflict(int id) async {
    await (_db.update(_db.conflicts)..where((t) => t.id.equals(id))).write(
      const ConflictsCompanion(resolved: Value(1)),
    );
  }

  // ---------------------------------------------------------------------------
  // Backups
  // ---------------------------------------------------------------------------

  /// Records a backup in the local metadata cache.
  Future<void> putBackup(BackupRecord backup) async {
    await _db
        .into(_db.backups)
        .insertOnConflictUpdate(
          BackupsCompanion.insert(
            stamp: backup.stamp,
            manifestKey: backup.manifestKey,
            fileCount: backup.fileCount,
            totalBytes: backup.totalBytes,
            createdAt: backup.createdAt,
          ),
        );
  }

  /// Returns all cached backups sorted descending by timestamp.
  Future<List<BackupRecord>> backups() async {
    final query = _db.select(_db.backups)
      ..orderBy([(t) => OrderingTerm.desc(t.stamp)]);
    final rows = await query.get();
    return rows
        .map(
          (r) => BackupRecord(
            stamp: r.stamp,
            manifestKey: r.manifestKey,
            fileCount: r.fileCount,
            totalBytes: r.totalBytes,
            createdAt: r.createdAt,
          ),
        )
        .toList();
  }

  /// Looks up a specific backup by [stamp].
  Future<BackupRecord?> backup(String stamp) async {
    final query = _db.select(_db.backups)..where((t) => t.stamp.equals(stamp));
    final row = await query.getSingleOrNull();
    return row == null
        ? null
        : BackupRecord(
            stamp: row.stamp,
            manifestKey: row.manifestKey,
            fileCount: row.fileCount,
            totalBytes: row.totalBytes,
            createdAt: row.createdAt,
          );
  }

  /// Removes cached backup metadata for [stamp].
  Future<void> removeBackup(String stamp) async {
    await (_db.delete(_db.backups)..where((t) => t.stamp.equals(stamp))).go();
  }

  /// Records a backup verification outcome.
  Future<int> addBackupVerification(
    BackupVerificationRecord verification,
  ) async {
    return _db
        .into(_db.backupVerifications)
        .insert(
          BackupVerificationsCompanion.insert(
            time: verification.time,
            stamp: verification.stamp,
            sampled: verification.sampled,
            ok: verification.ok,
            failed: verification.failed,
            failedKeys: jsonEncode(verification.failedKeys),
          ),
        );
  }

  /// Retrieves verification history for [stamp] ordered newest first.
  Future<List<BackupVerificationRecord>> verificationsForStamp(
    String stamp,
  ) async {
    final query = _db.select(_db.backupVerifications)
      ..where((t) => t.stamp.equals(stamp))
      ..orderBy([(t) => OrderingTerm.desc(t.time)]);
    final rows = await query.get();
    return rows
        .map(
          (r) => BackupVerificationRecord(
            id: r.id,
            time: r.time,
            stamp: r.stamp,
            sampled: r.sampled,
            ok: r.ok,
            failed: r.failed,
            failedKeys: (jsonDecode(r.failedKeys) as List<Object?>)
                .cast<String>(),
          ),
        )
        .toList();
  }
}
