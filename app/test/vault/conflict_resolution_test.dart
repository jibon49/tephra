// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/vault/conflict_resolution.dart';
import 'package:tephra/vault/note_document.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

void main() {
  group('Conflict Resolution', () {
    late ManualClock clock;
    late MemoryVaultFileSystem fs;
    late VaultPath path;

    setUp(() async {
      clock = ManualClock(DateTime(2026, 10, 11, 9, 30, 0));
      fs = MemoryVaultFileSystem(clock: clock);
      path = VaultPath('Note.md');
      await fs.writeText(path, const TextDocument(text: 'Base'));
    });

    Future<NoteDocument> setupConflictDoc([
      String theirsText = 'Theirs',
    ]) async {
      final doc = NoteDocument(path: path, fs: fs, clock: clock);
      await doc.load();
      doc.setText('Mine');

      // External modification causing conflict
      fs.putText('Note.md', theirsText);
      await doc.onExternalChange();
      expect(doc.pendingConflict, isNotNull);
      return doc;
    }

    testWidgets('keepMine -> disk gets mine on next save', (tester) async {
      final doc = await setupConflictDoc();

      await resolveConflict(doc, ConflictChoice.keepMine, fs: fs, clock: clock);
      expect(doc.pendingConflict, isNull);
      expect(doc.text, 'Mine');
      // keepMine saves immediately per spec
      expect(fs.textOf('Note.md'), 'Mine');
      expect(doc.saveState, SaveState.saved);

      doc.dispose();
    });

    testWidgets(
      'takeTheirs -> doc text = theirs, recovery file exists at .tephra/cache/recovery/20261011093000-Note.md',
      (tester) async {
        final doc = await setupConflictDoc();

        await resolveConflict(
          doc,
          ConflictChoice.takeTheirs,
          fs: fs,
          clock: clock,
        );
        expect(doc.pendingConflict, isNull);
        expect(doc.text, 'Theirs');
        expect(doc.saveState, SaveState.saved);

        // Check recovery copy
        final recoveryPath = VaultPath(
          '.tephra/cache/recovery/20261011093000-Note.md',
        );
        final stat = await fs.stat(recoveryPath);
        expect(stat, isNotNull);
        expect(
          fs.textOf('.tephra/cache/recovery/20261011093000-Note.md'),
          'Mine',
        );

        doc.dispose();
      },
    );

    testWidgets(
      'keepBoth -> Note (conflict 2026-10-11 09-30).md created with mine, doc text = theirs',
      (tester) async {
        final doc = await setupConflictDoc();

        await resolveConflict(
          doc,
          ConflictChoice.keepBoth,
          fs: fs,
          clock: clock,
        );
        expect(doc.pendingConflict, isNull);
        expect(doc.text, 'Theirs');

        final conflictPath = VaultPath('Note (conflict 2026-10-11 09-30).md');
        final stat = await fs.stat(conflictPath);
        expect(stat, isNotNull);
        expect(fs.textOf('Note (conflict 2026-10-11 09-30).md'), 'Mine');

        doc.dispose();
      },
    );

    testWidgets(
      'second conflict in the same minute -> Note (conflict 2026-10-11 09-30) 2.md',
      (tester) async {
        // First conflict
        final doc1 = await setupConflictDoc('Theirs 1');
        await resolveConflict(
          doc1,
          ConflictChoice.keepBoth,
          fs: fs,
          clock: clock,
        );
        doc1.dispose();

        // Second conflict within the same minute with different external content
        final doc2 = await setupConflictDoc('Theirs 2');
        await resolveConflict(
          doc2,
          ConflictChoice.keepBoth,
          fs: fs,
          clock: clock,
        );

        final conflictPath2 = VaultPath(
          'Note (conflict 2026-10-11 09-30) 2.md',
        );
        final stat2 = await fs.stat(conflictPath2);
        expect(stat2, isNotNull);
        expect(fs.textOf('Note (conflict 2026-10-11 09-30) 2.md'), 'Mine');

        doc2.dispose();
      },
    );

    testWidgets('after any choice autosave works again', (tester) async {
      final doc = await setupConflictDoc();
      await resolveConflict(
        doc,
        ConflictChoice.takeTheirs,
        fs: fs,
        clock: clock,
      );
      expect(doc.saveState, SaveState.saved);

      // Make a new edit and assert autosave triggers
      doc.setText('New text after conflict');
      expect(doc.isDirty, isTrue);

      await tester.pump(const Duration(milliseconds: 1000));
      expect(doc.saveState, SaveState.saved);
      expect(fs.textOf('Note.md'), 'New text after conflict');

      doc.dispose();
    });
  });
}
