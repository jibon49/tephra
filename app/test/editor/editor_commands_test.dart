// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/commands/command_registry.dart';
import 'package:tephra/commands/hotkey_conflicts.dart';
import 'package:tephra/commands/providers.dart';
import 'package:tephra/commands/shortcut_codec.dart';
import 'package:tephra/editor/edit_operation.dart';
import 'package:tephra/editor/editor_commands.dart';
import 'package:tephra/editor/editor_controller.dart';
import 'package:tephra/editor/editor_options.dart';
import 'package:tephra/editor/editor_registry.dart';
import 'package:tephra/editor/providers.dart';
import 'package:tephra/reading/parse_service.dart';
import 'package:tephra/vault/note_document_store.dart';
import 'package:tephra/workspace/providers.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../helpers/fake_editor_engine.dart';
import '../helpers/test_app.dart';

void main() {
  group('editor_commands', () {
    const expectedShortcuts = <String, List<String>>{
      'editor.toggle-bold': ['Ctrl+B'],
      'editor.toggle-italic': ['Ctrl+I'],
      'editor.toggle-strikethrough': [],
      'editor.toggle-highlight': [],
      'editor.toggle-code': [],
      'editor.insert-link': ['Ctrl+K'],
      'editor.toggle-bullet-list': [],
      'editor.toggle-numbered-list': [],
      'editor.toggle-task': ['Ctrl+Enter'],
      'editor.toggle-quote': [],
      'editor.cycle-heading': [],
      'editor.indent-list': [],
      'editor.outdent-list': [],
      'editor.undo': ['Ctrl+Z'],
      'editor.redo': ['Ctrl+Y', 'Ctrl+Shift+Z'],
      'editor.find': ['Ctrl+F'],
      'editor.replace': ['Ctrl+H'],
      'editor.move-line-up': ['Alt+Up'],
      'editor.move-line-down': ['Alt+Down'],
      'editor.duplicate-line': ['Ctrl+Shift+D'],
    };

    test('all 20 editor.* commands exist with exact default shortcuts', () {
      final registry = CommandRegistry();
      registerEditorCommands(registry);

      for (final entry in expectedShortcuts.entries) {
        final cmd = registry.byId(entry.key);
        expect(
          cmd,
          isNotNull,
          reason: 'Command ${entry.key} must be registered',
        );
        final actualShortcuts = cmd!.defaultShortcuts
            .map(formatShortcut)
            .toList();
        expect(
          actualShortcuts,
          equals(entry.value),
          reason: 'Shortcuts mismatch for command ${entry.key}',
        );
      }
    });

    test('no shortcut conflicts among all registered commands in registry', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final registry = container.read(commandRegistryProvider);
      final conflicts = findHotkeyConflicts(registry, {});
      expect(conflicts, isEmpty, reason: 'Found hotkey conflicts: $conflicts');
    });

    testWidgets(
      'all editor commands are unavailable without an active editor',
      (tester) async {
        late WidgetRef capturedRef;
        await tester.pumpWidget(
          testApp(
            Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        final registry = CommandRegistry();
        registerEditorCommands(registry);

        for (final cmdId in expectedShortcuts.keys) {
          final cmd = registry.byId(cmdId)!;
          final available = cmd.isAvailable?.call(capturedRef) ?? true;
          expect(
            available,
            isFalse,
            reason:
                'Command $cmdId should be unavailable without active editor',
          );
        }
      },
    );

    testWidgets(
      'each editor command executes and modifies text with FakeEditorEngine',
      (tester) async {
        final fs = MemoryVaultFileSystem();
        final store = NoteDocumentStore(fs, const SystemClock());
        final editorRegistry = EditorRegistry();
        final path = VaultPath('test.md');
        await fs.writeText(path, const TextDocument(text: 'Initial text'));
        final doc = store.acquire(path);
        await doc.load();

        final fakeEngine = FakeEditorEngine(doc.text);
        final controller = EditorController(
          document: doc,
          engine: fakeEngine,
          options: const EditorOptions(useTab: false, tabSize: 2),
          parseService: const ParseService(),
          registry: editorRegistry,
        );
        addTearDown(() {
          controller.dispose();
          store.release(path);
        });

        late WidgetRef capturedRef;
        late BuildContext capturedContext;

        await tester.pumpWidget(
          testApp(
            Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                capturedContext = context;
                return const SizedBox.shrink();
              },
            ),
            fs: fs,
            overrides: [
              editorRegistryProvider.overrideWithValue(editorRegistry),
              activeNotePathProvider.overrideWithValue(path),
            ],
          ),
        );
        await tester.pumpAndSettle();

        final registry = capturedRef.read(commandRegistryProvider);

        void runCmd(String id) {
          final cmd = registry.byId(id)!;
          expect(cmd.isAvailable?.call(capturedRef), isTrue);
          cmd.run(capturedRef, capturedContext);
        }

        // 1. bold: "word" selected -> "**word**"
        fakeEngine.setText('word', clearHistory: true);
        controller.select(0, 4);
        runCmd('editor.toggle-bold');
        expect(controller.text, '**word**');

        // 2. italic: "word" selected -> "*word*"
        fakeEngine.setText('word', clearHistory: true);
        controller.select(0, 4);
        runCmd('editor.toggle-italic');
        expect(controller.text, '*word*');

        // 3. strikethrough: "word" selected -> "~~word~~"
        fakeEngine.setText('word', clearHistory: true);
        controller.select(0, 4);
        runCmd('editor.toggle-strikethrough');
        expect(controller.text, '~~word~~');

        // 4. highlight: "word" selected -> "==word=="
        fakeEngine.setText('word', clearHistory: true);
        controller.select(0, 4);
        runCmd('editor.toggle-highlight');
        expect(controller.text, '==word==');

        // 5. code: "word" selected -> "`word`"
        fakeEngine.setText('word', clearHistory: true);
        controller.select(0, 4);
        runCmd('editor.toggle-code');
        expect(controller.text, '`word`');

        // 6. link: "word" selected -> "[word]()"
        fakeEngine.setText('word', clearHistory: true);
        controller.select(0, 4);
        runCmd('editor.insert-link');
        expect(controller.text, '[word]()');

        // 7. bullet list: "a" at col 1 -> "- a"
        fakeEngine.setText('a', clearHistory: true);
        controller.select(1);
        runCmd('editor.toggle-bullet-list');
        expect(controller.text, '- a');

        // 8. numbered list: "a" at col 1 -> "1. a"
        fakeEngine.setText('a', clearHistory: true);
        controller.select(1);
        runCmd('editor.toggle-numbered-list');
        expect(controller.text, '1. a');

        // 9. task: "a" at col 1 -> "- [ ] a"
        fakeEngine.setText('a', clearHistory: true);
        controller.select(1);
        runCmd('editor.toggle-task');
        expect(controller.text, '- [ ] a');

        // 10. quote: "a" at col 1 -> "> a"
        fakeEngine.setText('a', clearHistory: true);
        controller.select(1);
        runCmd('editor.toggle-quote');
        expect(controller.text, '> a');

        // 11. cycle heading: "a" at col 1 -> "# a"
        fakeEngine.setText('a', clearHistory: true);
        controller.select(1);
        runCmd('editor.cycle-heading');
        expect(controller.text, '# a');

        // 12. indent list: "- a" -> "  - a"
        fakeEngine.setText('- a', clearHistory: true);
        controller.select(3);
        runCmd('editor.indent-list');
        expect(controller.text, '  - a');

        // 13. outdent list: "  - a" -> "- a"
        fakeEngine.setText('  - a', clearHistory: true);
        controller.select(5);
        runCmd('editor.outdent-list');
        expect(controller.text, '- a');

        // 14. move line up: "a\nb" line 1 -> "b\na"
        fakeEngine.setText('a\nb', clearHistory: true);
        controller.select(3);
        runCmd('editor.move-line-up');
        expect(controller.text, 'b\na');

        // 15. move line down: "a\nb" line 0 -> "b\na"
        fakeEngine.setText('a\nb', clearHistory: true);
        controller.select(1);
        runCmd('editor.move-line-down');
        expect(controller.text, 'b\na');

        // 16. duplicate line: "a" -> "a\na"
        fakeEngine.setText('a', clearHistory: true);
        controller.select(1);
        runCmd('editor.duplicate-line');
        expect(controller.text, 'a\na');

        // 17. find & replace: open FindController
        expect(controller.findController.state.isOpen, isFalse);
        runCmd('editor.find');
        expect(controller.findController.state.isOpen, isTrue);
        expect(controller.findController.state.showReplace, isFalse);

        runCmd('editor.replace');
        expect(controller.findController.state.showReplace, isTrue);

        // 18. undo & redo
        fakeEngine.setText('hello', clearHistory: true);
        controller.apply(const EditOperation(5, 5, ' world'));
        expect(controller.text, 'hello world');
        expect(controller.canUndo, isTrue);

        runCmd('editor.undo');
        expect(controller.text, 'hello');
        expect(controller.canRedo, isTrue);

        runCmd('editor.redo');
        expect(controller.text, 'hello world');

        await tester.pump(const Duration(milliseconds: 300));
      },
    );
  });
}
