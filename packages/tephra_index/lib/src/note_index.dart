// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:drift/drift.dart' hide Table, Column, Index;
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import 'db/index_database.dart';
import 'db/open_index_database.dart';
import 'index_exceptions.dart';
import 'indexer/in_process_runner.dart';
import 'indexer/index_runner.dart';
import 'indexer/isolate_runner.dart';
import 'links/link_resolver.dart';
import 'links/name_table.dart';
import 'model/alias_record.dart';
import 'model/block_record.dart';
import 'model/file_record.dart';
import 'model/fts_hit.dart';
import 'model/heading_record.dart';
import 'model/index_event.dart';
import 'model/index_options.dart';
import 'model/index_progress.dart';
import 'model/index_stats.dart';
import 'model/link_record.dart';
import 'model/note_summary.dart';
import 'model/property_key_count.dart';
import 'model/tag_count.dart';
import 'model/task_record.dart';
import 'model/unlinked_mention.dart';

/// Public facade for the Tephra note index and search cache.
final class NoteIndex {
  NoteIndex._({
    required this._runner,
    required this._readerDb,
    required this._isIsolate,
  }) {
    _progressSub = _runner.progress.listen((p) {
      _currentProgress = p;
      _progressController.add(p);
    });
    _eventsSub = _runner.events.listen((e) {
      _changesController.add(e);
    });
  }

  /// Opens the index database and runner.
  ///
  /// [dbFile] == ':memory:' → in-memory database. A [MemoryVaultFileSystem]
  /// (or any fs that is not an [IoVaultFileSystem]) or ':memory:' → indexer runs
  /// on the calling isolate (tests). Otherwise → long-lived worker isolate.
  static Future<NoteIndex> open(
    String dbFile,
    VaultFileSystem fs, {
    Clock clock = const SystemClock(),
    IndexOptions options = const IndexOptions(),
  }) async {
    if (dbFile == ':memory:' || fs is! IoVaultFileSystem) {
      final opened = dbFile == ':memory:'
          ? await openMemoryIndexDatabase()
          : await openIndexDatabase(dbFile);
      final runner = InProcessIndexRunner(
        db: opened.db,
        fs: fs,
        clock: clock,
        options: options,
      );
      await runner.core.loadNameTable();
      return NoteIndex._(runner: runner, readerDb: opened.db, isIsolate: false);
    } else {
      final runner = await IsolateIndexRunner.create(
        rootDir: fs.rootDir,
        dbFile: dbFile,
        options: options,
      );
      final readerDb = openReaderIndexDatabase(dbFile);
      return NoteIndex._(runner: runner, readerDb: readerDb, isIsolate: true);
    }
  }

  final IndexRunner _runner;
  final TephraIndexDatabase _readerDb;
  final bool _isIsolate;

  late final StreamSubscription<IndexProgress> _progressSub;
  late final StreamSubscription<IndexEvent> _eventsSub;

  final StreamController<IndexProgress> _progressController =
      StreamController<IndexProgress>.broadcast();
  final StreamController<IndexEvent> _changesController =
      StreamController<IndexEvent>.broadcast();

  IndexProgress _currentProgress = const IndexProgress(
    phase: IndexPhase.idle,
    done: 0,
    total: 0,
  );

  bool _closed = false;

  /// Broadcast stream of indexer progress updates.
  Stream<IndexProgress> get progress => _progressController.stream;

  /// Last reported progress update, initially `IndexProgress(idle, 0, 0)`.
  IndexProgress get currentProgress => _currentProgress;

  /// Broadcast stream of index change events.
  Stream<IndexEvent> get changes => _changesController.stream;

  /// Runs a reconcile against the filesystem to detect external changes.
  Future<void> reconcile() => _runner.reconcile();

  /// Incrementally applies a single filesystem change.
  Future<void> onChange(VaultChange change) => _runner.apply(change);

  /// Rebuilds the index from scratch.
  Future<void> rebuild() => _runner.rebuild();

