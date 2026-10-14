// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/editor/edit_operation.dart';
import 'package:tephra/editor/editor_options.dart';
import 'package:tephra/editor/providers.dart';
import 'package:tephra/editor/source_editor_view.dart';
import 'package:tephra/vault/providers.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../helpers/test_app.dart';

class _TestJumpNotifier extends PendingJumpNotifier {
  _TestJumpNotifier(this._initial);
  final PendingJump _initial;

  @override
  PendingJump? build() => _initial;
}

void main() {
  group('SourceEditorView', () {
    late MemoryVaultFileSystem fs;
    late VaultPath path;

    setUp(() async {
      fs = MemoryVaultFileSystem();
      path = VaultPath('note.md');
      await fs.writeText(
        path,
        const TextDocument(text: '# Heading 1\nSome initial body text'),
      );
    });

    testWidgets('loads text into editor on 1200 dp and 400 dp layouts', (
      tester,
    ) async {
      // 1200 dp
      setSurfaceSize(tester, const Size(1200, 800));
      await tester.pumpWidget(
        testApp(
          SourceEditorView(path: path, tabId: 'tab-1'),
          fs: fs,
          size: const Size(1200, 800),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SourceEditorView), findsOneWidget);
      final element = tester.element(find.byType(SourceEditorView));
      final container = ProviderScope.containerOf(element);
      final controller1200 = container
          .read(editorRegistryProvider)
          .controllerFor(path);
      expect(controller1200, isNotNull);
      expect(controller1200!.text, contains('# Heading 1'));

      // 400 dp
      setSurfaceSize(tester, const Size(400, 800));
      await tester.pumpWidget(
        testApp(
          SourceEditorView(path: path, tabId: 'tab-1'),
          fs: fs,
          size: const Size(400, 800),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SourceEditorView), findsOneWidget);
      final controller400 = container
          .read(editorRegistryProvider)
          .controllerFor(path);
      expect(controller400, isNotNull);
      expect(controller400!.text, contains('# Heading 1'));
    });

    testWidgets('typing a character marks document dirty', (tester) async {
      setSurfaceSize(tester, const Size(1200, 800));
      await tester.pumpWidget(
        testApp(
          SourceEditorView(path: path, tabId: 'tab-1'),
          fs: fs,
        ),
      );
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(SourceEditorView));
      final container = ProviderScope.containerOf(element);
      final doc = container.read(noteDocumentProvider(path));
      expect(doc.isDirty, isFalse);

      final controller = container
          .read(editorRegistryProvider)
          .controllerFor(path);
      expect(controller, isNotNull);

      controller!.apply(const EditOperation(0, 0, 'X'));
      await tester.pumpAndSettle();

      expect(doc.isDirty, isTrue);
    });

    testWidgets(
      'second view of same document shows note.openElsewhere and switches after first is disposed',
      (tester) async {
        setSurfaceSize(tester, const Size(1200, 800));

        var showFirst = true;
        await tester.pumpWidget(
          testApp(
            StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    if (showFirst)
                      Expanded(
                        child: SourceEditorView(path: path, tabId: 'tab-1'),
                      ),
                    Expanded(
                      child: SourceEditorView(path: path, tabId: 'tab-2'),
                    ),
                  ],
                );
              },
            ),
            fs: fs,
          ),
        );
        await tester.pumpAndSettle();

        // Second view must show banner note.openElsewhere
        expect(
          find.byKey(const ValueKey('note.openElsewhere')),
          findsOneWidget,
        );

        // Dispose first view
        showFirst = false;
        await tester.pumpWidget(
          testApp(
            StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    if (showFirst)
                      Expanded(
                        child: SourceEditorView(path: path, tabId: 'tab-1'),
                      ),
                    Expanded(
                      child: SourceEditorView(path: path, tabId: 'tab-2'),
                    ),
                  ],
                );
              },
            ),
            fs: fs,
          ),
        );
        await tester.pumpAndSettle();

        // Banner should disappear and second view attaches as editor
        expect(find.byKey(const ValueKey('note.openElsewhere')), findsNothing);
        final element = tester.element(find.byType(SourceEditorView));
        final container = ProviderScope.containerOf(element);
        final controller = container
            .read(editorRegistryProvider)
            .controllerFor(path);
        expect(controller, isNotNull);
        expect(controller!.text, contains('# Heading 1'));
      },
    );

    testWidgets('read-only document displays malformed banner', (tester) async {
      final readOnlyPath = VaultPath('corrupt.md');
      await fs.writeBytes(readOnlyPath, [0xC3, 0x28]);

      await tester.pumpWidget(
        testApp(
          SourceEditorView(path: readOnlyPath, tabId: 'tab-ro'),
          fs: fs,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('note.malformedBanner')),
        findsOneWidget,
      );
    });

    testWidgets('pendingJump heading moves caret to the heading offset', (
      tester,
    ) async {
      await fs.writeText(
        path,
        const TextDocument(
          text: '# Intro\nBody\n\n# Target Heading\nMore body',
        ),
      );

      await tester.pumpWidget(
        testApp(
          SourceEditorView(path: path, tabId: 'tab-jump'),
          fs: fs,
          overrides: [
            pendingJumpProvider.overrideWith(
              () => _TestJumpNotifier(
                PendingJump(path: path, heading: 'Target Heading'),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(SourceEditorView));
      final widgetContainer = ProviderScope.containerOf(element);
      final controller = widgetContainer
          .read(editorRegistryProvider)
          .controllerFor(path);
      expect(controller, isNotNull);
      // '# Target Heading' begins at offset 14 in the text
      expect(controller!.selection.baseOffset, equals(14));
    });

    testWidgets('options change does not rebuild document text', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          SourceEditorView(path: path, tabId: 'tab-opts'),
          fs: fs,
        ),
      );
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(SourceEditorView));
      final container = ProviderScope.containerOf(element);
      final controller = container
          .read(editorRegistryProvider)
          .controllerFor(path);
      expect(controller, isNotNull);

      final originalText = controller!.text;

      // Update options
      controller.updateOptions(const EditorOptions(tabSize: 2));
      await tester.pumpAndSettle();

      expect(controller.text, equals(originalText));
    });
  });
}
