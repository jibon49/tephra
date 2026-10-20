// © 2026 Tephra. All rights reserved.

import 'package:drift/drift.dart';

/// Key-value metadata table for persistent sync settings and states.
@DataClassName('SyncMetaRow')
class SyncMeta extends Table {
  @override
  String get tableName => 'meta';

  /// Metadata setting key.
  TextColumn get key => text()();

  /// String-encoded value (numbers formatted as decimal, JSON strings).
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// Last successfully synced state for each local vault file.
@DataClassName('SyncedFileRow')
@TableIndex(name: 'synced_files_case_key', columns: {#caseKey})
class SyncedFiles extends Table {
  @override
  String get tableName => 'synced_files';

  /// Vault-relative path.
  TextColumn get path => text()();

  /// Lower-case path for case-insensitive collision detection.
  TextColumn get caseKey => text().named('case_key')();

  /// SHA-256 contentHash of the synced file content.
  TextColumn get hash => text()();

  /// Size of the file in bytes.
  IntColumn get size => integer()();

  /// Modification time in milliseconds UTC.
  IntColumn get mtime => integer()();

  /// Remote entry id (`<deviceId>:<seq>`) that this file was last synced to.
  TextColumn get version => text()();

  /// JSON list of remote blob keys composing this file's ciphertext.
  TextColumn get blobKeys => text().named('blob_keys')();

  /// Sync timestamp in milliseconds UTC.
  IntColumn get syncedAt => integer().named('synced_at')();

  @override
  Set<Column<Object>> get primaryKey => {path};
}

/// Gzip-compressed last synced text for mergeable files (.md, .txt, .json).
@DataClassName('BaseRow')
class Bases extends Table {
  @override
  String get tableName => 'bases';

  /// Vault-relative path.
  TextColumn get path => text()();

  /// Content hash matching [SyncedFiles.hash].
  TextColumn get hash => text()();

  /// Gzip-compressed UTF-8 bytes of normalized newline text.
  BlobColumn get textGz => blob().named('text_gz')();

  @override
  Set<Column<Object>> get primaryKey => {path};
}

/// Cache of computed file hashes to avoid re-hashing untouched files.
@DataClassName('LocalHashCacheRow')
class LocalHashCache extends Table {
  @override
  String get tableName => 'local_hash_cache';

  /// Vault-relative path.
  TextColumn get path => text()();

  /// File size in bytes.
  IntColumn get size => integer()();

  /// Last modification time in milliseconds UTC.
  IntColumn get mtime => integer()();

  /// SHA-256 hash.
  TextColumn get hash => text()();

  @override
  Set<Column<Object>> get primaryKey => {path};
}

/// Every journal entry received from remote devices or generated locally.
@DataClassName('RemoteEntryRow')
@TableIndex(name: 'remote_entries_path', columns: {#path})
@TableIndex(name: 'remote_entries_from_path', columns: {#fromPath})
@TableIndex(name: 'remote_entries_device_seq', columns: {#deviceId, #seq})
class RemoteEntries extends Table {
  @override
  String get tableName => 'remote_entries';

  /// Unique entry id (`<deviceId>:<seq>`).
  TextColumn get entryId => text().named('entry_id')();

  /// Originating device UUID.
  TextColumn get deviceId => text().named('device_id')();

  /// Sequence number on the originating device.
  IntColumn get seq => integer()();

  /// Hybrid Logical Clock timestamp string.
  TextColumn get hlc => text()();

  /// Operation kind (`put`, `delete`, `move`).
  TextColumn get op => text()();

  /// Target vault-relative path.
  TextColumn get path => text()();

  /// Source path if op is `move`.
  TextColumn get fromPath => text().named('from_path').nullable()();

  /// Content hash for put operations.
  TextColumn get hash => text().nullable()();

  /// File size in bytes.
  IntColumn get size => integer().nullable()();

  /// Modification time in milliseconds UTC.
  IntColumn get mtime => integer().nullable()();

  /// JSON list of remote blob keys.
  TextColumn get blobKeys => text().named('blob_keys').nullable()();

  /// Parent entry id for single-parent edits.
  TextColumn get parent => text().nullable()();

  /// Target path parent entry id for moves.
  TextColumn get targetParent => text().named('target_parent').nullable()();

  /// Second parent entry id if this entry was created by a merge.
  TextColumn get mergedParent => text().named('merged_parent').nullable()();

  /// Creation time in milliseconds UTC.
  IntColumn get time => integer()();

  @override
  Set<Column<Object>> get primaryKey => {entryId};
}

/// Materialized current remote head entries for every path.
@DataClassName('RemoteHeadRow')
class RemoteHeads extends Table {
  @override
  String get tableName => 'remote_heads';

  /// Vault-relative path.
  TextColumn get path => text()();

  /// Current head entry id.
  TextColumn get entryId => text().named('entry_id')();

  /// 1 if this path has concurrent unmerged leaves (fork), 0 otherwise.
  IntColumn get isFork => integer().named('is_fork')();

  @override
  Set<Column<Object>> get primaryKey => {path};
}

/// Sequence cursor progress tracking for each remote device.
@DataClassName('JournalCursorRow')
class JournalCursors extends Table {
  @override
  String get tableName => 'journal_cursors';

  /// Device UUID.
  TextColumn get deviceId => text().named('device_id')();

  /// Last journal sequence processed from this device.
  IntColumn get lastSeq => integer().named('last_seq')();

  /// Human-readable device name.
  TextColumn get deviceName => text().named('device_name').nullable()();

  /// Device platform ('android' or 'windows').
  TextColumn get platform => text().nullable()();

  /// Last seen timestamp in milliseconds UTC.
  IntColumn get lastSeenAt => integer().named('last_seen_at').nullable()();

  /// If revoked, journals after this sequence are ignored.
  IntColumn get revokedAfterSeq =>
      integer().named('revoked_after_seq').nullable()();

  @override
  Set<Column<Object>> get primaryKey => {deviceId};
}

/// Pending local actions for crash recovery (held deletes, journal uploads).
@DataClassName('PendingOpRow')
class PendingOps extends Table {
  @override
  String get tableName => 'pending_ops';

  /// Unique auto-incrementing ID.
  IntColumn get id => integer().autoIncrement()();

  /// Operation kind ('uploadJournal', 'heldDelete', etc.).
  TextColumn get kind => text()();

  /// JSON payload describing the operation parameters.
  TextColumn get payload => text()();

  /// Operation state ('pending', 'running', 'failed').
  TextColumn get state => text()();

  /// Timestamp created in milliseconds UTC.
  IntColumn get createdAt => integer().named('created_at')();

  /// Number of retry attempts made.
  IntColumn get attempts => integer()();

  /// Last failure error message.
  TextColumn get lastError => text().named('last_error').nullable()();
}

/// Cache of Google Drive file keys to Google Drive file IDs.
@DataClassName('RemoteFileIdRow')
class RemoteFileIds extends Table {
  @override
  String get tableName => 'remote_file_ids';

  /// Remote object key (e.g. `blobs/...`, `vault.json`).
  TextColumn get key => text()();

  /// Google Drive file ID.
  TextColumn get fileId => text().named('file_id')();

  /// Object size in bytes.
  IntColumn get size => integer().nullable()();

  /// Object creation time in milliseconds UTC.
  IntColumn get createdAt => integer().named('created_at').nullable()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// Index of plaintext hashes to encrypted blob keys for content deduplication.
@DataClassName('BlobIndexRow')
class BlobIndex extends Table {
  @override
  String get tableName => 'blob_index';

  /// SHA-256 of unencrypted content.
  TextColumn get plainHash => text().named('plain_hash')();

  /// Encrypted blob key (`blobs/<cipherHash>`).
  TextColumn get blobKey => text().named('blob_key')();

  /// Blob size in bytes.
  IntColumn get size => integer()();

  /// Timestamp in milliseconds UTC when blob existence was last verified remotely.
  IntColumn get seenAt => integer().named('seen_at')();

  @override
  Set<Column<Object>> get primaryKey => {plainHash, blobKey};
}

/// Human-readable synchronization event log (capped at 5,000 entries).
@DataClassName('SyncLogRow')
class SyncLog extends Table {
  @override
  String get tableName => 'sync_log';

  /// Unique auto-incrementing ID.
  IntColumn get id => integer().autoIncrement()();

  /// Timestamp in milliseconds UTC.
  IntColumn get time => integer()();

  /// Log level string ('info', 'warning', 'error').
  TextColumn get level => text()();

  /// Event kind ('upload', 'download', 'conflict', 'delete', etc.).
  TextColumn get kind => text()();

  /// Relevant primary vault path.
  TextColumn get path => text().nullable()();

  /// Relevant secondary vault path (e.g. destination for move).
  TextColumn get otherPath => text().named('other_path').nullable()();

  /// Originating device name.
  TextColumn get deviceName => text().named('device_name').nullable()();

  /// Additional details or error message.
  TextColumn get detail => text().nullable()();
}

/// Records of sync conflicts requiring user review or automatic resolution.
@DataClassName('ConflictRow')
class Conflicts extends Table {
  @override
  String get tableName => 'conflicts';

  /// Unique auto-incrementing ID.
  IntColumn get id => integer().autoIncrement()();

  /// Timestamp in milliseconds UTC.
  IntColumn get time => integer()();

  /// Original file path.
  TextColumn get path => text()();

  /// Preserved conflict copy path (e.g. `Note (Conflict from Phone).md`).
  TextColumn get copyPath => text().named('copy_path')();

  /// Conflict type ('content', 'case', 'delete_edit').
  TextColumn get kind => text()();

  /// Name of the competing device.
  TextColumn get otherDevice => text().named('other_device')();

  /// 1 if resolved by user, 0 if active.
  IntColumn get resolved => integer()();
}

/// Cached list of remote backup snapshots.
@DataClassName('BackupRow')
class Backups extends Table {
  @override
  String get tableName => 'backups';

  /// Backup timestamp stamp string (`yyyyMMddTHHmmssZ`).
  TextColumn get stamp => text()();

  /// Remote manifest key (`backups/<stamp>/manifest.json.enc`).
  TextColumn get manifestKey => text().named('manifest_key')();

  /// Total files in the backup.
  IntColumn get fileCount => integer().named('file_count')();

  /// Total bytes of files in the backup.
  IntColumn get totalBytes => integer().named('total_bytes')();

  /// Creation time in milliseconds UTC.
  IntColumn get createdAt => integer().named('created_at')();

  @override
  Set<Column<Object>> get primaryKey => {stamp};
}

/// Records of backup integrity verification runs.
@DataClassName('BackupVerificationRow')
class BackupVerifications extends Table {
  @override
  String get tableName => 'backup_verifications';

  /// Unique auto-incrementing ID.
  IntColumn get id => integer().autoIncrement()();

  /// Verification run time in milliseconds UTC.
  IntColumn get time => integer()();

  /// Backup timestamp string verified.
  TextColumn get stamp => text()();

  /// Number of sampled blobs checked.
  IntColumn get sampled => integer()();

  /// Number of verified OK blobs.
  IntColumn get ok => integer()();

  /// Number of failed or missing blobs.
  IntColumn get failed => integer()();

  /// JSON list of failed blob keys.
  TextColumn get failedKeys => text().named('failed_keys')();
}