  /// Returns metadata summaries for all indexed Markdown notes.
  Future<List<NoteSummary>> allNotes() async {
    final rows = await _readerDb
        .customSelect(
          'SELECT f.path, n.title, f.size, f.mtime, f.created, n.word_count '
          'FROM notes n JOIN files f ON f.path = n.path '
          'ORDER BY f.path',
        )
        .get();

    final aliasRows =
        await (_readerDb.select(_readerDb.aliases)..orderBy([
              (tbl) => OrderingTerm(expression: tbl.path),
              (tbl) => OrderingTerm(expression: tbl.ordinal),
            ]))
            .get();

    final tagRows =
        await (_readerDb.select(_readerDb.tags)..orderBy([
              (tbl) => OrderingTerm(expression: tbl.path),
              (tbl) => OrderingTerm(expression: tbl.tag),
            ]))
            .get();

    final aliasesMap = <String, List<String>>{};
    for (final r in aliasRows) {
      aliasesMap.putIfAbsent(r.path, () => <String>[]).add(r.alias);
    }

    final tagsMap = <String, List<String>>{};
    for (final r in tagRows) {
      final list = tagsMap.putIfAbsent(r.path, () => <String>[]);
      if (!list.contains(r.tag)) {
        list.add(r.tag);
      }
    }

    return rows.map((r) {
      final pathStr = r.read<String>('path');
      final createdMs = r.read<int?>('created');
      return NoteSummary(
        path: VaultPath(pathStr),
        title: r.read<String>('title'),
        size: r.read<int>('size'),
        modified: DateTime.fromMillisecondsSinceEpoch(
          r.read<int>('mtime'),
          isUtc: true,
        ).toLocal(),
        created: createdMs != null
            ? DateTime.fromMillisecondsSinceEpoch(
                createdMs,
                isUtc: true,
              ).toLocal()
            : null,
        wordCount: r.read<int>('word_count'),
        aliases: aliasesMap[pathStr] ?? const [],
        tags: tagsMap[pathStr] ?? const [],
      );
    }).toList();
  }

  /// Returns summary metadata for a note at [path], or null if not found.
  Future<NoteSummary?> note(VaultPath path) async {
    final fileRow = await _readerDb
        .customSelect(
          'SELECT f.path, n.title, f.size, f.mtime, f.created, n.word_count '
          'FROM notes n JOIN files f ON f.path = n.path '
          'WHERE f.path = ?',
          variables: [Variable.withString(path.value)],
        )
        .getSingleOrNull();

    if (fileRow == null) return null;

    final aliasRows =
        await (_readerDb.select(_readerDb.aliases)
              ..where((tbl) => tbl.path.equals(path.value))
              ..orderBy([(tbl) => OrderingTerm(expression: tbl.ordinal)]))
            .get();
    final tagRows = await (_readerDb.select(
      _readerDb.tags,
    )..where((tbl) => tbl.path.equals(path.value))).get();

    final tags = <String>[];
    for (final tr in tagRows) {
      if (!tags.contains(tr.tag)) {
        tags.add(tr.tag);
      }
    }

    final createdMs = fileRow.read<int?>('created');
    return NoteSummary(
      path: path,
      title: fileRow.read<String>('title'),
      size: fileRow.read<int>('size'),
      modified: DateTime.fromMillisecondsSinceEpoch(
        fileRow.read<int>('mtime'),
        isUtc: true,
      ).toLocal(),
      created: createdMs != null
          ? DateTime.fromMillisecondsSinceEpoch(
              createdMs,
              isUtc: true,
            ).toLocal()
          : null,
      wordCount: fileRow.read<int>('word_count'),
      aliases: aliasRows.map((a) => a.alias).toList(),
      tags: tags,
    );
  }

