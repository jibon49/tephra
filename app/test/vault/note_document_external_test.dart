// © 2026 Tephra. All rights reserved.

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

void main() {
  group('NoteDocument External Changes', () {
    late ManualClock clock;
    late MemoryVaultFileSystem fs;
    late NoteDocumentStore store;
    late VaultPath path;

    setUp(() async {
      clock = ManualClock(DateTime(2026, 10, 11, 9, 30));
      fs = MemoryVaultFileSystem(clock: clock);
      store = NoteDocumentStore(fs, clock);
      store.start();
      path = VaultPath('note.md');
      await fs.writeText(
        path,
        const TextDocument(text: 'Line 1\nLine 2\nLine 3'),
      );
    });

    tearDown(() {
      store.dispose();
      fs.dispose();
    });

    testWidgets('clean doc reloads silently and revision increments', (
      tester,
    ) async {
      final doc = store.acquire(path);
      await pumpEventQueue();
      final rev0 = doc.revision;

      fs.putText('note.md', 'Line 1\nLine 2 modified\nLine 3');
      fs.emit(FileModified(path));
      await pumpEventQueue();

      expect(doc.text, 'Line 1\nLine 2 modified\nLine 3');
      expect(doc.revision, greaterThan(rev0));
      expect(doc.isDirty, isFalse);
    });

    testWidgets(
      'editor attached -> replaceAll called with keepCursor: true and the undo history cleared',
      (tester) async {
        final doc = store.acquire(path);
        await pumpEventQueue();

        final engine = FakeEditorEngine(doc.text);
        final controller = EditorController(
          document: doc,
          engine: engine,
          parseService: const ParseService(),
          options: const EditorOptions(),
        );

        // Perform an edit then undo to make undo history non-empty
        controller.apply(const EditOperation(0, 0, 'Temp '));
        expect(controller.canUndo, isTrue);
        controller.undo();
        expect(doc.isDirty, isFalse);

        fs.putText('note.md', 'Line 1\nLine 2 changed\nLine 3');
        fs.emit(FileModified(path));
        await pumpEventQueue();

        expect(controller.text, 'Line 1\nLine 2 changed\nLine 3');
        expect(controller.canUndo, isFalse);

        controller.dispose();
      },
    );

    testWidgets(
      'dirty doc + non-overlapping external change -> merged text, still dirty, then autosave writes the merged text',
      (tester) async {
        final lines = List.generate(20, (i) => 'Line ${i + 1}').join('\n');
        await fs.writeText(path, TextDocument(text: lines));
        final doc = store.acquire(path);
        await pumpEventQueue();

        // Dirty edit at line 2: replace "Line 2" with "Line 2 mine"
        final l2Pos = lines.indexOf('Line 2');
        doc.edit(EditOperation(l2Pos, l2Pos + 6, 'Line 2 mine'));
        expect(doc.isDirty, isTrue);

        // External edit at line 18: replace "Line 18" with "Line 18 theirs"
        final externalLines = lines.replaceFirst('Line 18', 'Line 18 theirs');
        fs.putText('note.md', externalLines);
        fs.emit(FileModified(path));
        await pumpEventQueue();

        expect(doc.text, contains('Line 2 mine'));
        expect(doc.text, contains('Line 18 theirs'));
        expect(doc.isDirty, isTrue);

        // Autosave writes the merged text after 1,000 ms
        await tester.pump(const Duration(milliseconds: 1000));
        await pumpEventQueue();

        expect(doc.saveState, SaveState.saved);
        expect(fs.textOf('note.md'), contains('Line 2 mine'));
        expect(fs.textOf('note.md'), contains('Line 18 theirs'));
      },
    );

    testWidgets(
      'dirty + overlapping change -> pendingConflict set, no write happens while pending, save() returns conflict',
      (tester) async {
        final doc = store.acquire(path);
        await pumpEventQueue();

        doc.edit(const EditOperation(0, 6, 'Mine'));
        expect(doc.isDirty, isTrue);

        fs.putText('note.md', 'Theirs\nLine 2\nLine 3');
        fs.emit(FileModified(path));
        await pumpEventQueue();

        expect(doc.pendingConflict, isNotNull);
        expect(doc.pendingConflict!.mine, startsWith('Mine'));
        expect(doc.pendingConflict!.theirs.text, startsWith('Theirs'));

        // Wait past autosave timer -> no write while conflict is pending
        await tester.pump(const Duration(milliseconds: 1500));
        expect(fs.textOf('note.md'), startsWith('Theirs'));

        final outcome = await doc.save();
        expect(outcome, SaveOutcome.conflict);
        expect(fs.textOf('note.md'), startsWith('Theirs'));
      },
    );

    testWidgets(
      'external change identical to what we wrote -> ignored (hash equal)',
      (tester) async {
        final doc = store.acquire(path);
        await pumpEventQueue();

        doc.edit(const EditOperation(0, 0, 'New '));
        await doc.save();
        final rev = doc.revision;

        fs.emit(FileModified(path));
        await pumpEventQueue();

        expect(doc.revision, equals(rev));
      },
    );

    testWidgets(
      'BOM/ending-only change -> base flags updated, text untouched',
      (tester) async {
        final doc = store.acquire(path);
        await pumpEventQueue();
        expect(doc.base.lineEnding, LineEnding.lf);

        // External change with CRLF
        await fs.writeText(
          path,
          const TextDocument(
            text: 'Line 1\r\nLine 2\r\nLine 3',
            lineEnding: LineEnding.crlf,
          ),
        );
        fs.emit(FileModified(path));
        await pumpEventQueue();

        expect(doc.base.lineEnding, LineEnding.crlf);
        expect(doc.text, 'Line 1\nLine 2\nLine 3');
      },
    );

    testWidgets(
      'external change to a malformed file -> read-only banner, buffer untouched',
      (tester) async {
        final doc = store.acquire(path);
        await pumpEventQueue();

        doc.edit(const EditOperation(0, 0, 'Buffer text '));
        expect(doc.isDirty, isTrue);

        fs.putBytes('note.md', [0xFF, 0xFE, 0xFD]);
        fs.emit(FileModified(path));
        await pumpEventQueue();

        expect(doc.isReadOnly, isTrue);
        expect(doc.text, startsWith('Buffer text '));
      },
    );

    testWidgets('FileDeleted -> isDeletedOnDisk, buffer kept', (tester) async {
      final doc = store.acquire(path);
      await pumpEventQueue();

      await fs.delete(path, mode: TrashMode.permanent);
      fs.emit(FileDeleted(path));
      await pumpEventQueue();

      expect(doc.isDeletedOnDisk, isTrue);
      expect(doc.text, 'Line 1\nLine 2\nLine 3');
    });

    testWidgets('re-creation -> reload/merge', (tester) async {
      final doc = store.acquire(path);
      await pumpEventQueue();

      await fs.delete(path, mode: TrashMode.permanent);
      fs.emit(FileDeleted(path));
      await pumpEventQueue();
      expect(doc.isDeletedOnDisk, isTrue);

      fs.putText('note.md', 'Recreated externally');
      fs.emit(FileCreated(path));
      await pumpEventQueue();

      expect(doc.isDeletedOnDisk, isFalse);
      expect(doc.text, 'Recreated externally');
    });

    testWidgets('Recreate file writes the buffer', (tester) async {
      final doc = store.acquire(path);
      await pumpEventQueue();

      doc.edit(const EditOperation(0, 0, 'My restored work '));
      await fs.delete(path, mode: TrashMode.permanent);
      fs.emit(FileDeleted(path));
      await pumpEventQueue();
      expect(doc.isDeletedOnDisk, isTrue);

      final outcome = await doc.save(force: true);
      expect(outcome, SaveOutcome.written);
      expect(doc.isDeletedOnDisk, isFalse);
      expect(fs.textOf('note.md'), startsWith('My restored work '));
    });

    testWidgets(
      'stat guard: modify the file without emitting a watcher event, then save() notices external change',
      (tester) async {
        final doc = store.acquire(path);
        await pumpEventQueue();

        doc.edit(const EditOperation(0, 6, 'Mine'));
        expect(doc.isDirty, isTrue);

        // Advance clock and modify disk without emitting watcher event
        clock.advance(const Duration(minutes: 5));
        fs.putText('note.md', 'External silent modification\nLine 2\nLine 3');

        // Attempting to save hits stat guard, merges or creates conflict
        final outcome = await doc.save();
        expect(outcome, SaveOutcome.conflict);
        expect(doc.pendingConflict, isNotNull);
        // Disk content preserved
        expect(
          fs.textOf('note.md'),
          startsWith('External silent modification'),
        );
      },
    );
  });
}
