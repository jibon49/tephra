// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tephra_index/src/db/fts.dart';
import 'package:tephra_index/src/db/index_database.dart';
import 'package:tephra_index/src/db/open_index_database.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late String dbFile;
  TephraIndexDatabase? openDb;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('tephra_idx_');
    dbFile = p.join(tempDir.path, 'index.sqlite');
  });

  tearDown(() async {
    if (openDb != null) {
      await openDb!.close();
      openDb = null;
    }
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  test('fresh database needs full index and has all tables', () async {
    final opened = await openIndexDatabase(dbFile);
    openDb = opened.db;
    expect(opened.needsFullIndex, isTrue);

    final rows = await openDb!
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    final names = rows.map((r) => r.read<String>('name')).toSet();
    final expectedTables = {
      'files',
      'notes',
      'aliases',
      'headings',
      'blocks',
      'links',
      'tags',
      'properties',
      'tasks',
      'index_meta',
      'fts_words',
      'fts_trigram',
    };
    for (final expected in expectedTables) {
      expect(
        names.contains(expected),
        isTrue,
        reason: 'Missing table $expected',
      );
    }
  });

  test('reopen does not need full index', () async {
    final first = await openIndexDatabase(dbFile);
    expect(first.needsFullIndex, isTrue);
    await first.db.close();

    final second = await openIndexDatabase(dbFile);
    openDb = second.db;
    expect(second.needsFullIndex, isFalse);
  });

  test('parser version change wipes rows', () async {
    final first = await openIndexDatabase(dbFile);
    await first.db.customStatement('''
      INSERT INTO files(path, case_key, name_key, stem_key, folder, extension, size, mtime, created, hash, is_note)
      VALUES ('note.md', 'note.md', 'note.md', 'note', '', 'md', 10, 1000, null, 'h', 1)
      ''');
    final countBefore = await first.db
        .customSelect('SELECT count(*) AS c FROM files')
        .getSingle();
    expect(countBefore.read<int>('c'), equals(1));

    await first.db.customStatement(
      "UPDATE index_meta SET value = '0' WHERE key = 'parserVersion'",
    );
    await first.db.close();

    final second = await openIndexDatabase(dbFile);
    openDb = second.db;
    expect(second.needsFullIndex, isTrue);

    final countAfter = await second.db
        .customSelect('SELECT count(*) AS c FROM files')
        .getSingle();
    expect(countAfter.read<int>('c'), equals(0));
  });

  test('corrupt file is recreated', () async {
    File(dbFile).writeAsStringSync('not a database');
    final opened = await openIndexDatabase(dbFile);
    openDb = opened.db;
    expect(opened.needsFullIndex, isTrue);
  });

  test('foreign key cascade deletes children', () async {
    final opened = await openIndexDatabase(dbFile);
    openDb = opened.db;
    await openDb!.customStatement('''
      INSERT INTO files(path, case_key, name_key, stem_key, folder, extension, size, mtime, created, hash, is_note)
      VALUES ('A.md', 'a.md', 'a.md', 'a', '', 'md', 10, 1000, null, 'h', 1)
      ''');
    await openDb!.customStatement('''
      INSERT INTO notes(path, title, frontmatter_json, frontmatter_valid, word_count)
      VALUES ('A.md', 'A', '{}', 1, 5)
      ''');
    await openDb!.customStatement('''
      INSERT INTO headings(path, ordinal, level, heading_text, heading_key, start_offset, end_offset, line)
      VALUES ('A.md', 0, 1, 'H1', 'h1', 0, 5, 0)
      ''');
    await openDb!.customStatement('''
      INSERT INTO links(source, target_raw, target_key, target_path, kind, syntax, heading, block_ref, alias, embed_size, start_offset, end_offset, line, resolved, via_alias)
      VALUES ('A.md', 'B', 'b', null, 'link', 'wiki', null, null, null, null, 10, 15, 1, 0, 0)
      ''');

    await openDb!.customStatement("DELETE FROM files WHERE path = 'A.md'");

    final notesCount = await openDb!
        .customSelect("SELECT count(*) AS c FROM notes WHERE path = 'A.md'")
        .getSingle();
    expect(notesCount.read<int>('c'), equals(0));

    final headingsCount = await openDb!
        .customSelect("SELECT count(*) AS c FROM headings WHERE path = 'A.md'")
        .getSingle();
    expect(headingsCount.read<int>('c'), equals(0));

    final linksCount = await openDb!
        .customSelect("SELECT count(*) AS c FROM links WHERE source = 'A.md'")
        .getSingle();
    expect(linksCount.read<int>('c'), equals(0));
  });

  test('fts insert and delete', () async {
    final opened = await openIndexDatabase(dbFile);
    openDb = opened.db;
    await ftsInsert(openDb!, 1, 'Note', 'Meeting minutes');

    final r1 = await openDb!
        .customSelect(
          'SELECT rowid FROM fts_trigram WHERE fts_trigram MATCH \'"eeting"\'',
        )
        .get();
    expect(r1.map((r) => r.read<int>('rowid')).toList(), equals([1]));

    await ftsDelete(openDb!, 1);
    final r2 = await openDb!
        .customSelect(
          'SELECT rowid FROM fts_trigram WHERE fts_trigram MATCH \'"eeting"\'',
        )
        .get();
    expect(r2, isEmpty);
  });

  test('wal mode is on', () async {
    final opened = await openIndexDatabase(dbFile);
    openDb = opened.db;
    final r = await openDb!.customSelect('PRAGMA journal_mode').getSingle();
    expect(r.read<String>('journal_mode').toLowerCase(), equals('wal'));
  });
}
