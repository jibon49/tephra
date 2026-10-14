// © 2026 Tephra. All rights reserved.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/workspace/providers.dart';
import 'package:tephra/workspace/tab_bar_view.dart';
import 'package:tephra/workspace/workspace_shell.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('tab chips show stems and back/forward buttons enable/disable', (
    tester,
  ) async {
    final fs = MemoryVaultFileSystem();
    await fs.writeText(VaultPath('MyNote.md'), const TextDocument(text: ''));
    await fs.writeText(VaultPath('OtherNote.md'), const TextDocument(text: ''));

    await tester.pumpWidget(
      testApp(const WorkspaceShell(), fs: fs, size: const Size(1200, 800)),
    );
    await tester.pumpAndSettle();

    final element = tester.element(find.byType(WorkspaceShell));
    final container = ProviderScope.containerOf(element);

    container.read(workspaceProvider.notifier).openPath(VaultPath('MyNote.md'));
    await tester.pumpAndSettle();

    // Stem shown
    expect(
      find.descendant(
        of: find.byType(WorkspaceTabBarView),
        matching: find.text('MyNote'),
      ),
      findsOneWidget,
    );

    // With 1 item, back and forward are disabled
    final backBtn = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.arrow_back),
    );
    final forwardBtn = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.arrow_forward),
    );
    expect(backBtn.onPressed, isNull);
    expect(forwardBtn.onPressed, isNull);

    // Open another note in the same tab -> Back enabled
    container
        .read(workspaceProvider.notifier)
        .openPath(VaultPath('OtherNote.md'));
    await tester.pumpAndSettle();

    final backBtnAfter = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.arrow_back),
    );
    expect(backBtnAfter.onPressed, isNotNull);

    // Tap back
    await tester.tap(find.widgetWithIcon(IconButton, Icons.arrow_back));
    await tester.pumpAndSettle();

    // Forward enabled, back disabled
    final backBtnBack = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.arrow_back),
    );
    final forwardBtnBack = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.arrow_forward),
    );
    expect(backBtnBack.onPressed, isNull);
    expect(forwardBtnBack.onPressed, isNotNull);
  });

  testWidgets('middle-click closes the tab', (tester) async {
    final fs = MemoryVaultFileSystem();
    await fs.writeText(VaultPath('NoteA.md'), const TextDocument(text: ''));
    await fs.writeText(VaultPath('NoteB.md'), const TextDocument(text: ''));

    await tester.pumpWidget(
      testApp(const WorkspaceShell(), fs: fs, size: const Size(1200, 800)),
    );
    await tester.pumpAndSettle();

    final element = tester.element(find.byType(WorkspaceShell));
    final container = ProviderScope.containerOf(element);

    container.read(workspaceProvider.notifier).openPath(VaultPath('NoteA.md'));
    container
        .read(workspaceProvider.notifier)
        .openPath(VaultPath('NoteB.md'), newTab: true);
    await tester.pumpAndSettle();

    final noteATab = find.descendant(
      of: find.byType(WorkspaceTabBarView),
      matching: find.text('NoteA'),
    );
    final noteBTab = find.descendant(
      of: find.byType(WorkspaceTabBarView),
      matching: find.text('NoteB'),
    );

    expect(noteATab, findsOneWidget);
    expect(noteBTab, findsOneWidget);

    // Middle-click NoteB tab chip
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(
      pointer.down(tester.getCenter(noteBTab), buttons: kMiddleMouseButton),
    );
    await tester.sendEventToBinding(pointer.up());
    await tester.pumpAndSettle();

    expect(noteBTab, findsNothing);
    expect(noteATab, findsOneWidget);
  });

  testWidgets('dirty dot appears when tabDirtyProvider is overridden to true', (
    tester,
  ) async {
    final fs = MemoryVaultFileSystem();
    await fs.writeText(VaultPath('DirtyNote.md'), const TextDocument(text: ''));

    await tester.pumpWidget(
      testApp(
        const WorkspaceShell(),
        fs: fs,
        size: const Size(1200, 800),
        overrides: [
          tabDirtyProvider(VaultPath('DirtyNote.md')).overrideWithValue(true),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final element = tester.element(find.byType(WorkspaceShell));
    final container = ProviderScope.containerOf(element);

    container
        .read(workspaceProvider.notifier)
        .openPath(VaultPath('DirtyNote.md'));
    await tester.pumpAndSettle();

    // Verify tab chip and dirty dot container
    expect(
      find.descendant(
        of: find.byType(WorkspaceTabBarView),
        matching: find.text('DirtyNote'),
      ),
      findsOneWidget,
    );
    // Finds the 6x6 dirty dot BoxDecoration with circle shape
    final containers = tester.widgetList<Container>(find.byType(Container));
    final hasDirtyDot = containers.any((c) {
      final decoration = c.decoration;
      if (decoration is BoxDecoration) {
        return decoration.shape == BoxShape.circle;
      }
      return false;
    });
    expect(hasDirtyDot, isTrue);
  });
}
