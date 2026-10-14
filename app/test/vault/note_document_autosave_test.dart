// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/editor/edit_operation.dart';
import 'package:tephra/editor/editor_controller.dart';
import 'package:tephra/editor/editor_options.dart';
import 'package:tephra/reading/parse_service.dart';
import 'package:tephra/vault/note_document.dart';
import 'package:tephra/vault/note_document_store.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../helpers/fake_editor_engine.dart';

final class _CountingVaultFileSystem implements VaultFileSystem {
  _CountingVaultFileSystem(this._inner);

  final MemoryVaultFileSystem _inner;
  int writeCount = 0;
  bool shouldFail = false;

  @override
  String get rootDisplayPath => _inner.rootDisplayPath;

  @override
  Future<List<VaultEntry>> list({
    VaultPath folder = VaultPath.root,
    bool recursive = true,
  }) => _inner.list(folder: folder, recursive: recursive);

  @override
  Future<VaultEntry?> stat(VaultPath path) => _inner.stat(path);

  @override
  Future<List<int>> readBytes(VaultPath path) => _inner.readBytes(path);

  @override
  Future<TextDocument> readText(VaultPath path) => _inner.readText(path);

  @override
  Future<void> writeBytes(VaultPath path, List<int> bytes) async {
    if (shouldFail) {
      throw const PermissionDeniedException('write denied');
    }
    writeCount++;
    return _inner.writeBytes(path, bytes);
  }

  @override
  Future<void> writeText(VaultPath path, TextDocument doc) async {
    if (shouldFail) {
      throw const PermissionDeniedException('write denied');
    }
    writeCount++;
    return _inner.writeText(path, doc);
  }

  @override
  Future<void> createFolder(VaultPath path) => _inner.createFolder(path);

  @override
  Future<void> move(VaultPath from, VaultPath to) => _inner.move(from, to);

  @override
  Future<void> delete(
    VaultPath path, {
    TrashMode mode = TrashMode.vaultTrash,
  }) => _inner.delete(path, mode: mode);

  @override
  Stream<VaultChange> watch() => _inner.watch();

  @override
  Future<void> dispose() => _inner.dispose();
}