  /// Resolves [target] link against the index relative to [from].
  Future<VaultPath?> resolveLink(
    String target, {
    required VaultPath from,
  }) async {
    var t = target;
    final pipe = t.indexOf('|');
    if (pipe != -1) t = t.substring(0, pipe);
    final hash = t.indexOf('#');
    if (hash != -1) t = t.substring(0, hash);
    t = t.trim().replaceAll(r'\', '/');
    if (t.isEmpty) return from;

    final absoluteOnly = t.startsWith('/');
    var tClean = t;
    if (absoluteOnly) {
      while (tClean.startsWith('/')) {
        tClean = tClean.substring(1);
      }
      if (tClean.isEmpty) return null;
    }
    final relativeOnly = tClean.startsWith('./') || tClean.startsWith('../');

    final List<String> candidates;
    if (tClean.toLowerCase().endsWith('.md')) {
      candidates = [tClean];
    } else {
      candidates = ['$tClean.md', tClean];
    }

    final caseKeys = <String>{};
    final nameKeys = <String>{};

    if (!relativeOnly) {
      for (final c in candidates) {
        final vp = _tryVaultPath(c);
        if (vp != null) caseKeys.add(vp.caseKey);
      }
    }

    if (!absoluteOnly) {
      final base = from.parent;
      for (final c in candidates) {
        final combined = (base == null || base.isRoot || base.value.isEmpty)
            ? c
            : '${base.value}/$c';
        final vp = _tryVaultPath(combined);
        if (vp != null) caseKeys.add(vp.caseKey);
      }
    }

    if (!absoluteOnly && !relativeOnly) {
      for (final c in candidates) {
        final lastSlash = c.lastIndexOf('/');
        final seg = lastSlash == -1 ? c : c.substring(lastSlash + 1);
        nameKeys.add(seg.toLowerCase());
      }
    }

    final files = <VaultPath>{};
    if (caseKeys.isNotEmpty || nameKeys.isNotEmpty) {
      final whereClauses = <String>[];
      final vars = <Variable>[];

      if (caseKeys.isNotEmpty) {
        final placeholders = List.filled(caseKeys.length, '?').join(', ');
        whereClauses.add('case_key IN ($placeholders)');
        vars.addAll(caseKeys.map(Variable.withString));
      }
      if (nameKeys.isNotEmpty) {
        final placeholders = List.filled(nameKeys.length, '?').join(', ');
        whereClauses.add('name_key IN ($placeholders)');
        vars.addAll(nameKeys.map(Variable.withString));
      }

      final query = 'SELECT path FROM files WHERE ${whereClauses.join(' OR ')}';
      final rows = await _readerDb.customSelect(query, variables: vars).get();
      for (final r in rows) {
        files.add(VaultPath(r.read<String>('path')));
      }
    }

    final aliasesMap = <VaultPath, List<String>>{};
    if (!absoluteOnly && !relativeOnly && !tClean.contains('/')) {
      final aliasKey = tClean.toLowerCase();
      final aliasRows = await _readerDb
          .customSelect(
            'SELECT path, alias FROM aliases WHERE alias_key = ?',
            variables: [Variable.withString(aliasKey)],
          )
          .get();
      for (final r in aliasRows) {
        final vp = VaultPath(r.read<String>('path'));
        aliasesMap.putIfAbsent(vp, () => []).add(r.read<String>('alias'));
        files.add(vp);
      }
    }

    final nameTable = NameTable.from(files, aliasesMap);
    final resolved = LinkResolver(nameTable).resolve(t, from: from);
    return resolved?.path;
  }

  /// Returns incoming backlinks to [target].
  Future<List<LinkRecord>> backlinks(VaultPath target) async {
    final rows =
        await (_readerDb.select(_readerDb.links)
              ..where(
                (tbl) =>
                    tbl.targetPath.equals(target.value) &
                    tbl.source.equals(target.value).not(),
              )
              ..orderBy([
                (tbl) => OrderingTerm(expression: tbl.source),
                (tbl) => OrderingTerm(expression: tbl.startOffset),
              ]))
            .get();
    return rows.map(_rowToLink).toList();
  }

  /// Returns unlinked mentions of [target].
  Future<List<UnlinkedMention>> unlinkedMentions(VaultPath target) {
    throw UnimplementedError('step 02.12');
  }

  /// Returns outgoing links from [source].
  Future<List<LinkRecord>> outgoing(VaultPath source) async {
    final rows =
        await (_readerDb.select(_readerDb.links)
              ..where((tbl) => tbl.source.equals(source.value))
              ..orderBy([(tbl) => OrderingTerm(expression: tbl.startOffset)]))
            .get();
    return rows.map(_rowToLink).toList();
  }

  /// Returns counts for all tags and ancestor tag prefixes.
  Future<List<TagCount>> tags() async {
    final rows = await _readerDb
        .customSelect('SELECT DISTINCT path, tag, tag_lower FROM tags')
        .get();

    final allPaths = <String, Set<String>>{};
    final directPaths = <String, Set<String>>{};
    final exactDisplay = <String, String>{};
    final inferredDisplay = <String, String>{};

    for (final r in rows) {
      final path = r.read<String>('path');
      final tag = r.read<String>('tag');
      final tagLower = r.read<String>('tag_lower');

      final lowerSegments = tagLower.split('/');
      final displaySegments = tag.split('/');

      for (var len = 1; len <= lowerSegments.length; len++) {
        final prefixLower = lowerSegments.sublist(0, len).join('/');
        allPaths.putIfAbsent(prefixLower, () => <String>{}).add(path);

        if (len == lowerSegments.length) {
          directPaths.putIfAbsent(prefixLower, () => <String>{}).add(path);
          exactDisplay.putIfAbsent(prefixLower, () => tag);
        } else {
          inferredDisplay.putIfAbsent(
            prefixLower,
            () => displaySegments.sublist(0, len).join('/'),
          );
        }
      }
    }

    final result = <TagCount>[];
    for (final entry in allPaths.entries) {
      final prefixLower = entry.key;
      final display =
          exactDisplay[prefixLower] ??
          inferredDisplay[prefixLower] ??
          prefixLower;
      final count = entry.value.length;
      final direct = directPaths[prefixLower]?.length ?? 0;
      result.add(
        TagCount(
          tag: display,
          tagLower: prefixLower,
          count: count,
          directCount: direct,
        ),
      );
    }

    result.sort((a, b) => a.tagLower.compareTo(b.tagLower));
    return result;
  }

  /// Returns all headings within [path] in document order.
  Future<List<HeadingRecord>> headings(VaultPath path) async {
    final rows =
        await (_readerDb.select(_readerDb.headings)
              ..where((tbl) => tbl.path.equals(path.value))
              ..orderBy([(tbl) => OrderingTerm(expression: tbl.ordinal)]))
            .get();
    return rows.map(_rowToHeading).toList();
  }

  /// Returns tasks matching the optional [done] filter.
  Future<List<TaskRecord>> tasks({bool? done}) async {
    final query = _readerDb.select(_readerDb.tasks);
    if (done == true) {
      query.where((tbl) => tbl.statusChar.equals(' ').not());
    } else if (done == false) {
      query.where((tbl) => tbl.statusChar.equals(' '));
    }
    query.orderBy([
      (tbl) => OrderingTerm(expression: tbl.path),
      (tbl) => OrderingTerm(expression: tbl.line),
    ]);
    final rows = await query.get();
    return rows.map(_rowToTask).toList();
  }

  /// Performs a full-text search query using SQLite FTS5.
  Future<List<FtsHit>> fullText(String ftsQuery, {int limit = 200}) async {
    try {
      final rows = await _readerDb
          .customSelect(
            'SELECT n.path, bm25(fts_words) AS r '
            'FROM fts_words JOIN notes n ON n.id = fts_words.rowid '
            'WHERE fts_words MATCH ? '
            'ORDER BY r LIMIT ?',
            variables: [Variable.withString(ftsQuery), Variable.withInt(limit)],
          )
          .get();
      return rows
          .map(
            (r) => FtsHit(
              path: VaultPath(r.read<String>('path')),
              rank: r.read<double>('r'),
            ),
          )
          .toList();
    } catch (e) {
      if (e is sqlite.SqliteException ||
          e.toString().contains('syntax error') ||
          e.toString().contains('MATCH') ||
          e.toString().contains('SqliteException')) {
        throw IndexQueryException('invalid full-text query: $e');
      }
      rethrow;
    }
  }

  /// Returns all indexed files in the vault.
  Future<List<FileRecord>> allFiles() async {
    final rows = await (_readerDb.select(
      _readerDb.files,
    )..orderBy([(tbl) => OrderingTerm(expression: tbl.path)])).get();
    return rows.map((r) {
      final createdMs = r.created;
      return FileRecord(
        path: VaultPath(r.path),
        size: r.size,
        modified: DateTime.fromMillisecondsSinceEpoch(
          r.mtime,
          isUtc: true,
        ).toLocal(),
        created: createdMs != null
            ? DateTime.fromMillisecondsSinceEpoch(
                createdMs,
                isUtc: true,
              ).toLocal()
            : null,
        isNote: r.isNote,
      );
    }).toList();
  }

  /// Returns all note aliases across the vault.
  Future<List<AliasRecord>> allAliases() async {
    final rows =
        await (_readerDb.select(_readerDb.aliases)..orderBy([
              (tbl) => OrderingTerm(expression: tbl.path),
              (tbl) => OrderingTerm(expression: tbl.ordinal),
            ]))
            .get();
    return rows
        .map((r) => AliasRecord(path: VaultPath(r.path), alias: r.alias))
        .toList();
  }

  /// Returns all headings across all notes.
  Future<List<HeadingRecord>> allHeadings() async {
    final rows =
        await (_readerDb.select(_readerDb.headings)..orderBy([
              (tbl) => OrderingTerm(expression: tbl.path),
              (tbl) => OrderingTerm(expression: tbl.ordinal),
            ]))
            .get();
    return rows.map(_rowToHeading).toList();
  }

  /// Returns all block references within [path].
  Future<List<BlockRecord>> blocks(VaultPath path) async {
    final rows =
        await (_readerDb.select(_readerDb.blocks)
              ..where((tbl) => tbl.path.equals(path.value))
              ..orderBy([(tbl) => OrderingTerm(expression: tbl.startOffset)]))
            .get();
    return rows.map(_rowToBlock).toList();
  }

  /// Returns distinct frontmatter property keys with their inferred types and counts.
  Future<List<PropertyKeyCount>> propertyKeys() async {
    final rows = await _readerDb
        .customSelect(
          'SELECT key_lower, key, value_type, COUNT(DISTINCT path) AS c '
          'FROM properties GROUP BY key_lower, value_type',
        )
        .get();

    final grouped = <String, List<_PropTypeStat>>{};
    for (final r in rows) {
      final keyLower = r.read<String>('key_lower');
      final key = r.read<String>('key');
      final valueType = r.read<String>('value_type');
      final count = r.read<int>('c');
      grouped
          .putIfAbsent(keyLower, () => [])
          .add(_PropTypeStat(key: key, valueType: valueType, count: count));
    }

    final result = <PropertyKeyCount>[];
    for (final stats in grouped.values) {
      var best = stats.first;
      var total = 0;
      for (final s in stats) {
        total += s.count;
        if (s.count > best.count) {
          best = s;
        } else if (s.count == best.count) {
          if (s.valueType.compareTo(best.valueType) < 0) {
            best = s;
          }
        }
      }
      result.add(
        PropertyKeyCount(
          key: best.key,
          valueType: best.valueType,
          count: total,
        ),
      );
    }

    result.sort((a, b) {
      final c = b.count.compareTo(a.count);
      if (c != 0) return c;
      return a.key.compareTo(b.key);
    });
    return result;
  }

  /// Returns distinct values for a given property [key].
  Future<List<String>> propertyValues(String key, {int limit = 50}) async {
    final rows = await _readerDb
        .customSelect(
          'SELECT MIN(value_text) AS v, COUNT(*) AS c '
          'FROM properties '
          'WHERE key_lower = ? AND value_text IS NOT NULL AND value_text <> \'\' '
          'GROUP BY value_lower '
          'ORDER BY c DESC, v '
          'LIMIT ?',
          variables: [
            Variable.withString(key.toLowerCase()),
            Variable.withInt(limit),
          ],
        )
        .get();
    return rows.map((r) => r.read<String>('v')).toList();
  }

  /// Loads the entire in-memory [NameTable] from the reader database.
  Future<NameTable> loadNameTable() async {
    final filesRows = await _readerDb.select(_readerDb.files).get();
    final aliasRows = await (_readerDb.select(
      _readerDb.aliases,
    )..orderBy([(tbl) => OrderingTerm(expression: tbl.ordinal)])).get();

    final files = <VaultPath>[];
    for (final row in filesRows) {
      files.add(VaultPath(row.path));
    }

    final aliases = <VaultPath, List<String>>{};
    for (final row in aliasRows) {
      final vp = VaultPath(row.path);
      aliases.putIfAbsent(vp, () => <String>[]).add(row.alias);
    }

    return NameTable.from(files, aliases);
  }

  /// Read-only SQL query against the index database.
  ///
  /// Used by tephra_search. Only SELECT and WITH statements are permitted.
  Future<List<Map<String, Object?>>> rawSelect(
    String sql, [
    List<Object?> args = const [],
  ]) async {
    final trimmed = sql.trimLeft();
    final upper = trimmed.toUpperCase();
    if (!upper.startsWith('SELECT') && !upper.startsWith('WITH')) {
      throw ArgumentError('rawSelect only permits SELECT or WITH queries');
    }

    final variables = <Variable<Object>>[
      for (final a in args)
        if (a is String)
          Variable.withString(a)
        else if (a is int)
          Variable.withInt(a)
        else if (a is double)
          Variable.withReal(a)
        else if (a is bool)
          Variable.withBool(a)
        else
          Variable<Object>(a),
    ];

    final rows = await _readerDb.customSelect(sql, variables: variables).get();
    return rows.map((r) => r.data).toList();
  }

  /// Returns overall counts of entities stored in the index.
  Future<IndexStats> stats() async {
    final filesRow = await _readerDb
        .customSelect('SELECT COUNT(*) AS c FROM files')
        .getSingle();
    final notesRow = await _readerDb
        .customSelect('SELECT COUNT(*) AS c FROM notes')
        .getSingle();
    final linksRow = await _readerDb
        .customSelect('SELECT COUNT(*) AS c FROM links')
        .getSingle();
    final unresolvedRow = await _readerDb
        .customSelect(
          "SELECT COUNT(*) AS c FROM links WHERE resolved = 0 AND target_key <> ''",
        )
        .getSingle();
    final tagsRow = await _readerDb
        .customSelect('SELECT COUNT(DISTINCT tag_lower) AS c FROM tags')
        .getSingle();

    return IndexStats(
      files: filesRow.read<int>('c'),
      notes: notesRow.read<int>('c'),
      links: linksRow.read<int>('c'),
      unresolvedLinks: unresolvedRow.read<int>('c'),
      tags: tagsRow.read<int>('c'),
    );
  }

  /// Closes the index and terminates the background worker isolate.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _progressSub.cancel();
    await _eventsSub.cancel();
    await _runner.dispose();
    if (_isIsolate) {
      await _readerDb.close();
    }
    await _progressController.close();
    await _changesController.close();
  }

