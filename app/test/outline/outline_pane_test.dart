// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/editor/editor_controller.dart';
import 'package:tephra/editor/editor_options.dart';
import 'package:tephra/editor/providers.dart';
import 'package:tephra/outline/outline_pane.dart';
import 'package:tephra/reading/parse_service.dart';
import 'package:tephra/vault/note_document.dart';
import 'package:tephra/workspace/providers.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../helpers/fake_editor_engine.dart';
import '../helpers/test_app.dart';

void main() {
  group('OutlinePane', () {
    late MemoryVaultFileSystem fs;
    final notePath = VaultPath('note.md');
    const noteText = '# L1\nContent 1\n## L2\nContent 2\n### L3\nContent 3\n';

    setUp(() async {
      fs = MemoryVaultFileSystem();
      await fs.writeText(notePath, const TextDocument(text: noteText));
    });

    testWidgets('tree renders 3 levels', (tester) async {
      await tester.pumpWidget(
        testApp(
          const Scaffold(body: OutlinePane()),
          fs: fs,
          size: const Size(1200, 800),
          overrides: [activeNotePathProvider.overrideWithValue(notePath)],
        ),
      );

      // Wait for debounce parse in activeParsedNoteProvider
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('L1'), findsOneWidget);
      expect(find.text('L2'), findsOneWidget);
      expect(find.text('L3'), findsOneWidget);
    });

    testWidgets('tapping a row calls select on controller with heading start', (
      tester,
    ) async {
      late WidgetRef capturedRef;
      await tester.pumpWidget(
        testApp(
          Consumer(
            builder: (context, ref, _) {
              capturedRef = ref;
              return const Scaffold(body: OutlinePane());
            },
          ),
          fs: fs,
          size: const Size(1200, 800),
          overrides: [activeNotePathProvider.overrideWithValue(notePath)],
        ),
      );

      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // Create and attach controller
      final doc = NoteDocument(
        path: notePath,
        fs: fs,
        parseService: const ParseService(),
        clock: const SystemClock(),
      );
      await doc.load();

      final engine = FakeEditorEngine(noteText);
      final controller = EditorController(
        document: doc,
        engine: engine,
        options: const EditorOptions(),
        parseService: const ParseService(),
        registry: capturedRef.read(editorRegistryProvider),
      );
      addTearDown(controller.dispose);

      await tester.pumpAndSettle();

      // L2 starts at offset 15 in '# L1\nContent 1\n## L2\nContent 2\n### L3\nContent 3\n'
      final l2Start = noteText.indexOf('## L2');
      expect(l2Start, isPositive);

      await tester.tap(find.text('L2'));
      await tester.pumpAndSettle();

      expect(controller.selection.baseOffset, equals(l2Start));
    });

    testWidgets('at 1200 dp rows are draggable, at 400 dp they are not', (
      tester,
    ) async {
      // 1. Desktop width 1200 dp -> Draggable present
      await tester.pumpWidget(
        testApp(
          const Scaffold(body: OutlinePane()),
          fs: fs,
          size: const Size(1200, 800),
          overrides: [activeNotePathProvider.overrideWithValue(notePath)],
        ),
      );

      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.byType(Draggable<int>), findsNWidgets(3));

      // 2. Mobile width 400 dp -> No Draggable
      await tester.pumpWidget(
        testApp(
          const Scaffold(body: OutlinePane()),
          fs: fs,
          size: const Size(400, 800),
          overrides: [activeNotePathProvider.overrideWithValue(notePath)],
        ),
      );

      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.byType(Draggable<int>), findsNothing);
    });

    testWidgets('collapsing parent heading hides children', (tester) async {
      await tester.pumpWidget(
        testApp(
          const Scaffold(body: OutlinePane()),
          fs: fs,
          size: const Size(1200, 800),
          overrides: [activeNotePathProvider.overrideWithValue(notePath)],
        ),
      );

      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('L1'), findsOneWidget);
      expect(find.text('L2'), findsOneWidget);
      expect(find.text('L3'), findsOneWidget);

      // Tap the expand/collapse chevron on L1
      final chevronFinder = find.byIcon(Icons.expand_more).first;
      await tester.tap(chevronFinder);
      await tester.pumpAndSettle();

      // L1 is still visible, but children L2 and L3 are collapsed/hidden
      expect(find.text('L1'), findsOneWidget);
      expect(find.text('L2'), findsNothing);
      expect(find.text('L3'), findsNothing);

      // Tap again to uncollapse
      final collapsedChevronFinder = find.byIcon(Icons.chevron_right).first;
      await tester.tap(collapsedChevronFinder);
      await tester.pumpAndSettle();

      expect(find.text('L1'), findsOneWidget);
      expect(find.text('L2'), findsOneWidget);
      expect(find.text('L3'), findsOneWidget);
    });

    testWidgets(
      'dragging heading section on desktop applies edits and Ctrl+Z restores',
      (tester) async {
        late WidgetRef capturedRef;
        await tester.pumpWidget(
          testApp(
            Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                return const Scaffold(body: OutlinePane());
              },
            ),
            fs: fs,
            size: const Size(1200, 800),
            overrides: [activeNotePathProvider.overrideWithValue(notePath)],
          ),
        );

        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();

        final doc = NoteDocument(
          path: notePath,
          fs: fs,
          parseService: const ParseService(),
          clock: const SystemClock(),
        );
        await doc.load();

        final engine = FakeEditorEngine(noteText);
        final controller = EditorController(
          document: doc,
          engine: engine,
          options: const EditorOptions(),
          parseService: const ParseService(),
          registry: capturedRef.read(editorRegistryProvider),
        );
        addTearDown(controller.dispose);

        await tester.pumpAndSettle();

        final l2Finder = find.text('L2');
        expect(l2Finder, findsOneWidget);

        final dropTargets = find.byType(DragTarget<int>);
        expect(dropTargets, findsWidgets);

        final firstDropTarget = dropTargets.first;
        final gesture = await tester.startGesture(tester.getCenter(l2Finder));
        await tester.pump(const Duration(milliseconds: 100));
        await gesture.moveBy(const Offset(0, -20));
        await tester.pump(const Duration(milliseconds: 100));

        await gesture.moveTo(tester.getCenter(firstDropTarget));
        await tester.pump(const Duration(milliseconds: 100));

        await gesture.up();
        await tester.pumpAndSettle();

        // Check text after moving L2 and its children above L1
        expect(
          controller.text.startsWith('## L2\nContent 2\n### L3\n'),
          isTrue,
        );

        // Verify undo restores original text in one step
        controller.undo();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
        expect(controller.text, equals(noteText));
      },
    );
  });
}
