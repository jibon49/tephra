// © 2026 Tephra. All rights reserved.

import 'package:drift/drift.dart';

/// DDL for full-text word search with unicode61 mark categories.
const String ftsWordsDdl = '''
CREATE VIRTUAL TABLE IF NOT EXISTS fts_words USING fts5(
  name, body, content='', contentless_delete=1,
  tokenize="unicode61 remove_diacritics 2 categories 'L* N* Co M*'")''';

/// DDL for trigram case-insensitive substring search.
const String ftsTrigramDdl = '''
CREATE VIRTUAL TABLE IF NOT EXISTS fts_trigram USING fts5(
  name, body, content='', contentless_delete=1,
  tokenize='trigram case_sensitive 0')''';

/// Inserts note text into both [fts_words] and [fts_trigram] for [noteId].
Future<void> ftsInsert(
  DatabaseConnectionUser db,
  int noteId,
  String name,
  String body,
) async {
  await db.customStatement(
    'INSERT INTO fts_words(rowid, name, body) VALUES (?, ?, ?)',
    [noteId, name, body],
  );
  await db.customStatement(
    'INSERT INTO fts_trigram(rowid, name, body) VALUES (?, ?, ?)',
    [noteId, name, body],
  );
}

/// Inserts multiple note entries into [fts_words] and [fts_trigram] in chunks.
Future<void> ftsBatchInsert(
  DatabaseConnectionUser db,
  List<(int, String, String)> items,
) async {
  if (items.isEmpty) return;
  const chunkSize = 100;
  for (var i = 0; i < items.length; i += chunkSize) {
    final chunk = items.sublist(
      i,
      i + chunkSize > items.length ? items.length : i + chunkSize,
    );
    final placeholders = List.filled(chunk.length, '(?, ?, ?)').join(', ');
    final args = <Object>[];
    for (final (rowid, name, body) in chunk) {
      args.add(rowid);
      args.add(name);
      args.add(body);
    }
    await db.customStatement(
      'INSERT INTO fts_words(rowid, name, body) VALUES $placeholders',
      args,
    );
    await db.customStatement(
      'INSERT INTO fts_trigram(rowid, name, body) VALUES $placeholders',
      args,
    );
  }
}

/// Deletes full-text search entries for [noteId] from both tables.
Future<void> ftsDelete(DatabaseConnectionUser db, int noteId) async {
  await db.customStatement('DELETE FROM fts_words WHERE rowid = ?', [noteId]);
  await db.customStatement('DELETE FROM fts_trigram WHERE rowid = ?', [noteId]);
}
