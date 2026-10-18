// © 2026 Tephra. All rights reserved.

import 'package:drift/drift.dart';

import 'fts.dart';
import 'tables.dart';

part 'index_database.g.dart';

/// SQLite database holding the Tephra note index and FTS5 virtual tables.
@DriftDatabase(
  tables: [
    Files,
    Notes,
    Aliases,
    Headings,
    Blocks,
    Links,
    Tags,
    Properties,
    Tasks,
    IndexMeta,
  ],
)
class TephraIndexDatabase extends _$TephraIndexDatabase {
  TephraIndexDatabase(super.e);

  /// Bump when the schema changes. Any change rebuilds the index from scratch (it is a cache).
  @override
  int get schemaVersion => 1;

  /// Bump when extraction output changes (parser or NoteExtractor); a mismatch forces a full rebuild on open.
  static const int parserVersion = 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement(ftsWordsDdl);
      await customStatement(ftsTrigramDdl);
    },
    onUpgrade: (m, from, to) async {
      await _dropEverything(m);
      await m.createAll();
      await customStatement(ftsWordsDdl);
      await customStatement(ftsTrigramDdl);
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _dropEverything(Migrator m) async {
    await customStatement('DROP TABLE IF EXISTS fts_words');
    await customStatement('DROP TABLE IF EXISTS fts_trigram');
    await customStatement('DROP TABLE IF EXISTS links');
    await customStatement('DROP TABLE IF EXISTS tags');
    await customStatement('DROP TABLE IF EXISTS properties');
    await customStatement('DROP TABLE IF EXISTS tasks');
    await customStatement('DROP TABLE IF EXISTS headings');
    await customStatement('DROP TABLE IF EXISTS blocks');
    await customStatement('DROP TABLE IF EXISTS aliases');
    await customStatement('DROP TABLE IF EXISTS notes');
    await customStatement('DROP TABLE IF EXISTS files');
    await customStatement('DROP TABLE IF EXISTS index_meta');
  }

  /// Drops and recreates all tables, resetting the database to a clean state.
  Future<void> wipeAll() async {
    await customStatement('DROP TABLE IF EXISTS fts_words');
    await customStatement('DROP TABLE IF EXISTS fts_trigram');
    await customStatement('DROP TABLE IF EXISTS links');
    await customStatement('DROP TABLE IF EXISTS tags');
    await customStatement('DROP TABLE IF EXISTS properties');
    await customStatement('DROP TABLE IF EXISTS tasks');
    await customStatement('DROP TABLE IF EXISTS headings');
    await customStatement('DROP TABLE IF EXISTS blocks');
    await customStatement('DROP TABLE IF EXISTS aliases');
    await customStatement('DROP TABLE IF EXISTS notes');
    await customStatement('DROP TABLE IF EXISTS files');
    await customStatement('DROP TABLE IF EXISTS index_meta');

    final m = createMigrator();
    await m.createAll();
    await customStatement(ftsWordsDdl);
    await customStatement(ftsTrigramDdl);
  }
}
