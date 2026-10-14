// © 2026 Tephra. All rights reserved.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/editor/engine/re_editor_engine.dart';
import 'package:tephra/editor/providers.dart';
import 'package:tephra/workspace/providers.dart';
import 'package:tephra/workspace/workspace_models.dart';
import 'package:tephra/workspace/workspace_shell.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../helpers/test_app.dart';

void main() {
  group('Editor shortcuts and IME safety', () {
    test('IME safety: composing TextEditingValue is never intercepted', () {
      expect(
        ReEditorEngine.shouldInterceptEdit(
          const TextEditingValue(
            text: 'nihongo',
            composing: TextRange(start: 0, end: 7),
          ),
        ),
        isFalse,
      );
      expect(
        ReEditorEngine.shouldInterceptEdit(
          const TextEditingValue(text: 'a', composing: TextRange.empty),
        ),
        isTrue,
      );
      expect(
        ReEditorEngine.shouldInterceptEdit(
          const TextEditingValue(
            text: 'a',
            composing: TextRange(start: -1, end: -1),
          ),
        ),
        isTrue,
      );
    });

    testWidgets('shell at 1200 dp: shortcuts and editing with real engine', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        final fs = MemoryVaultFileSystem();
        final path = VaultPath('note.md');
        await fs.writeText(
          path,
          const TextDocument(text: 'first line\nsecond word here\nthird line'),
        );

        setSurfaceSize(tester, const Size(1200, 800));
        await tester.pumpWidget(
          testApp(const WorkspaceShell(), fs: fs, size: const Size(1200, 800)),
        );
        await tester.pumpAndSettle();

        final element = tester.element(find.byType(WorkspaceShell));
        final container = ProviderScope.containerOf(element);

        // Open the note in a tab and switch to Source mode
        container.read(workspaceProvider.notifier).openPath(path);
        await tester.pumpAndSettle();

        final activeTab = container.read(workspaceProvider).focusedTab;
        expect(activeTab, isNotNull);
        container
            .read(workspaceProvider.notifier)
            .setMode(activeTab!.id, ViewMode.source);
        await tester.pumpAndSettle();

        final controller = container
            .read(editorRegistryProvider)
            .controllerFor(path);
        expect(controller, isNotNull);
        final c = controller!;

        // Focus the editor
        c.focus();
        await tester.pumpAndSettle();

        // 1. Ctrl+B with word selected wraps in **
        c.select(18, 22);
        await tester.pumpAndSettle();
        expect(
          c.text.substring(c.selection.baseOffset, c.selection.extentOffset),
          'word',
        );

        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();

        expect(c.text, contains('**word**'));

        // 2. Ctrl+Z undoes
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();

        expect(c.text, contains('second word here'));
        expect(c.text, isNot(contains('**word**')));

        // 3. Ctrl+Shift+D duplicates the line
        c.select(18, 18);
        await tester.pumpAndSettle();

        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();

        expect(
          c.text,
          'first line\nsecond word here\nsecond word here\nthird line',
        );

        // 4. Alt+Up moves line 1 above line 0
        c.select(11, 11);
        await tester.pumpAndSettle();

        await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
        await tester.pumpAndSettle();

        expect(
          c.text,
          'second word here\nfirst line\nsecond word here\nthird line',
        );

        // 5. Ctrl+Enter toggles task
        c.replaceAll('- [ ] task item', keepCursor: false);
        c.select(0, 0);
        await tester.pumpAndSettle();

        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();

        expect(c.text, '- [x] task item');

        // 6. Enter in - a continues the list
        c.replaceAll('- a', keepCursor: false);
        c.select(3, 3);
        await tester.pumpAndSettle();

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        expect(c.text, '- a\n- ');

        // 7. Tab indents
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();

        expect(c.text, contains('- a\n'));
        expect(c.text.endsWith('- '), isTrue);
        expect(c.text.substring(4, c.text.length - 2), anyOf('\t', '    '));

        // 8. Typing ( inserts ()
        c.replaceAll('', keepCursor: false);
        c.select(0, 0);
        await tester.pumpAndSettle();

        final engine = c.engine as ReEditorEngine;
        engine.typeText('(');
        await tester.pumpAndSettle();

        expect(c.text, '()');
        expect(c.selection.baseOffset, 1);
        expect(c.selection.extentOffset, 1);

        // 9. Typing 200 characters produces exactly expected text
        c.replaceAll('', keepCursor: false);
        c.select(0, 0);
        await tester.pumpAndSettle();

        const typedSample =
            "I'm testing snake_case and **bold** formatting with (a) sample.\n"
            'This sentence ensures that typing multiple paragraphs and symbols works.\n'
            'Here is more text to easily reach over 200 total characters in length!';

        engine.typeText(typedSample);
        await tester.pumpAndSettle();

        expect(c.text, typedSample);
        expect(c.text.length, greaterThanOrEqualTo(200));

        // Clear debounce timer before test finish
        await tester.pump(const Duration(milliseconds: 300));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