  static VaultPath? _tryVaultPath(String raw) {
    try {
      return VaultPath(raw);
    } on InvalidPathException {
      return null;
    }
  }

  static LinkRecord _rowToLink(LinkRow r) {
    return LinkRecord(
      source: VaultPath(r.source),
      targetRaw: r.targetRaw,
      targetPath: r.targetPath != null ? VaultPath(r.targetPath!) : null,
      kind: r.kind == 'embed' ? LinkKind.embed : LinkKind.link,
      syntax: r.syntax == 'markdown' ? LinkSyntax.markdown : LinkSyntax.wiki,
      heading: r.heading,
      blockRef: r.blockRef,
      alias: r.alias,
      embedSize: r.embedSize,
      start: r.startOffset,
      end: r.endOffset,
      line: r.line,
      resolved: r.resolved,
      viaAlias: r.viaAlias,
    );
  }

  static HeadingRecord _rowToHeading(HeadingRow r) {
    return HeadingRecord(
      path: VaultPath(r.path),
      level: r.level,
      text: r.headingText,
      start: r.startOffset,
      end: r.endOffset,
      line: r.line,
      ordinal: r.ordinal,
    );
  }

  static BlockRecord _rowToBlock(BlockRow r) {
    return BlockRecord(
      path: VaultPath(r.path),
      id: r.blockId,
      start: r.startOffset,
      end: r.endOffset,
      line: r.line,
      preview: r.preview,
    );
  }

  static TaskRecord _rowToTask(TaskRow r) {
    return TaskRecord(
      path: VaultPath(r.path),
      line: r.line,
      statusChar: r.statusChar,
      text: r.taskText,
      start: r.startOffset,
      end: r.endOffset,
      due: r.due,
    );
  }
}

class _PropTypeStat {
  const _PropTypeStat({
    required this.key,
    required this.valueType,
    required this.count,
  });

  final String key;
  final String valueType;
  final int count;
}
