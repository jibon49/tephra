// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/editor/conflict_dialog.dart';
import 'package:tephra/vault/note_document.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../helpers/test_app.dart';

void main() {
  group('ConflictDialog', () {
    late ManualClock clock;
    late MemoryVaultFileSystem fs;
    late VaultPath path;

    setUp(() async {
      clock = ManualClock(DateTime(2026, 10, 11, 9, 30, 0));
      fs = MemoryVaultFileSystem(clock: clock);
      path = VaultPath('Note.md');
      await fs.writeText(path, const TextDocument(text: 'Base'));
    });

    Future<NoteDocument> setupConflictDoc() async {
      final doc = NoteDocument(path: path, fs: fs, clock: clock);
      await doc.load();
      doc.setText('Mine');
      fs.putText('Note.md', 'Theirs');
      await doc.onExternalChange();
      expect(doc.pendingConflict, isNotNull);
      return doc;
    }

    testWidgets('renders three buttons and is not dismissible on barrier tap', (
      tester,
    ) async {
      final doc = await setupConflictDoc();

      await tester.pumpWidget(
        testApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showConflictDialog(context, doc),
              child: const Text('Open'),
            ),
          ),
          fs: fs,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byKey(const Key('conflict.mine')), findsOneWidget);
      expect(find.byKey(const Key('conflict.theirs')), findsOneWidget);
      expect(find.byKey(const Key('conflict.both')), findsOneWidget);

      // Tap barrier outside dialog (top-left)
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // Dialog is still visible (not dismissible)
      expect(find.byType(AlertDialog), findsOneWidget);

      doc.dispose();
    });

    testWidgets('tapping Keep mine resolves with keepMine', (tester) async {
      final doc = await setupConflictDoc();

      await tester.pumpWidget(
        testApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showConflictDialog(context, doc),
              child: const Text('Open'),
            ),
          ),
          fs: fs,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('conflict.mine')));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(doc.pendingConflict, isNull);
      expect(doc.text, 'Mine');
      expect(fs.textOf('Note.md'), 'Mine');

      doc.dispose();
    });

    testWidgets('tapping Take theirs resolves with takeTheirs', (tester) async {
      final doc = await setupConflictDoc();

      await tester.pumpWidget(
        testApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showConflictDialog(context, doc),
              child: const Text('Open'),
            ),
          ),
          fs: fs,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('conflict.theirs')));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(doc.pendingConflict, isNull);
      expect(doc.text, 'Theirs');

      doc.dispose();
    });

    testWidgets('tapping Keep both resolves with keepBoth', (tester) async {
      final doc = await setupConflictDoc();

      await tester.pumpWidget(
        testApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showConflictDialog(context, doc),
              child: const Text('Open'),
            ),
          ),
          fs: fs,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('conflict.both')));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(doc.pendingConflict, isNull);
      expect(doc.text, 'Theirs');
      expect(fs.textOf('Note (conflict 2026-10-11 09-30).md'), 'Mine');

      doc.dispose();
    });
  });
}
