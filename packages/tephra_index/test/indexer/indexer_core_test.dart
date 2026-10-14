// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/src/db/index_database.dart';
import 'package:tephra_index/src/db/open_index_database.dart';
import 'package:tephra_index/src/indexer/indexer_core.dart';
import 'package:tephra_index/src/model/index_event.dart';
import 'package:tephra_index/src/model/index_options.dart';
import 'package:tephra_index/src/model/index_progress.dart';
import 'package:tephra_vault/tephra_vault.dart';
import 'package:test/test.dart';

class CountingVaultFileSystem implements VaultFileSystem {
  CountingVaultFileSystem(this.inner);
  final VaultFileSystem inner;
  int readBytesCount = 0;

  @override
  String get rootDisplayPath => inner.rootDisplayPath;

  @override
  Future<List<VaultEntry>> list({
    VaultPath folder = VaultPath.root,
    bool recursive = true,
  }) => inner.list(folder: folder, recursive: recursive);

  @override
  Future<VaultEntry?> stat(VaultPath path) => inner.stat(path);

  @override
  Future<List<int>> readBytes(VaultPath path) {
    readBytesCount++;
    return inner.readBytes(path);
  }

  @override
  Future<TextDocument> readText(VaultPath path) => inner.readText(path);

  @override
  Future<void> writeBytes(VaultPath path, List<int> bytes) =>
      inner.writeBytes(path, bytes);

  @override
  Future<void> writeText(VaultPath path, TextDocument doc) =>
      inner.writeText(path, doc);

  @override
  Future<void> createFolder(VaultPath path) => inner.createFolder(path);

  @override
  Future<void> move(VaultPath from, VaultPath to) => inner.move(from, to);

  @override
  Future<void> delete(
    VaultPath path, {
    TrashMode mode = TrashMode.vaultTrash,
  }) => inner.delete(path, mode: mode);

  @override
  Stream<VaultChange> watch() => inner.watch();

  @override
  Future<void> dispose() => inner.dispose();
}

class FlakyVaultFileSystem implements VaultFileSystem {
  FlakyVaultFileSystem(this.inner, {required this.failOncePath});
  final VaultFileSystem inner;
  final VaultPath failOncePath;
  bool failed = false;

  @override
  String get rootDisplayPath => inner.rootDisplayPath;

  @override
  Future<List<VaultEntry>> list({
    VaultPath folder = VaultPath.root,
    bool recursive = true,
  }) => inner.list(folder: folder, recursive: recursive);

  @override
  Future<VaultEntry?> stat(VaultPath path) => inner.stat(path);

  @override
  Future<List<int>> readBytes(VaultPath path) async {
    if (path == failOncePath && !failed) {
      failed = true;
      throw FileNotFoundException(path);
    }
    return inner.readBytes(path);
  }

  @override
  Future<TextDocument> readText(VaultPath path) => inner.readText(path);

  @override
  Future<void> writeBytes(VaultPath path, List<int> bytes) =>
      inner.writeBytes(path, bytes);

  @override
  Future<void> writeText(VaultPath path, TextDocument doc) =>
      inner.writeText(path, doc);

  @override
  Future<void> createFolder(VaultPath path) => inner.createFolder(path);

  @override
  Future<void> move(VaultPath from, VaultPath to) => inner.move(from, to);

  @override
  Future<void> delete(
    VaultPath path, {
    TrashMode mode = TrashMode.vaultTrash,
  }) => inner.delete(path, mode: mode);

  @override
  Stream<VaultChange> watch() => inner.watch();

  @override
  Future<void> dispose() => inner.dispose();
}

class FixedClock implements Clock {
  FixedClock(this.fixedTime);
  DateTime fixedTime;

  @override
  DateTime now() => fixedTime;
}

