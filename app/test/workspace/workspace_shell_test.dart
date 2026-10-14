// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/workspace/providers.dart';
import 'package:tephra/workspace/workspace_shell.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('1200 dp wide shows desktop layout with tab bar and status bar', (
    tester,
  ) async {
    final fs = MemoryVaultFileSystem();
    await fs.writeText(VaultPath('A.md'), const TextDocument(text: ''));

    await tester.pumpWidget(
      testApp(const WorkspaceShell(), fs: fs, size: const Size(1200, 800)),
    );
    await tester.pumpAndSettle();

    final element = tester.element(find.byType(WorkspaceShell));
    final container = ProviderScope.containerOf(element);
    container.read(workspaceProvider.notifier).openPath(VaultPath('A.md'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('desktop.tabbar')), findsOneWidget);
    expect(find.byKey(const Key('desktop.statusbar')), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
  });

  testWidgets('400 dp wide shows phone layout with AppBar and no tab bar', (
    tester,
  ) async {
    final fs = MemoryVaultFileSystem();
    await fs.writeText(VaultPath('A.md'), const TextDocument(text: ''));

    await tester.pumpWidget(
      testApp(const WorkspaceShell(), fs: fs, size: const Size(400, 800)),
    );
    await tester.pumpAndSettle();

    final element = tester.element(find.byType(WorkspaceShell));
    final container = ProviderScope.containerOf(element);
    container.read(workspaceProvider.notifier).openPath(VaultPath('A.md'));
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byKey(const Key('desktop.tabbar')), findsNothing);
  });

  testWidgets('adaptive breakpoint switches at 840 dp', (tester) async {
    final fs = MemoryVaultFileSystem();
    await fs.writeText(VaultPath('A.md'), const TextDocument(text: ''));

    // 839 dp -> phone
    await tester.pumpWidget(
      testApp(const WorkspaceShell(), fs: fs, size: const Size(839, 800)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byKey(const Key('desktop.tabbar')), findsNothing);

    // 840 dp -> desktop
    await tester.pumpWidget(
      testApp(const WorkspaceShell(), fs: fs, size: const Size(840, 800)),
    );
    await tester.pumpAndSettle();

    final element = tester.element(find.byType(WorkspaceShell));
    final container = ProviderScope.containerOf(element);
    container.read(workspaceProvider.notifier).openPath(VaultPath('A.md'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('desktop.tabbar')), findsOneWidget);
    expect(find.byKey(const Key('desktop.statusbar')), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
  });

  testWidgets(
    'Android back button navigates history [A, B] -> A and allows pop at root',
    (tester) async {
      final fs = MemoryVaultFileSystem();
      await fs.writeText(VaultPath('A.md'), const TextDocument(text: ''));
      await fs.writeText(VaultPath('B.md'), const TextDocument(text: ''));

      await tester.pumpWidget(
        testApp(const WorkspaceShell(), fs: fs, size: const Size(400, 800)),
      );
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(WorkspaceShell));
      final container = ProviderScope.containerOf(element);

      // Open A then B in the same tab
      container.read(workspaceProvider.notifier).openPath(VaultPath('A.md'));
      container.read(workspaceProvider.notifier).openPath(VaultPath('B.md'));
      await tester.pumpAndSettle();

      expect(container.read(activeNotePathProvider), equals(VaultPath('B.md')));

      // System back navigates tab history to A
      final handledFirst = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(handledFirst, isTrue);
      expect(container.read(activeNotePathProvider), equals(VaultPath('A.md')));

      // At A (historyIndex == 0), history cannot go back further so pop is not handled by tab history
      final handledSecond = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(handledSecond, isFalse);
    },
  );
}