void main() {
  group('NoteDocument Autosave', () {
    const clock = SystemClock();
    late MemoryVaultFileSystem memFs;
    late _CountingVaultFileSystem fs;
    late VaultPath path;

    setUp(() async {
      memFs = MemoryVaultFileSystem();
      fs = _CountingVaultFileSystem(memFs);
      path = VaultPath('note.md');
      await fs.writeText(path, const TextDocument(text: 'Initial text'));
      fs.writeCount = 0;
    });

    testWidgets(
      'an edit followed by 999 ms -> no write; at 1,000 ms -> exactly one write',
      (tester) async {
        final doc = NoteDocument(path: path, fs: fs, clock: clock);
        await doc.load();
        expect(fs.writeCount, 0);

        doc.edit(const EditOperation(0, 0, 'Prefix '));
        expect(doc.isDirty, isTrue);

        await tester.pump(const Duration(milliseconds: 999));
        expect(fs.writeCount, 0);

        await tester.pump(const Duration(milliseconds: 1));
        expect(fs.writeCount, 1);
        expect(doc.saveState, SaveState.saved);
        expect(doc.savedText, 'Prefix Initial text');

        doc.dispose();
      },
    );

    testWidgets('ten edits 100 ms apart -> one write 1,000 ms after the last', (
      tester,
    ) async {
      final doc = NoteDocument(path: path, fs: fs, clock: clock);
      await doc.load();
      expect(fs.writeCount, 0);

      for (var i = 0; i < 10; i++) {
        doc.edit(EditOperation(0, 0, '$i'));
        await tester.pump(const Duration(milliseconds: 100));
        expect(fs.writeCount, 0);
      }

      // 999 ms after 10th edit (100 ms already elapsed in loop + 899 ms = 999 ms)
      await tester.pump(const Duration(milliseconds: 899));
      expect(fs.writeCount, 0);

      await tester.pump(const Duration(milliseconds: 1));
      expect(fs.writeCount, 1);
      expect(doc.saveState, SaveState.saved);

      doc.dispose();
    });

    testWidgets(
      'edit + save() before the timer -> one write and the timer is cancelled (no second write)',
      (tester) async {
        final doc = NoteDocument(path: path, fs: fs, clock: clock);
        await doc.load();

        doc.edit(const EditOperation(0, 0, 'Fast '));
        await tester.pump(const Duration(milliseconds: 200));
        expect(fs.writeCount, 0);

        final outcome = await doc.save();
        expect(outcome, SaveOutcome.written);
        expect(fs.writeCount, 1);

        // Wait 1,500 ms -> no second write
        await tester.pump(const Duration(milliseconds: 1500));
        expect(fs.writeCount, 1);

        doc.dispose();
      },
    );

    testWidgets('undo-to-original before the timer -> no write at all', (
      tester,
    ) async {
      final doc = NoteDocument(path: path, fs: fs, clock: clock);
      await doc.load();

      doc.edit(const EditOperation(0, 0, 'Temporary '));
      await tester.pump(const Duration(milliseconds: 500));

      doc.setText('Initial text');
      expect(doc.isDirty, isFalse);

      await tester.pump(const Duration(milliseconds: 1500));
      expect(fs.writeCount, 0);
      expect(doc.saveState, SaveState.saved);

      doc.dispose();
    });

    testWidgets('read-only never writes', (tester) async {
      final malformedPath = VaultPath('malformed.md');
      memFs.putBytes('malformed.md', [0xFF, 0xFE, 0xFD]);
      fs.writeCount = 0;

      final doc = NoteDocument(path: malformedPath, fs: fs, clock: clock);
      await doc.load();
      expect(doc.isReadOnly, isTrue);

      final editResult = doc.edit(const EditOperation(0, 0, 'test'));
      expect(editResult, isFalse);

      await tester.pump(const Duration(milliseconds: 1500));
      expect(fs.writeCount, 0);

      final outcome = await doc.save();
      expect(outcome, SaveOutcome.readOnly);
      expect(fs.writeCount, 0);

      doc.dispose();
    });

    testWidgets('blur (FakeEditorEngine) saves immediately', (tester) async {
      final doc = NoteDocument(path: path, fs: fs, clock: clock);
      await doc.load();

      final engine = FakeEditorEngine(doc.text);
      final controller = EditorController(
        document: doc,
        engine: engine,
        parseService: const ParseService(),
        options: const EditorOptions(),
      );

      engine.setFocus(true);
      controller.apply(const EditOperation(0, 0, 'Edited '));
      expect(doc.isDirty, isTrue);
      expect(fs.writeCount, 0);

      // Blur
      engine.setFocus(false);
      await tester.pump();

      expect(fs.writeCount, 1);
      expect(doc.saveState, SaveState.saved);

      controller.dispose();
      doc.dispose();
    });

    testWidgets('flushAll saves every dirty doc', (tester) async {
      final store = NoteDocumentStore(fs, clock);
      final path1 = VaultPath('note1.md');
      final path2 = VaultPath('note2.md');
      await fs.writeText(path1, const TextDocument(text: 'Text 1'));
      await fs.writeText(path2, const TextDocument(text: 'Text 2'));
      fs.writeCount = 0;

      final doc1 = store.acquire(path1);
      final doc2 = store.acquire(path2);
      await doc1.load();
      await doc2.load();

      doc1.edit(const EditOperation(0, 0, 'A '));
      doc2.edit(const EditOperation(0, 0, 'B '));
      expect(doc1.isDirty, isTrue);
      expect(doc2.isDirty, isTrue);
      expect(fs.writeCount, 0);

      await store.flushAll();
      expect(fs.writeCount, 2);
      expect(doc1.isDirty, isFalse);
      expect(doc2.isDirty, isFalse);

      store.dispose();
    });

    testWidgets(
      'a failing fs -> saveState == error, a later edit retries and succeeds',
      (tester) async {
        final doc = NoteDocument(path: path, fs: fs, clock: clock);
        await doc.load();

        fs.shouldFail = true;
        doc.edit(const EditOperation(0, 0, 'Fail '));

        await tester.pump(const Duration(milliseconds: 1000));
        expect(doc.saveState, SaveState.error);
        expect(doc.lastError, isNotNull);

        // Fix failure and make another edit
        fs.shouldFail = false;
        doc.edit(const EditOperation(0, 0, 'Retry '));

        await tester.pump(const Duration(milliseconds: 1000));
        expect(doc.saveState, SaveState.saved);
        expect(doc.isDirty, isFalse);

        doc.dispose();
      },
    );

    testWidgets('vault close flushes first', (tester) async {
      var flushed = false;
      final store = NoteDocumentStore(
        fs,
        clock,
        onFlushed: () {
          flushed = true;
        },
      );
      final doc = store.acquire(path);
      await doc.load();

      doc.edit(const EditOperation(0, 0, 'Closing '));
      expect(doc.isDirty, isTrue);

      await store.flushAll();
      expect(flushed, isTrue);
      expect(doc.isDirty, isFalse);
      expect(fs.writeCount, 1);

      store.dispose();
    });
  });
}
