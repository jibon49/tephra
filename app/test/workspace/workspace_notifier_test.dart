// © 2026 Tephra. All rights reserved.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/settings/app_settings.dart';
import 'package:tephra/settings/providers.dart';
import 'package:tephra/settings/vault_settings.dart';
import 'package:tephra/vault/providers.dart';
import 'package:tephra/vault/vault_session.dart';
import 'package:tephra/workspace/providers.dart';
import 'package:tephra/workspace/tab_content.dart';
import 'package:tephra/workspace/workspace_models.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

void main() {
  late ProviderContainer container;
  late MemoryVaultFileSystem fs;

  setUp(() {
    fs = MemoryVaultFileSystem();
    container = ProviderContainer(
      overrides: [
        initialAppSettingsProvider.overrideWithValue(
          const AppSettings(deviceId: 'test-device'),
        ),
      ],
    );
    container
        .read(vaultSessionProvider.notifier)
        .set(
          VaultSession(
            vaultId: 'test-vault',
            rootDir: '/test',
            name: 'Test Vault',
            fs: fs,
            settings: const VaultSettings(),
          ),
        );
  });

  tearDown(() {
    container.dispose();
  });

  test('open A in empty workspace -> 1 pane 1 tab', () {
    final notifier = container.read(workspaceProvider.notifier);
    notifier.openPath(VaultPath('A.md'));

    final state = container.read(workspaceProvider);
    expect(state.panes.length, equals(1));
    expect(state.panes[0].tabs.length, equals(1));
    expect(state.panes[0].activeIndex, equals(0));
    expect(
      state.panes[0].activeTab?.content,
      equals(FileTabContent(VaultPath('A.md'))),
    );
    expect(container.read(activeNotePathProvider), equals(VaultPath('A.md')));
  });

  test('open B (no newTab) -> same tab, history [A,B], index 1', () {
    final notifier = container.read(workspaceProvider.notifier);
    notifier.openPath(VaultPath('A.md'));
    notifier.openPath(VaultPath('B.md'));

    final state = container.read(workspaceProvider);
    expect(state.panes[0].tabs.length, equals(1));
    final tab = state.panes[0].activeTab!;
    expect(tab.history.length, equals(2));
    expect(tab.historyIndex, equals(1));
    expect(tab.content, equals(FileTabContent(VaultPath('B.md'))));
    expect(tab.canGoBack, isTrue);
    expect(tab.canGoForward, isFalse);
  });

  test('goBack -> A, canGoForward', () {
    final notifier = container.read(workspaceProvider.notifier);
    notifier.openPath(VaultPath('A.md'));
    notifier.openPath(VaultPath('B.md'));
    notifier.goBack();

    final tab = container.read(workspaceProvider).panes[0].activeTab!;
    expect(tab.historyIndex, equals(0));
    expect(tab.content, equals(FileTabContent(VaultPath('A.md'))));
    expect(tab.canGoBack, isFalse);
    expect(tab.canGoForward, isTrue);
  });

  test('open C after goBack -> history [A,C] (forward truncated)', () {
    final notifier = container.read(workspaceProvider.notifier);
    notifier.openPath(VaultPath('A.md'));
    notifier.openPath(VaultPath('B.md'));
    notifier.goBack();
    notifier.openPath(VaultPath('C.md'));

    final tab = container.read(workspaceProvider).panes[0].activeTab!;
    expect(tab.history.length, equals(2));
    expect(tab.history[0], equals(FileTabContent(VaultPath('A.md'))));
    expect(tab.history[1], equals(FileTabContent(VaultPath('C.md'))));
    expect(tab.historyIndex, equals(1));
  });

  test('open A while tab shows C and another tab already shows A -> that tab is activated', () {
    final notifier = container.read(workspaceProvider.notifier);
    notifier.openPath(VaultPath('A.md'));
    notifier.openPath(VaultPath('C.md'), newTab: true);
    expect(container.read(workspaceProvider).panes[0].activeIndex, equals(1));

    // Open A without newTab -> should activate tab 0
    notifier.openPath(VaultPath('A.md'));
    expect(container.read(workspaceProvider).panes[0].activeIndex, equals(0));
    expect(
      container.read(workspaceProvider).panes[0].activeTab?.content,
      equals(FileTabContent(VaultPath('A.md'))),
    );
  });

  test('newTab creates a second tab and activates it', () {
    final notifier = container.read(workspaceProvider.notifier);
    notifier.openPath(VaultPath('A.md'));
    notifier.openPath(VaultPath('B.md'), newTab: true);

    final state = container.read(workspaceProvider);
    expect(state.panes[0].tabs.length, equals(2));
    expect(state.panes[0].activeIndex, equals(1));
    expect(
      state.panes[0].activeTab?.content,
      equals(FileTabContent(VaultPath('B.md'))),
    );
  });

  test('background keeps the old active tab', () {
    final notifier = container.read(workspaceProvider.notifier);
    notifier.openPath(VaultPath('A.md'));
    notifier.openPath(VaultPath('B.md'), newTab: true, background: true);

    final state = container.read(workspaceProvider);
    expect(state.panes[0].tabs.length, equals(2));
    expect(state.panes[0].activeIndex, equals(0));
    expect(
      state.panes[0].activeTab?.content,
      equals(FileTabContent(VaultPath('A.md'))),
    );
  });

  test('closeTab picks the right neighbour then the left', () {
    final notifier = container.read(workspaceProvider.notifier);
    notifier.openPath(VaultPath('A.md'));
    notifier.openPath(VaultPath('B.md'), newTab: true);
    notifier.openPath(VaultPath('C.md'), newTab: true);

    final pane = container.read(workspaceProvider).panes[0];
    final tabAId = pane.tabs[0].id;
    final tabBId = pane.tabs[1].id;
    final tabCId = pane.tabs[2].id;

    // Activate middle tab B
    notifier.activateTab(pane.id, tabBId);
    expect(container.read(workspaceProvider).panes[0].activeIndex, equals(1));

    // Closing B picks right neighbour C (now at index 1)
    notifier.closeTab(pane.id, tabBId);
    expect(container.read(workspaceProvider).panes[0].activeIndex, equals(1));
    expect(
      container.read(workspaceProvider).panes[0].activeTab?.id,
      equals(tabCId),
    );

    // Closing C (at index 1, rightmost) picks left neighbour A (at index 0)
    notifier.closeTab(pane.id, tabCId);
    expect(container.read(workspaceProvider).panes[0].activeIndex, equals(0));
    expect(
      container.read(workspaceProvider).panes[0].activeTab?.id,
      equals(tabAId),
    );
  });

  test('closing the last tab of the only pane leaves an empty pane', () {
    final notifier = container.read(workspaceProvider.notifier);
    notifier.openPath(VaultPath('A.md'));
    final pane = container.read(workspaceProvider).panes[0];

    notifier.closeTab(pane.id, pane.tabs[0].id);
    final state = container.read(workspaceProvider);
    expect(state.panes.length, equals(1));
    expect(state.panes[0].tabs, isEmpty);
  });

  test('split -> 2 panes with copied tab and closePane merges tabs', () {
    final notifier = container.read(workspaceProvider.notifier);
    notifier.openPath(VaultPath('A.md'));
    notifier.openPath(VaultPath('B.md'), newTab: true);

    notifier.splitFocused(SplitAxis.horizontal);
    var state = container.read(workspaceProvider);
    expect(state.panes.length, equals(2));
    expect(state.focusedPane, equals(1));
    expect(
      state.panes[1].activeTab?.content,
      equals(FileTabContent(VaultPath('B.md'))),
    );
    expect(
      state.panes[1].activeTab?.id,
      isNot(equals(state.panes[0].activeTab?.id)),
    );

    // closePane merges tabs into the other pane
    notifier.closePane(state.panes[1].id);
    state = container.read(workspaceProvider);
    expect(state.panes.length, equals(1));
    expect(state.panes[0].tabs.length, equals(3));
  });

  test('moveTab(0, 2) reorders', () {
    final notifier = container.read(workspaceProvider.notifier);
    notifier.openPath(VaultPath('A.md'));
    notifier.openPath(VaultPath('B.md'), newTab: true);
    notifier.openPath(VaultPath('C.md'), newTab: true);

    final pane = container.read(workspaceProvider).panes[0];
    notifier.moveTab(pane.id, 0, 2);

    final updatedTabs = container.read(workspaceProvider).panes[0].tabs;
    expect(updatedTabs[0].content, equals(FileTabContent(VaultPath('B.md'))));
    expect(updatedTabs[1].content, equals(FileTabContent(VaultPath('C.md'))));
    expect(updatedTabs[2].content, equals(FileTabContent(VaultPath('A.md'))));
  });

  test('nextTab / previousTab wrap around', () {
    final notifier = container.read(workspaceProvider.notifier);
    notifier.openPath(VaultPath('A.md'));
    notifier.openPath(VaultPath('B.md'), newTab: true);
    notifier.openPath(VaultPath('C.md'), newTab: true);

    // currently at index 2 (C)
    notifier.nextTab();
    expect(container.read(workspaceProvider).panes[0].activeIndex, equals(0));

    notifier.previousTab();
    expect(container.read(workspaceProvider).panes[0].activeIndex, equals(2));
  });

  test('retargetPath updates exact and prefix matches in history', () {
    final notifier = container.read(workspaceProvider.notifier);
    notifier.openPath(VaultPath('a.md'));
    notifier.openPath(VaultPath('Folder/x.md'), newTab: true);

    notifier.retargetPath(VaultPath('a.md'), VaultPath('b.md'));
    notifier.retargetPath(VaultPath('Folder'), VaultPath('New'));

    final tabs = container.read(workspaceProvider).panes[0].tabs;
    expect(tabs[0].content, equals(FileTabContent(VaultPath('b.md'))));
    expect(tabs[1].content, equals(FileTabContent(VaultPath('New/x.md'))));
  });

  test('removePath removes entries and closes empty tabs', () {
    final notifier = container.read(workspaceProvider.notifier);
    notifier.openPath(VaultPath('Keep.md'));
    notifier.openPath(VaultPath('Folder/sub.md'), newTab: true);

    notifier.removePath(VaultPath('Folder'));

    final state = container.read(workspaceProvider);
    expect(state.panes[0].tabs.length, equals(1));
    expect(
      state.panes[0].tabs[0].content,
      equals(FileTabContent(VaultPath('Keep.md'))),
    );
  });

  test('history is capped at 100 entries', () {
    final notifier = container.read(workspaceProvider.notifier);
    for (var i = 0; i < 120; i++) {
      notifier.openPath(VaultPath('note-$i.md'));
    }

    final tab = container.read(workspaceProvider).panes[0].activeTab!;
    expect(tab.history.length, equals(100));
    expect(tab.history.first, equals(FileTabContent(VaultPath('note-20.md'))));
    expect(tab.history.last, equals(FileTabContent(VaultPath('note-119.md'))));
  });

  test('setSplitRatio clamps to 0.2 - 0.8', () {
    final notifier = container.read(workspaceProvider.notifier);
    notifier.setSplitRatio(0.05);
    expect(container.read(workspaceProvider).splitRatio, equals(0.2));

    notifier.setSplitRatio(0.95);
    expect(container.read(workspaceProvider).splitRatio, equals(0.8));
  });

  test('default mode is taken from vault settings', () {
    const customSettings = VaultSettings(defaultViewMode: 'source');
    final customSession = VaultSession(
      vaultId: 's',
      rootDir: '/r',
      name: 'N',
      fs: fs,
      settings: customSettings,
    );
    container.read(vaultSessionProvider.notifier).set(customSession);

    final notifier = container.read(workspaceProvider.notifier);
    notifier.openPath(VaultPath('SourceNote.md'), newTab: true);

    final tab = container.read(workspaceProvider).panes[0].activeTab!;
    expect(tab.mode, equals(ViewMode.source));
  });

  test('recentFilesProvider ordering and cap 30', () {
    final notifier = container.read(workspaceProvider.notifier);
    for (var i = 0; i < 35; i++) {
      notifier.openPath(VaultPath('file-$i.md'));
    }

    final recents = container.read(recentFilesProvider);
    expect(recents.length, equals(30));
    expect(recents.first, equals(VaultPath('file-34.md')));
    expect(recents.last, equals(VaultPath('file-5.md')));
  });

  test('activeNotePathProvider follows focused tab', () {
    final notifier = container.read(workspaceProvider.notifier);
    notifier.openPath(VaultPath('A.md'));
    expect(container.read(activeNotePathProvider), equals(VaultPath('A.md')));

    notifier.openPath(VaultPath('B.md'), newTab: true);
    expect(container.read(activeNotePathProvider), equals(VaultPath('B.md')));
  });
}