void main() {
  group('IndexerCore', () {
    late TephraIndexDatabase db;
    late MemoryVaultFileSystem fs;
    late IndexerCore indexer;
    late List<IndexProgress> progressReports;
    late List<IndexEvent> events;
    final fixedClock = FixedClock(DateTime.utc(2026, 10, 14, 12, 0, 0));

    Future<void> write(VaultFileSystem vfs, String path, String text) async {
      final bytes = utf8.encode(text);
      await vfs.writeBytes(VaultPath(path), bytes);
    }

    setUp(() async {
      final opened = await openMemoryIndexDatabase();
      db = opened.db;
      fs = MemoryVaultFileSystem(clock: fixedClock);
      progressReports = [];
      events = [];

      indexer = IndexerCore(
        db: db,
        fs: fs,
        options: const IndexOptions(excludedFolders: ['Archive']),
        clock: fixedClock,
        onProgress: progressReports.add,
        onEvent: events.add,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('full index stores notes, links and fts rows', () async {
      await write(fs, 'A.md', '[[B]] #x');
      await write(fs, 'B.md', '# Hi');
      await fs.writeBytes(VaultPath('img.png'), [1, 2, 3]);

      await indexer.reconcile();

      final files = await db.select(db.files).get();
      expect(files.length, equals(3));

      final notes = await db.select(db.notes).get();
      expect(notes.length, equals(2));

      final links = await db.select(db.links).get();
      expect(links.length, equals(1));
      expect(links.first.source, equals('A.md'));
      expect(links.first.targetPath, equals('B.md'));
      expect(links.first.resolved, isTrue);

      final tags = await db.select(db.tags).get();
      expect(tags.length, equals(1));
      expect(tags.first.tag, equals('x'));

      final headings = await db.select(db.headings).get();
      expect(headings.length, equals(1));
      expect(headings.first.headingText, equals('Hi'));

      final wordRows = await db
          .customSelect(
            "SELECT rowid FROM fts_words WHERE fts_words MATCH 'Hi'",
          )
          .get();
      expect(wordRows.length, equals(1));
      final bNote = notes.firstWhere((n) => n.path == 'B.md');
      expect(wordRows.first.read<int>('rowid'), equals(bNote.id));

      final trigramRows = await db
          .customSelect(
            "SELECT rowid FROM fts_trigram WHERE fts_trigram MATCH '\"# H\"'",
          )
          .get();
      expect(trigramRows.length, equals(1));
      expect(trigramRows.first.read<int>('rowid'), equals(bNote.id));
    });

    test('alias resolution after full index', () async {
      await write(fs, 'A.md', '[[First]]');
      await write(fs, 'Z.md', '---\naliases: [First]\n---\n');

      await indexer.reconcile();

      final links = await db.select(db.links).get();
      expect(links.length, equals(1));
      expect(links.first.source, equals('A.md'));
      expect(links.first.targetPath, equals('Z.md'));
      expect(links.first.resolved, isTrue);
      expect(links.first.viaAlias, isTrue);
    });

    test('reconcile fast path does not re-read unchanged files', () async {
      await write(fs, 'A.md', 'Content A');
      await write(fs, 'B.md', 'Content B');

      final countingFs = CountingVaultFileSystem(fs);
      final countingIndexer = IndexerCore(
        db: db,
        fs: countingFs,
        options: const IndexOptions(),
        clock: fixedClock,
        onProgress: (_) {},
        onEvent: (_) {},
      );

      await countingIndexer.reconcile();
      final firstReads = countingFs.readBytesCount;
      expect(firstReads, equals(2));

      // Second reconcile without changes
      countingFs.readBytesCount = 0;
      await countingIndexer.reconcile();
      expect(countingFs.readBytesCount, equals(0));
    });

    test('reconcile re-reads changed mtime but skips equal hash', () async {
      await write(fs, 'A.md', 'Content A');
      await indexer.reconcile();

      final originalNotes = await db.select(db.notes).get();
      final originalNoteId = originalNotes.first.id;

      // Advance clock and re-write same content
      fixedClock.fixedTime = fixedClock.fixedTime.add(
        const Duration(seconds: 10),
      );
      await write(fs, 'A.md', 'Content A');

      final countingFs = CountingVaultFileSystem(fs);
      final testIndexer = IndexerCore(
        db: db,
        fs: countingFs,
        options: const IndexOptions(),
        clock: fixedClock,
        onProgress: (_) {},
        onEvent: (_) {},
      );

      await testIndexer.reconcile();
      expect(countingFs.readBytesCount, equals(1));

      final updatedNotes = await db.select(db.notes).get();
      expect(updatedNotes.first.id, equals(originalNoteId));
    });

    test('creating a note resolves previously unresolved links', () async {
      await write(fs, 'A.md', '[[New]]');
      await indexer.reconcile();

      var link = (await db.select(db.links).get()).first;
      expect(link.resolved, isFalse);

      events.clear();
      await write(fs, 'New.md', '# New Note');
      await indexer.apply(FileCreated(VaultPath('New.md')));

      link = (await db.select(db.links).get()).first;
      expect(link.resolved, isTrue);
      expect(link.targetPath, equals('New.md'));

      expect(events.isNotEmpty, isTrue);
      final changed = events.last.changedPaths.map((p) => p.value).toSet();
      expect(changed, containsAll(['A.md', 'New.md']));
    });

    test('deleting a note unresolves links', () async {
      await write(fs, 'A.md', '[[New]]');
      await write(fs, 'New.md', 'Content');
      await indexer.reconcile();

      var link = (await db.select(db.links).get()).first;
      expect(link.resolved, isTrue);

      await fs.delete(VaultPath('New.md'));
      await indexer.apply(FileDeleted(VaultPath('New.md')));

      link = (await db.select(db.links).get()).first;
      expect(link.resolved, isFalse);
      expect(link.targetPath, isNull);
    });

    test('deleting a note falls back to the next candidate', () async {
      await write(fs, 'Note.md', 'Root Note');
      await write(fs, 'Sub/Note.md', 'Sub Note');
      await write(fs, 'A.md', '[[Note]]');
      await indexer.reconcile();

      var link = (await (db.select(
        db.links,
      )..where((l) => l.source.equals('A.md'))).get()).first;
      expect(link.targetPath, equals('Note.md'));

      await fs.delete(VaultPath('Note.md'));
      await indexer.apply(FileDeleted(VaultPath('Note.md')));

      link = (await (db.select(
        db.links,
      )..where((l) => l.source.equals('A.md'))).get()).first;
      expect(link.targetPath, equals('Sub/Note.md'));
      expect(link.resolved, isTrue);
    });

    test('renaming a note re-resolves', () async {
      await write(fs, 'A.md', '[[Old]] [[New]]');
      await write(fs, 'Old.md', 'Old content');
      await indexer.reconcile();

      await fs.move(VaultPath('Old.md'), VaultPath('New.md'));
      await indexer.apply(
        FileMoved(VaultPath('New.md'), from: VaultPath('Old.md')),
      );

      final links = await db.select(db.links).get();
      final oldLink = links.firstWhere((l) => l.targetRaw == 'Old');
      final newLink = links.firstWhere((l) => l.targetRaw == 'New');

      expect(oldLink.resolved, isFalse);
      expect(newLink.resolved, isTrue);
      expect(newLink.targetPath, equals('New.md'));

      final oldFiles = await (db.select(
        db.files,
      )..where((f) => f.path.equals('Old.md'))).get();
      expect(oldFiles, isEmpty);
    });

    test('alias edit re-resolves', () async {
      await write(fs, 'A.md', '[[Nick]]');
      await write(fs, 'P.md', 'No aliases yet');
      await indexer.reconcile();

      var link = (await db.select(db.links).get()).first;
      expect(link.resolved, isFalse);

      await write(fs, 'P.md', '---\naliases: [Nick]\n---\nHas alias');
      await indexer.apply(FileModified(VaultPath('P.md')));

      link = (await db.select(db.links).get()).first;
      expect(link.resolved, isTrue);
      expect(link.targetPath, equals('P.md'));
      expect(link.viaAlias, isTrue);

      await write(fs, 'P.md', 'Removed alias');
      await indexer.apply(FileModified(VaultPath('P.md')));

      link = (await db.select(db.links).get()).first;
      expect(link.resolved, isFalse);
    });

    test('folder move moves every file', () async {
      await write(fs, 'F/a.md', 'Note a');
      await write(fs, 'F/G/b.md', 'Note b');
      await write(fs, 'X.md', '[[F/a]] [[b]]');
      await indexer.reconcile();

      await fs.move(VaultPath('F'), VaultPath('H'));
      await indexer.apply(FileMoved(VaultPath('H'), from: VaultPath('F')));

      final files = await db.select(db.files).get();
      final filePaths = files.map((f) => f.path).toSet();
      expect(filePaths, containsAll(['H/a.md', 'H/G/b.md', 'X.md']));
      expect(filePaths, isNot(contains('F/a.md')));

      final links = await db.select(db.links).get();
      final linkFa = links.firstWhere((l) => l.targetRaw == 'F/a');
      final linkB = links.firstWhere((l) => l.targetRaw == 'b');

      expect(linkFa.resolved, isFalse);
      expect(linkB.resolved, isTrue);
      expect(linkB.targetPath, equals('H/G/b.md'));
    });

    test('folder delete removes every file', () async {
      await write(fs, 'F/a.md', 'Note a');
      await write(fs, 'F/b.md', 'Note b');
      await indexer.reconcile();

      await fs.delete(VaultPath('F'));
      await indexer.apply(FileDeleted(VaultPath('F')));

      final files = await db.select(db.files).get();
      expect(files, isEmpty);
    });

    test('ignored paths are never indexed', () async {
      await write(fs, '.obsidian/app.json', '{}');
      await write(fs, '.trash/x.md', 'trash');
      await write(fs, 'node_modules/y.md', 'code');
      await write(fs, 'Archive/z.md', 'archive');
      await write(fs, 'Valid.md', 'valid');

      await indexer.reconcile();

      final files = await db.select(db.files).get();
      expect(files.map((f) => f.path).toList(), equals(['Valid.md']));
    });

    test('same-size edit in same millisecond is picked up', () async {
      await write(fs, 'A.md', 'aaaa');
      await indexer.reconcile();

      // Edit to same byte length at same fixed clock time
      await write(fs, 'A.md', 'bbbb');
      await indexer.apply(FileModified(VaultPath('A.md')));

      final ftsRows = await db
          .customSelect(
            "SELECT rowid FROM fts_trigram WHERE fts_trigram MATCH '\"bbbb\"'",
          )
          .get();
      expect(ftsRows.length, equals(1));
    });

    test('unreadable file is skipped and retried', () async {
      await write(fs, 'Good.md', 'Good content');
      await write(fs, 'Bad.md', 'Bad content');

      final flaky = FlakyVaultFileSystem(fs, failOncePath: VaultPath('Bad.md'));
      final flakyIndexer = IndexerCore(
        db: db,
        fs: flaky,
        options: const IndexOptions(),
        clock: fixedClock,
        onProgress: (_) {},
        onEvent: (_) {},
      );

      await flakyIndexer.reconcile();
      var files = await db.select(db.files).get();
      expect(files.map((f) => f.path).toList(), equals(['Good.md']));

      // Second reconcile: now readable!
      await flakyIndexer.reconcile();
      files = await db.select(db.files).get();
      expect(files.map((f) => f.path).toSet(), equals({'Good.md', 'Bad.md'}));
    });

    test('rebuild produces the same rows', () async {
      for (var i = 1; i <= 20; i++) {
        await write(
          fs,
          'Note$i.md',
          '# Note $i\n[[Note${i == 20 ? 1 : i + 1}]] #tag$i',
        );
      }
      await indexer.reconcile();

      Future<List<String>> dumpRows() async {
        final lines = <String>[];
        final files = await (db.select(
          db.files,
        )..orderBy([(f) => OrderingTerm.asc(f.path)])).get();
        for (final f in files) {
          lines.add('FILE:${f.path}:${f.hash}:${f.size}:${f.isNote}');
        }
        final notes = await (db.select(
          db.notes,
        )..orderBy([(n) => OrderingTerm.asc(n.path)])).get();
        for (final n in notes) {
          lines.add('NOTE:${n.path}:${n.title}:${n.wordCount}');
        }
        final links =
            await (db.select(db.links)..orderBy([
                  (l) => OrderingTerm.asc(l.source),
                  (l) => OrderingTerm.asc(l.targetRaw),
                ]))
                .get();
        for (final l in links) {
          lines.add(
            'LINK:${l.source}:${l.targetRaw}:${l.targetPath}:${l.resolved}',
          );
        }
        final tags =
            await (db.select(db.tags)..orderBy([
                  (t) => OrderingTerm.asc(t.path),
                  (t) => OrderingTerm.asc(t.tag),
                ]))
                .get();
        for (final t in tags) {
          lines.add('TAG:${t.path}:${t.tag}');
        }
        return lines;
      }

      final before = await dumpRows();
      await indexer.rebuild();
      final after = await dumpRows();

      expect(after, equals(before));
    });
  });
}
