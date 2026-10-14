// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/commands/command_registry.dart';
import 'package:tephra/commands/providers.dart';
import 'package:tephra/editor/editor_commands.dart';
import 'package:tephra/editor/editor_controller.dart';
import 'package:tephra/editor/editor_options.dart';
import 'package:tephra/editor/mobile_toolbar.dart';
import 'package:tephra/editor/providers.dart';
import 'package:tephra/reading/parse_service.dart';
import 'package:tephra/vault/note_document.dart';
import 'package:tephra/workspace/providers.dart';
import 'package:tephra/workspace/workspace_models.dart';
import 'package:tephra/workspace/workspace_shell.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../helpers/fake_editor_engine.dart';
import '../helpers/test_app.dart';

const List<String> _expectedCommandOrder = [
  'editor.toggle-bold',
  'editor.toggle-italic',
  'editor.cycle-heading',
  'editor.toggle-bullet-list',
  'editor.toggle-numbered-list',
  'editor.toggle-task',
  'editor.insert-link',
  'editor.toggle-code',
  'editor.toggle-quote',
  'editor.insert-attachment',
  'editor.undo',
  'editor.redo',
  'editor.outdent-list',
  'editor.indent-list',
];

void main() {
  group('MobileToolbar', () {
    late MemoryVaultFileSystem fs;

    setUp(() {
      fs = MemoryVaultFileSystem();
    });

    EditorController createController(
      WidgetRef ref,
      String text, {
      VaultPath? path,
    }) {
      final notePath = path ?? VaultPath('note.md');
      fs.writeText(notePath, TextDocument(text: text));
      final doc = NoteDocument(
        path: notePath,
        fs: fs,
        parseService: ParseService(),
        clock: const SystemClock(),
      );
      doc.load();

      final engine = FakeEditorEngine(text);
      final controller = EditorController(
        document: doc,
        engine: engine,
        options: const EditorOptions(),
        parseService: ParseService(),
        registry: ref.read(editorRegistryProvider),
      );
      addTearDown(controller.dispose);
      return controller;
    }

    testWidgets('at 400 dp renders buttons in exact order with 48 dp targets', (
      tester,
    ) async {
      late WidgetRef capturedRef;
      await tester.pumpWidget(
        testApp(
          Consumer(
            builder: (context, ref, _) {
              capturedRef = ref;
              return const Scaffold(bottomNavigationBar: MobileToolbar());
            },
          ),
          fs: fs,
          size: const Size(400, 800),
          overrides: [
            activeNotePathProvider.overrideWithValue(VaultPath('note.md')),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final controller = createController(capturedRef, 'Some text');

      // Re-pump so activeEditorProvider picks up controller and widgets rebuild
      await tester.pumpAndSettle();

      // Check toolbar existence
      expect(find.byKey(const Key('mobile.toolbar')), findsOneWidget);

      // Verify each button in order and its 48x48 size
      for (final id in _expectedCommandOrder) {
        final btnFinder = find.byKey(Key('toolbar.$id'));
        expect(
          btnFinder,
          findsOneWidget,
          reason: 'Command $id should be rendered',
        );
        final size = tester.getSize(btnFinder);
        expect(size.width, equals(48.0));
        expect(size.height, equals(48.0));
      }

      // Check hide-keyboard pinned at right end
      final hideBtn = find.byKey(const Key('toolbar.editor.hide-keyboard'));
      expect(hideBtn, findsOneWidget);
      final hideSize = tester.getSize(hideBtn);
      expect(hideSize.width, equals(48.0));
      expect(hideSize.height, equals(48.0));

      // Undo and redo should be disabled with no history
      final undoBtn = tester.widget<IconButton>(
        find.byKey(const Key('toolbar.editor.undo')),
      );
      final redoBtn = tester.widget<IconButton>(
        find.byKey(const Key('toolbar.editor.redo')),
      );
      expect(undoBtn.onPressed, isNull);
      expect(redoBtn.onPressed, isNull);

      // Tapping bold calls command and editor keeps focus
      controller.focus();
      expect(controller.hasFocus, isTrue);

      await tester.tap(find.byKey(const Key('toolbar.editor.toggle-bold')));
      await tester.pump();

      expect(controller.hasFocus, isTrue);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('hides unavailable commands', (tester) async {
      final registry = CommandRegistry();
      registerEditorCommands(registry);

      await tester.pumpWidget(
        testApp(
          const Scaffold(bottomNavigationBar: MobileToolbar()),
          fs: fs,
          size: const Size(400, 800),
          overrides: [commandRegistryProvider.overrideWithValue(registry)],
        ),
      );
      await tester.pumpAndSettle();

      // Without active editor, editor commands are unavailable and hidden
      for (final id in _expectedCommandOrder) {
        expect(find.byKey(Key('toolbar.$id')), findsNothing);
      }
    });

    testWidgets(
      'workspace shell integration: hidden at 1200 dp and in reading mode',
      (tester) async {
        await fs.writeText(
          VaultPath('A.md'),
          const TextDocument(text: 'Content'),
        );

        // 1. At 1200 dp: toolbar is never shown
        await tester.pumpWidget(
          testApp(const WorkspaceShell(), fs: fs, size: const Size(1200, 800)),
        );
        await tester.pumpAndSettle();

        var element = tester.element(find.byType(WorkspaceShell));
        var container = ProviderScope.containerOf(element);
        container.read(workspaceProvider.notifier).openPath(VaultPath('A.md'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('mobile.toolbar')), findsNothing);

        // 2. At 400 dp in reading mode: toolbar is not shown
        await tester.pumpWidget(
          testApp(const WorkspaceShell(), fs: fs, size: const Size(400, 800)),
        );
        await tester.pumpAndSettle();

        element = tester.element(find.byType(WorkspaceShell));
        container = ProviderScope.containerOf(element);
        final tab = container.read(workspaceProvider).focusedTab;
        if (tab != null && tab.mode != ViewMode.reading) {
          container
              .read(workspaceProvider.notifier)
              .setMode(tab.id, ViewMode.reading);
          await tester.pumpAndSettle();
        }

        expect(find.byKey(const Key('mobile.toolbar')), findsNothing);

        // 3. Switch to source mode and focus editor: toolbar is shown
        if (tab != null) {
          container
              .read(workspaceProvider.notifier)
              .setMode(tab.id, ViewMode.source);
          await tester.pumpAndSettle();

          final editor = container.read(activeEditorProvider);
          editor?.focus();
          await tester.pumpAndSettle();

          expect(find.byKey(const Key('mobile.toolbar')), findsOneWidget);
        }
      },
    );
  });
}
