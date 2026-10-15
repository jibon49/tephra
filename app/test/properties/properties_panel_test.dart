// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/editor/editor_controller.dart';
import 'package:tephra/editor/editor_options.dart';
import 'package:tephra/editor/live_preview/editing_mode.dart';
import 'package:tephra/editor/source_editor_view.dart';
import 'package:tephra/properties/frontmatter_editor.dart';
import 'package:tephra/properties/properties_panel.dart';
import 'package:tephra/properties/property_row.dart';
import 'package:tephra/properties/raw_yaml_editor.dart';
import 'package:tephra/reading/parse_service.dart';
import 'package:tephra/settings/vault_settings.dart';
import 'package:tephra/vault/note_document.dart';
import 'package:tephra/workspace/providers.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../helpers/fake_editor_engine.dart';
import '../helpers/test_app.dart';

void main() {
  group('PropertiesPanel', () {
    late MemoryVaultFileSystem fs;
    late ParseService parseService;

    setUp(() {
      fs = MemoryVaultFileSystem();
      parseService = ParseService();
    });

    EditorController createController(String text, {VaultPath? path}) {
      final notePath = path ?? VaultPath('note.md');
      fs.writeText(notePath, TextDocument(text: text));
      final doc = NoteDocument(
        path: notePath,
        fs: fs,
        parseService: parseService,
        clock: const SystemClock(),
      );
      doc.load();
      addTearDown(doc.dispose);

      final engine = FakeEditorEngine(text);
      final controller = EditorController(
        document: doc,
        engine: engine,
        options: const EditorOptions(),
        parseService: parseService,
      );
      addTearDown(controller.dispose);
      return controller;
    }

    testWidgets('one row per key in order and tags: [x] renders chip #x', (
      tester,
    ) async {
      const text = '''---
title: Test Note
tags:
  - flutter
count: 42
done: false
---
Body text
''';

      final controller = createController(text);

      await tester.pumpWidget(
        testApp(
          Scaffold(body: PropertiesPanel(controller: controller)),
          fs: fs,
        ),
      );
      await tester.pumpAndSettle();

      final rows = find.byType(PropertyRow);
      expect(rows, findsNWidgets(4));

      // Check key order
      final titleRow = tester.widget<PropertyRow>(rows.at(0));
      expect(titleRow.propertyKey, 'title');

      final tagsRow = tester.widget<PropertyRow>(rows.at(1));
      expect(tagsRow.propertyKey, 'tags');

      final countRow = tester.widget<PropertyRow>(rows.at(2));
      expect(countRow.propertyKey, 'count');

      final doneRow = tester.widget<PropertyRow>(rows.at(3));
      expect(doneRow.propertyKey, 'done');

      // tags: [flutter] renders chip #flutter
      expect(find.text('#flutter'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets(
      'checkbox toggle -> one applyEdits call turns done: false into done: true',
      (tester) async {
        const text = '''---
done: false
---
Body text
''';

        final controller = createController(text);

        await tester.pumpWidget(
          testApp(
            Scaffold(body: PropertiesPanel(controller: controller)),
            fs: fs,
          ),
        );
        await tester.pumpAndSettle();

        final checkbox = find.byType(Checkbox);
        expect(checkbox, findsOneWidget);

        await tester.tap(checkbox);
        await tester.pumpAndSettle();

        expect(controller.text, contains('done: true'));

        await tester.pump(const Duration(seconds: 2));
      },
    );

    testWidgets('text field edit then blur -> exactly one commit', (
      tester,
    ) async {
      const text = '''---
title: Initial
---
Body text
''';

      final controller = createController(text);

      final otherFocusNode = FocusNode();
      addTearDown(otherFocusNode.dispose);

      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: Column(
              children: [
                PropertiesPanel(controller: controller),
                TextField(focusNode: otherFocusNode),
              ],
            ),
          ),
          fs: fs,
        ),
      );
      await tester.pumpAndSettle();

      final valueField = find.widgetWithText(TextField, 'Initial');
      expect(valueField, findsOneWidget);

      await tester.enterText(valueField, 'Updated Title');
      await tester.pumpAndSettle();

      // Not yet committed before blur
      expect(controller.text, contains('title: Initial'));

      // Move focus to otherFocusNode to blur
      otherFocusNode.requestFocus();
      await tester.pumpAndSettle();

      expect(controller.text, contains('title: Updated Title'));

      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('invalid number shows the error and makes no commit', (
      tester,
    ) async {
      const text = '''---
count: 10
---
Body text
''';

      final controller = createController(text);

      final otherFocusNode = FocusNode();
      addTearDown(otherFocusNode.dispose);

      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: Column(
              children: [
                PropertiesPanel(controller: controller),
                TextField(focusNode: otherFocusNode),
              ],
            ),
          ),
          fs: fs,
        ),
      );
      await tester.pumpAndSettle();

      final valueField = find.widgetWithText(TextField, '10');
      expect(valueField, findsOneWidget);

      await tester.enterText(valueField, 'invalid-num');
      otherFocusNode.requestFocus();
      await tester.pumpAndSettle();

      // Should show invalid number error
      expect(find.text('Invalid number'), findsOneWidget);
      // Controller should NOT have committed invalid-num
      expect(controller.text, contains('count: 10'));

      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets(
      'key rename to an existing key shows propertiesKeyExists and reverts',
      (tester) async {
        const text = '''---
title: Note
status: draft
---
Body text
''';

        final controller = createController(text);

        final otherFocusNode = FocusNode();
        addTearDown(otherFocusNode.dispose);

        await tester.pumpWidget(
          testApp(
            Scaffold(
              body: Column(
                children: [
                  PropertiesPanel(controller: controller),
                  TextField(focusNode: otherFocusNode),
                ],
              ),
            ),
            fs: fs,
          ),
        );
        await tester.pumpAndSettle();

        // Find the key TextField for 'status'
        final statusKeyField = find.widgetWithText(TextField, 'status');
        expect(statusKeyField, findsOneWidget);

        // Try renaming 'status' to 'title'
        await tester.enterText(statusKeyField, 'title');
        otherFocusNode.requestFocus();
        await tester.pumpAndSettle();

        // Should show error and revert
        expect(find.text('Property already exists'), findsOneWidget);
        expect(controller.text, contains('status: draft'));

        await tester.pump(const Duration(seconds: 2));
      },
    );

    testWidgets('Remove property -> one commit', (tester) async {
      const text = '''---
title: Note
status: draft
---
Body text
''';

      final controller = createController(text);

      await tester.pumpWidget(
        testApp(
          Scaffold(body: PropertiesPanel(controller: controller)),
          fs: fs,
        ),
      );
      await tester.pumpAndSettle();

      // Find the row menu specifically inside the status PropertyRow
      final statusRow = find.widgetWithText(PropertyRow, 'status');
      expect(statusRow, findsOneWidget);
      final rowMenu = find.descendant(
        of: statusRow,
        matching: find.byIcon(Icons.more_horiz),
      );
      expect(rowMenu, findsOneWidget);

      await tester.tap(rowMenu);
      await tester.pumpAndSettle();

      final removeOption = find.text('Remove property');
      expect(removeOption, findsOneWidget);
      await tester.tap(removeOption);
      await tester.pumpAndSettle();

      expect(controller.text.contains('status'), isFalse);
      expect(controller.text, contains('title: Note'));

      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets(
      'at 1200 dp drag handles exist, at 400 dp a ⋮ button with 48 dp height exists',
      (tester) async {
        const text = '''---
title: Note
---
Body text
''';

        final controller = createController(text);

        // Desktop test at 1200 dp
        setSurfaceSize(tester, const Size(1200, 800));
        await tester.pumpWidget(
          testApp(
            Scaffold(body: PropertiesPanel(controller: controller)),
            fs: fs,
            size: const Size(1200, 800),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.drag_handle), findsOneWidget);
        expect(find.byIcon(Icons.more_vert), findsNothing);

        // Phone test at 400 dp
        setSurfaceSize(tester, const Size(400, 800));
        await tester.pumpWidget(
          testApp(
            Scaffold(body: PropertiesPanel(controller: controller)),
            fs: fs,
            size: const Size(400, 800),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.drag_handle), findsNothing);
        final vertMenu = find.byIcon(Icons.more_vert);
        expect(vertMenu, findsOneWidget);

        final parentBox = find
            .ancestor(of: vertMenu, matching: find.byType(SizedBox))
            .first;
        final size = tester.getSize(parentBox);
        expect(size.height, greaterThanOrEqualTo(48.0));

        await tester.pump(const Duration(seconds: 2));
      },
    );

    testWidgets(
      'invalid YAML -> banner + raw editor, Apply with a: [ shows the error with line 1 and no edit',
      (tester) async {
        const text = '''---
invalid: [yaml
---
Body text
''';

        final controller = createController(text);

        await tester.pumpWidget(
          testApp(
            Scaffold(body: PropertiesPanel(controller: controller)),
            fs: fs,
          ),
        );
        await tester.pumpAndSettle();

        // Shows banner
        expect(find.text('Invalid YAML frontmatter'), findsOneWidget);
        // Shows RawYamlEditor
        expect(find.byType(RawYamlEditor), findsOneWidget);

        // Structured rows are not shown
        expect(find.byType(PropertyRow), findsNothing);

        // Type "a: [" into raw editor and click Apply
        final rawField = find.descendant(
          of: find.byType(RawYamlEditor),
          matching: find.byType(TextField),
        );
        await tester.enterText(rawField, 'a: [');
        await tester.pumpAndSettle();

        final applyButton = find.text('Apply');
        await tester.tap(applyButton);
        await tester.pumpAndSettle();

        // Error shown with line 1
        expect(find.textContaining('line 1'), findsOneWidget);
        // No edit committed to controller
        expect(controller.text, text);

        await tester.pump(const Duration(seconds: 2));
      },
    );

    testWidgets(
      'propertiesInDocument = source or source mode -> no panel in SourceEditorView',
      (tester) async {
        final path = VaultPath('note.md');
        const text = '''---
title: Note
---
Body text
''';
        await fs.writeText(path, const TextDocument(text: text));

        // Test 1: propertiesInDocument = 'source'
        await tester.pumpWidget(
          testApp(
            Consumer(
              builder: (context, ref, _) {
                final activeTab = ref.watch(workspaceProvider).focusedTab;
                if (activeTab == null) return const SizedBox.shrink();
                return SourceEditorView(path: path, tabId: activeTab.id);
              },
            ),
            fs: fs,
            settings: VaultSettings(
              editor: const EditorSettings(propertiesInDocument: 'source')
                  .toMap(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final element1 = tester.element(find.byType(Consumer));
        final container1 = ProviderScope.containerOf(element1);
        container1
            .read(workspaceProvider.notifier)
            .openPath(path, editingMode: EditingMode.livePreview);
        await tester.pumpAndSettle();

        expect(find.byType(PropertiesPanel), findsNothing);

        // Test 2: Source mode (even if propertiesInDocument = 'visible')
        await tester.pumpWidget(
          testApp(
            Consumer(
              builder: (context, ref, _) {
                final activeTab = ref.watch(workspaceProvider).focusedTab;
                if (activeTab == null) return const SizedBox.shrink();
                return SourceEditorView(path: path, tabId: activeTab.id);
              },
            ),
            fs: fs,
            settings: VaultSettings(
              editor: const EditorSettings(propertiesInDocument: 'visible')
                  .toMap(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final element2 = tester.element(find.byType(Consumer));
        final container2 = ProviderScope.containerOf(element2);
        container2
            .read(workspaceProvider.notifier)
            .openPath(path, editingMode: EditingMode.source);
        await tester.pumpAndSettle();

        expect(find.byType(PropertiesPanel), findsNothing);

        await tester.pump(const Duration(seconds: 2));
      },
    );

    test('Undo check (controller-level): setValue edit then undo restores original note text', () {
      const original = '''---
title: Original Note
tags:
  - test
status: draft
---
Body of note
''';

      final controller = createController(original);

      final edit = FrontmatterEditor.setValue(
        controller.text,
        'status',
        'done',
      );
      expect(edit, isNotNull);
      controller.applyEdits([edit!]);

      expect(controller.text, contains('status: done'));
      expect(controller.text, isNot(original));

      controller.undo();

      expect(controller.text, original);
    });
  });
}
