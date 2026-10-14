// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/commands/hotkey_host.dart';
import 'package:tephra/editor/find/find_bar.dart';
import 'package:tephra/editor/providers.dart';
import 'package:tephra/editor/source_editor_view.dart';
import 'package:tephra/workspace/providers.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../helpers/test_app.dart';

void main() {
  group('FindBar with real engine', () {
    late MemoryVaultFileSystem fs;
    late VaultPath path;

    setUp(() async {
      fs = MemoryVaultFileSystem();
      path = VaultPath('note.md');
      await fs.writeText(
        path,
        const TextDocument(
          text: 'hello world\nhello again\nsomething else entirely',
        ),
      );
    });

    Widget buildTestWidget() {
      return testApp(
        HotkeyHost(
          child: SourceEditorView(path: path, tabId: 'tab-1'),
        ),
        fs: fs,
        overrides: [activeNotePathProvider.overrideWithValue(path)],
      );
    }

    testWidgets('Ctrl+F opens the bar and query typing shows 1 of N', (
      tester,
    ) async {
      setSurfaceSize(tester, const Size(1200, 800));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(FindBar), findsNothing);

      // Press Ctrl+F
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(find.byType(FindBar), findsOneWidget);
      expect(find.byKey(const Key('find.query')), findsOneWidget);

      // Type query "hello"
      await tester.enterText(find.byKey(const Key('find.query')), 'hello');
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      expect(find.text('1 of 2'), findsOneWidget);
    });

    testWidgets('Enter advances and wraps; Shift+Enter goes back', (
      tester,
    ) async {
      setSurfaceSize(tester, const Size(1200, 800));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(SourceEditorView));
      final container = ProviderScope.containerOf(element);
      final controller = container
          .read(editorRegistryProvider)
          .controllerFor(path)!;

      controller.findController.open();
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('find.query')), 'hello');
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      expect(find.text('1 of 2'), findsOneWidget);

      // Advance
      await tester.tap(find.byKey(const Key('find.next')));
      await tester.pumpAndSettle();
      expect(find.text('2 of 2'), findsOneWidget);

      // Advance wraps to 1
      await tester.tap(find.byKey(const Key('find.next')));
      await tester.pumpAndSettle();
      expect(find.text('1 of 2'), findsOneWidget);

      // Previous wraps to 2
      await tester.tap(find.byKey(const Key('find.prev')));
      await tester.pumpAndSettle();
      expect(find.text('2 of 2'), findsOneWidget);

      // Keyboard: Enter advances
      await tester.showKeyboard(find.byKey(const Key('find.query')));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('1 of 2'), findsOneWidget);

      // Keyboard: Shift+Enter goes back
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(find.text('2 of 2'), findsOneWidget);
    });

    testWidgets('toggles change match count', (tester) async {
      await fs.writeText(
        path,
        const TextDocument(text: 'Hello world\nhello world\nhellos'),
      );

      setSurfaceSize(tester, const Size(1200, 800));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(SourceEditorView));
      final container = ProviderScope.containerOf(element);
      final controller = container
          .read(editorRegistryProvider)
          .controllerFor(path)!;

      controller.findController.open();
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('find.query')), 'Hello');
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      // Case-insensitive: "Hello" matches "Hello" and "hello" and prefix of "hellos" -> 3 matches
      expect(find.text('1 of 3'), findsOneWidget);

      // Toggle matchCase
      await tester.tap(find.byKey(const Key('find.matchCase')));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      expect(find.text('1 of 1'), findsOneWidget);

      // Toggle matchCase off
      await tester.tap(find.byKey(const Key('find.matchCase')));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      expect(find.text('1 of 3'), findsOneWidget);

      // Toggle wholeWord: "hello" as whole word matches 2 (not "hellos")
      await tester.tap(find.byKey(const Key('find.wholeWord')));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      expect(find.text('1 of 2'), findsOneWidget);
    });

    testWidgets(
      'Replace all changes document and one Ctrl+Z restores it entirely',
      (tester) async {
        setSurfaceSize(tester, const Size(1200, 800));
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        final element = tester.element(find.byType(SourceEditorView));
        final container = ProviderScope.containerOf(element);
        final controller = container
            .read(editorRegistryProvider)
            .controllerFor(path)!;

        // Open with replace row
        controller.findController.open(replace: true);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('find.replace')), findsOneWidget);

        await tester.enterText(find.byKey(const Key('find.query')), 'hello');
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pumpAndSettle();
        expect(find.text('1 of 2'), findsOneWidget);

        await tester.enterText(
          find.byKey(const Key('find.replace')),
          'greetings',
        );
        await tester.pumpAndSettle();

        // Tap Replace All
        await tester.tap(find.byKey(const Key('find.replaceAll')));
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pumpAndSettle();

        expect(
          controller.text,
          'greetings world\ngreetings again\nsomething else entirely',
        );

        // One Ctrl+Z undoes the entire replace all
        controller.undo();
        await tester.pumpAndSettle();

        expect(
          controller.text,
          'hello world\nhello again\nsomething else entirely',
        );
      },
    );

    testWidgets('Esc closes bar and clears highlights', (tester) async {
      setSurfaceSize(tester, const Size(1200, 800));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(SourceEditorView));
      final container = ProviderScope.containerOf(element);
      final controller = container
          .read(editorRegistryProvider)
          .controllerFor(path)!;

      controller.findController.open();
      await tester.pumpAndSettle();
      expect(find.byType(FindBar), findsOneWidget);

      await tester.enterText(find.byKey(const Key('find.query')), 'world');
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      // Check overlays present
      expect(controller.highlighter.overlays, isNotEmpty);

      // Press Esc on FindBar
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(FindBar), findsNothing);
      expect(controller.highlighter.overlays, isEmpty);
    });

    testWidgets('Ctrl+H shows replace row', (tester) async {
      setSurfaceSize(tester, const Size(1200, 800));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(FindBar), findsNothing);

      // Press Ctrl+H
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(find.byType(FindBar), findsOneWidget);
      expect(find.byKey(const Key('find.replace')), findsOneWidget);
    });

    testWidgets('invalid regex shows error text', (tester) async {
      setSurfaceSize(tester, const Size(1200, 800));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(SourceEditorView));
      final container = ProviderScope.containerOf(element);
      final controller = container
          .read(editorRegistryProvider)
          .controllerFor(path)!;

      controller.findController.open();
      await tester.pumpAndSettle();

      // Toggle regex on
      await tester.tap(find.byKey(const Key('find.regex')));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      // Type invalid regex "("
      await tester.enterText(find.byKey(const Key('find.query')), '(');
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      expect(find.text('Invalid regular expression'), findsOneWidget);
    });

    testWidgets('selection prefills the query field', (tester) async {
      setSurfaceSize(tester, const Size(1200, 800));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(SourceEditorView));
      final container = ProviderScope.containerOf(element);
      final controller = container
          .read(editorRegistryProvider)
          .controllerFor(path)!;

      // Select "world" (offset 6 to 11)
      controller.select(6, 11);
      await tester.pumpAndSettle();

      // Press Ctrl+F
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(find.byType(FindBar), findsOneWidget);
      expect(controller.findController.state.options.query, 'world');
      final queryField = tester.widget<TextField>(
        find.byKey(const Key('find.query')),
      );
      expect(queryField.controller?.text, 'world');
    });
  });
}
