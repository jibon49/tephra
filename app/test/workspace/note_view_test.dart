// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/editor/edit_operation.dart';
import 'package:tephra/editor/providers.dart';
import 'package:tephra/editor/source_editor_view.dart';
import 'package:tephra/reading/reading_view.dart';
import 'package:tephra/vault/providers.dart';
import 'package:tephra/workspace/note_view.dart';
import 'package:tephra/workspace/providers.dart';
import 'package:tephra/workspace/workspace_models.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../helpers/test_app.dart';

void main() {
  group('NoteView', () {
    late MemoryVaultFileSystem fs;
    late VaultPath path;

    setUp(() async {
      fs = MemoryVaultFileSystem();
      path = VaultPath('note.md');
      await fs.writeText(
        path,
        const TextDocument(
          text: '# Heading 1\nLine 1\nLine 2\nLine 3\n# Heading 2\nLine 4\nLine 5',
        ),
      );
    });

    testWidgets(
      'toggling mode keeps position, doc instance and preserves unsaved edits',
      (tester) async {
        final tabId = 'tab-1';
        await tester.pumpWidget(
          testApp(
            NoteView(path: path, tabId: tabId),
            fs: fs,
          ),
        );
        await tester.pumpAndSettle();

        final element = tester.element(find.byType(NoteView));
        final container = ProviderScope.containerOf(element);

        // Open tab in workspace state so findTab returns the tab
        container.read(workspaceProvider.notifier).openPath(path);
        await tester.pumpAndSettle();

        final activeTab = container.read(workspaceProvider).focusedTab;
        expect(activeTab, isNotNull);
        final currentTabId = activeTab!.id;

        // Pump NoteView with the real tab id
        await tester.pumpWidget(
          testApp(
            NoteView(path: path, tabId: currentTabId),
            fs: fs,
          ),
        );
        await tester.pumpAndSettle();

        // Initially in default mode (reading)
        expect(find.byType(ReadingView), findsOneWidget);
        expect(find.byType(SourceEditorView), findsNothing);

        final docInstance1 = container.read(noteDocumentProvider(path));

        // 1. Toggle to Source mode
        container
            .read(workspaceProvider.notifier)
            .setMode(currentTabId, ViewMode.source);
        await tester.pumpAndSettle();

        expect(find.byType(SourceEditorView), findsOneWidget);
        expect(find.byType(ReadingView), findsNothing);

        // Verify same NoteDocument instance
        final docInstance2 = container.read(noteDocumentProvider(path));
        expect(identical(docInstance1, docInstance2), isTrue);

        // 2. Perform an unsaved edit in Source mode and move caret
        final controller = container
            .read(editorRegistryProvider)
            .controllerFor(path);
        expect(controller, isNotNull);

        // Apply edit: insert '# Extra\n' at start
        controller!.apply(const EditOperation(0, 0, '# Extra\n'));
        controller.select(20);
        await tester.pumpAndSettle();

        expect(docInstance1.isDirty, isTrue);

        // 3. Toggle back to Reading mode
        container
            .read(workspaceProvider.notifier)
            .setMode(currentTabId, ViewMode.reading);
        await tester.pumpAndSettle();

        // ReadingView is back, receives unsaved text and initial offset
        expect(find.byType(ReadingView), findsOneWidget);
        final readingView = tester.widget<ReadingView>(
          find.byType(ReadingView),
        );
        expect(readingView.text, startsWith('# Extra\n'));
        expect(readingView.initialOffset, equals(20));
        expect(docInstance1.isDirty, isTrue);

        // Toggle back to Source mode
        container
            .read(workspaceProvider.notifier)
            .setMode(currentTabId, ViewMode.source);
        await tester.pumpAndSettle();

        expect(find.byType(SourceEditorView), findsOneWidget);
        final controller2 = container
            .read(editorRegistryProvider)
            .controllerFor(path);
        expect(controller2, isNotNull);
        expect(controller2!.text, startsWith('# Extra\n'));
        expect(docInstance1.isDirty, isTrue);
      },
    );

    testWidgets('missing file shows missing state with close button', (
      tester,
    ) async {
      final missingPath = VaultPath('non_existent.md');
      final tabId = 'tab-missing';

      await tester.pumpWidget(
        testApp(
          NoteView(path: missingPath, tabId: tabId),
          fs: fs,
        ),
      );
      await tester.pumpAndSettle();

      // Shows missing message and close tab button
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byType(SourceEditorView), findsNothing);
      expect(find.byType(ReadingView), findsNothing);
    });
  });
}
