// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/editor/edit_operation.dart';
import 'package:tephra/editor/editor_controller.dart';
import 'package:tephra/editor/editor_options.dart';
import 'package:tephra/editor/editor_registry.dart';
import 'package:tephra/reading/parse_service.dart';
import 'package:tephra/vault/note_document.dart';
import 'package:tephra/vault/note_document_store.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../helpers/fake_editor_engine.dart';

void main() {
  group('EditorController', () {
    late MemoryVaultFileSystem fs;
    late NoteDocumentStore store;
    late EditorRegistry registry;
    late VaultPath path;
    late NoteDocument doc;

    setUp(() async {
      fs = MemoryVaultFileSystem();
      store = NoteDocumentStore(fs, const SystemClock());
      registry = EditorRegistry();
      path = VaultPath('test.md');
      await fs.writeText(path, const TextDocument(text: 'Initial text'));
      doc = store.acquire(path);
      await doc.load();
    });

    tearDown(() {
      store.release(path);
    });

    test(
      'construction attaches to document and registers in EditorRegistry',
      () {
        final engine = FakeEditorEngine(doc.text);
        final controller = EditorController(
          document: doc,
          engine: engine,
          options: const EditorOptions(),
          parseService: const ParseService(),
          registry: registry,
        );

        expect(doc.editor, equals(controller));
        expect(registry.controllerFor(path), equals(controller));

        controller.dispose();
        expect(doc.editor, isNull);
        expect(registry.controllerFor(path), isNull);
      },
    );

    test('a second controller on the same document throws StateError', () {
      final engine1 = FakeEditorEngine(doc.text);
      final controller1 = EditorController(
        document: doc,
        engine: engine1,
        options: const EditorOptions(),
        parseService: const ParseService(),
        registry: registry,
      );

      final engine2 = FakeEditorEngine(doc.text);
      expect(
        () => EditorController(
          document: doc,
          engine: engine2,
          options: const EditorOptions(),
          parseService: const ParseService(),
          registry: registry,
        ),
        throwsStateError,
      );

      controller1.dispose();
    });

    test('apply(op) changes text, increments revision, sets unsaved, emits EditorEdit', () async {
      final engine = FakeEditorEngine(doc.text);
      final controller = EditorController(
        document: doc,
        engine: engine,
        options: const EditorOptions(),
        parseService: const ParseService(),
        registry: registry,
      );

      final initialRevision = doc.revision;
      final edits = <EditorEdit>[];
      final sub = controller.edits.listen(edits.add);

      controller.apply(const EditOperation(0, 0, '# '));

      expect(controller.text, equals('# Initial text'));
      expect(doc.revision, greaterThan(initialRevision));
      expect(doc.saveState, equals(SaveState.unsaved));

      await pumpEventQueue();
      expect(edits.length, equals(1));
      expect(edits.first.start, equals(0));
      expect(edits.first.deletedLength, equals(0));
      expect(edits.first.insertedText, equals('# '));
      expect(edits.first.isUndoRedo, isFalse);

      await sub.cancel();
      controller.dispose();
    });

    test('applyEdits with two edits is ONE undo step', () {
      final engine = FakeEditorEngine(doc.text);
      final controller = EditorController(
        document: doc,
        engine: engine,
        options: const EditorOptions(),
        parseService: const ParseService(),
        registry: registry,
      );

      // 'Initial text'
      // edit 1: replace 'Initial' (0..7) with 'First'
      // edit 2: replace 'text' (8..12) with 'words'
      controller.applyEdits([
        const EditOperation(0, 7, 'First'),
        const EditOperation(8, 12, 'words'),
      ]);

      expect(controller.text, equals('First words'));
      expect(controller.canUndo, isTrue);

      controller.undo();
      expect(controller.text, equals('Initial text'));

      controller.redo();
      expect(controller.text, equals('First words'));

      controller.dispose();
    });

    test('overlapping edits throw ArgumentError', () {
      final engine = FakeEditorEngine(doc.text);
      final controller = EditorController(
        document: doc,
        engine: engine,
        options: const EditorOptions(),
        parseService: const ParseService(),
        registry: registry,
      );

      expect(
        () => controller.applyEdits([
          const EditOperation(0, 5, 'A'),
          const EditOperation(3, 8, 'B'),
        ]),
        throwsArgumentError,
      );

      controller.dispose();
    });

    test('selection mapping through edits', () {
      final engine = FakeEditorEngine('hello world');
      final controller = EditorController(
        document: doc,
        engine: engine,
        options: const EditorOptions(),
        parseService: const ParseService(),
        registry: registry,
      );

      // Cursor at 'world' start (offset 6)
      controller.select(6);

      // Insert 'say ' at start (offset 0), before the selection
      controller.applyEdits([const EditOperation(0, 0, 'say ')]);

      // Caret shifted by insertion length (4)
      expect(controller.selection.baseOffset, equals(10));

      // Cursor inside deleted range clamps
      controller.select(7);
      controller.applyEdits([const EditOperation(5, 10, '')]);
      expect(controller.selection.baseOffset, equals(5));

      controller.dispose();
    });

    test('undo/redo emit edits with isUndoRedo: true', () async {
      final engine = FakeEditorEngine(doc.text);
      final controller = EditorController(
        document: doc,
        engine: engine,
        options: const EditorOptions(),
        parseService: const ParseService(),
        registry: registry,
      );

      final edits = <EditorEdit>[];
      final sub = controller.edits.listen(edits.add);

      controller.apply(const EditOperation(0, 0, 'X'));
      await pumpEventQueue();

      controller.undo();
      await pumpEventQueue();

      expect(edits.length, equals(2));
      expect(edits[1].isUndoRedo, isTrue);

      controller.redo();
      await pumpEventQueue();

      expect(edits.length, equals(3));
      expect(edits[2].isUndoRedo, isTrue);

      await sub.cancel();
      controller.dispose();
    });

    test('replaceAll changes only the middle and maps cursor', () async {
      final engine = FakeEditorEngine('prefix-old-suffix');
      final controller = EditorController(
        document: doc,
        engine: engine,
        options: const EditorOptions(),
        parseService: const ParseService(),
        registry: registry,
      );

      // Cursor at suffix (offset 12)
      controller.select(12);

      final edits = <EditorEdit>[];
      final sub = controller.edits.listen(edits.add);

      controller.replaceAll('prefix-new-longer-suffix', keepCursor: true);
      await pumpEventQueue();

      expect(controller.text, equals('prefix-new-longer-suffix'));
      // Only middle changed ('old' -> 'new-longer')
      expect(edits.length, equals(1));
      expect(edits.first.start, equals(7)); // 'prefix-'.length
      expect(edits.first.deletedLength, equals(3)); // 'old'.length
      expect(edits.first.insertedText, equals('new-longer'));

      // Cursor at suffix shifted by delta (10 - 3 = +7)
      expect(controller.selection.baseOffset, equals(19));

      // With keepCursor: false -> caret to 0
      controller.replaceAll(
        'prefix-new-longer-suffix-extra',
        keepCursor: false,
      );
      expect(controller.selection.baseOffset, equals(0));

      await sub.cancel();
      controller.dispose();
    });

    test('select(5) beyond length clamps', () {
      final engine = FakeEditorEngine('abc');
      final controller = EditorController(
        document: doc,
        engine: engine,
        options: const EditorOptions(),
        parseService: const ParseService(),
        registry: registry,
      );

      controller.select(100);
      expect(controller.selection.baseOffset, equals(3));

      controller.dispose();
    });

    test('edit then undo to original then doc.save() writes nothing', () async {
      final initialWriteCount = fs.writeCount;
      final engine = FakeEditorEngine(doc.text);
      final controller = EditorController(
        document: doc,
        engine: engine,
        options: const EditorOptions(),
        parseService: const ParseService(),
        registry: registry,
      );

      controller.apply(const EditOperation(0, 0, 'Edit '));
      expect(doc.isDirty, isTrue);

      controller.undo();
      expect(controller.text, equals('Initial text'));
      expect(doc.isDirty, isFalse);

      final outcome = await doc.save();
      expect(outcome, equals(SaveOutcome.unchanged));
      expect(fs.writeCount, equals(initialWriteCount));

      controller.dispose();
    });

    test(
      'blur (FakeEditorEngine.setFocus(false)) triggers doc.save()',
      () async {
        final initialWriteCount = fs.writeCount;
        final engine = FakeEditorEngine(doc.text);
        final controller = EditorController(
          document: doc,
          engine: engine,
          options: const EditorOptions(),
          parseService: const ParseService(),
          registry: registry,
        );

        // Blur when clean -> no write
        engine.setFocus(true);
        engine.setFocus(false);
        await pumpEventQueue();
        expect(fs.writeCount, equals(initialWriteCount));

        // Edit -> dirty -> blur triggers save
        controller.apply(const EditOperation(0, 0, 'Dirty '));
        expect(doc.isDirty, isTrue);

        engine.setFocus(true);
        engine.setFocus(false);
        await pumpEventQueue();

        expect(fs.writeCount, equals(initialWriteCount + 1));
        expect(doc.isDirty, isFalse);

        controller.dispose();
      },
    );
  });
}
