// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import '../note_index.dart';

/// 10 probe words used by the fuzz generator and FTS dump verification.
const List<String> ftsProbeWords = [
  'alpha',
  'bravo',
  'charlie',
  'delta',
  'echo',
  'foxtrot',
  'golf',
  'hotel',
  'india',
  'juliet',
];

/// Serializes all tables in [index] into a normalized JSON representation
/// for consistency and equality verification.
Future<Map<String, List<String>>> dumpIndex(NoteIndex index) async {
  final result = <String, List<String>>{};

  Future<void> dumpTable(
    String table,
    String sql, [
    List<Object?> args = const [],
  ]) async {
    final rows = await index.rawSelect(sql, args);
    final serialized = <String>[];
    for (final row in rows) {
      serialized.add(jsonEncode(row.values.toList()));
    }
    serialized.sort();
    result[table] = serialized;
  }

  await dumpTable(
    'files',
    'SELECT path, size, mtime, created, is_note, case_key, name_key, hash FROM files',
  );

  await dumpTable(
    'notes',
    'SELECT path, title, frontmatter_json, frontmatter_valid, word_count FROM notes',
  );

  await dumpTable(
    'aliases',
    'SELECT path, alias, alias_key, ordinal FROM aliases',
  );

  await dumpTable(
    'headings',
    'SELECT path, ordinal, level, heading_text, heading_key, start_offset, end_offset, line FROM headings',
  );

  await dumpTable(
    'blocks',
    'SELECT path, block_id, block_key, start_offset, end_offset, line, preview FROM blocks',
  );

  await dumpTable(
    'links',
    'SELECT source, target_raw, target_key, target_path, kind, syntax, heading, block_ref, alias, embed_size, start_offset, end_offset, line, resolved, via_alias FROM links',
  );

  await dumpTable(
    'tags',
    'SELECT path, tag, tag_lower, start_offset, line FROM tags',
  );

  await dumpTable(
    'properties',
    'SELECT path, key, key_lower, value_type, value_text, value_lower, value_num, value_bool, value_date, ordinal FROM properties',
  );

  await dumpTable(
    'tasks',
    'SELECT path, line, status_char, task_text, task_lower, start_offset, end_offset, due FROM tasks',
  );

  final ftsHits = <String>[];
  for (final word in ftsProbeWords) {
    final rows = await index.rawSelect(
      'SELECT n.path FROM fts_trigram JOIN notes n ON n.id = fts_trigram.rowid WHERE fts_trigram MATCH ?',
      [word],
    );
    for (final row in rows) {
      ftsHits.add('$word:${row['path']}');
    }
  }
  ftsHits.sort();
  result['fts'] = ftsHits;

  return result;
}
