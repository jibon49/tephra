// © 2026 Tephra. All rights reserved.

import 'package:drift/drift.dart';

import 'sync_tables.dart';

part 'sync_database.g.dart';

/// Drift SQLite database tracking local and remote sync state per vault.
@DriftDatabase(
  tables: [
    SyncMeta,
    SyncedFiles,
    Bases,
    LocalHashCache,
    RemoteEntries,
    RemoteHeads,
    JournalCursors,
    PendingOps,
    RemoteFileIds,
    BlobIndex,
    SyncLog,
    Conflicts,
    Backups,
    BackupVerifications,
  ],
)
class TephraSyncDatabase extends _$TephraSyncDatabase {
  TephraSyncDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await into(syncMeta)
          .insert(SyncMetaCompanion.insert(key: 'schemaVersion', value: '1'));
    },
    onUpgrade: (m, from, to) async {
      throw UnsupportedError(
        'Unsupported sync schema migration from $from to $to',
      );
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
