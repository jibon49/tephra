// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';

import '../settings/providers.dart';
import '../vault/providers.dart';
import 'providers.dart';
import 'tab_content.dart';
import 'workspace_models.dart';
import 'workspace_persistence.dart';

final class WorkspaceNotifier extends Notifier<WorkspaceState> {
  WorkspaceNotifier({WorkspacePersistence? persistence})
    : _persistence = persistence ?? WorkspacePersistence();

  final WorkspacePersistence _persistence;
  Timer? _saveTimer;
  int _tabCounter = 1;
  int _paneCounter = 1;

  String _nextTabId() => 'tab-${_tabCounter++}';
  String _nextPaneId() => 'pane-${_paneCounter++}';

  @override
  WorkspaceState build() {
    ref.onDispose(() {
      _saveTimer?.cancel();
    });
    return const WorkspaceState();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), _flushSave);
  }

  Future<void> flushSave() => _flushSave();

  Future<void> _flushSave() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    final session = ref.read(vaultSessionProvider);
    if (session == null) return;
    final deviceId = ref.read(appSettingsProvider).deviceId;
    final recent = ref.read(recentFilesProvider);
    await _persistence.save(
      fs: session.fs,
      deviceId: deviceId,
      state: state,
      recentFiles: recent,
    );
  }

  void openPath(
    VaultPath path, {
    bool newTab = false,
    bool background = false,
    String? subpath,
  }) => openContent(
    FileTabContent(path, subpath: subpath),
    newTab: newTab,
    background: background,
  );

  void openContent(
    TabContent content, {
    bool newTab = false,
    bool background = false,
  }) {
    final panes = List<PaneState>.of(state.panes);
    if (panes.isEmpty) {
      panes.add(PaneState(id: _nextPaneId(), tabs: const [], activeIndex: 0));
    }
    final focusedIndex = state.focusedPane.clamp(0, panes.length - 1);
    var pane = panes[focusedIndex];

    if (!newTab) {
      // (a) If a tab in pane has content == this content -> activate it
      final existingIdx = pane.tabs.indexWhere((t) => t.content == content);
      if (existingIdx != -1) {
        pane = pane.copyWith(activeIndex: existingIdx);
        panes[focusedIndex] = pane;
        state = state.copyWith(panes: panes, focusedPane: focusedIndex);
        _scheduleSave();
        if (content is FileTabContent) {
          ref.read(recentFilesProvider.notifier).add(content.path);
        }
        return;
      }

      // (b) Else if pane has an active tab -> navigate
      if (pane.activeTab != null) {
        final activeTab = pane.activeTab!;
        if (activeTab.content == content) {
          return;
        }
        var newHistory = activeTab.history
            .sublist(0, activeTab.historyIndex + 1)
            .toList();
        newHistory.add(content);
        var newIndex = newHistory.length - 1;
        if (newHistory.length > 100) {
          newHistory = newHistory.sublist(newHistory.length - 100);
          newIndex = newHistory.length - 1;
        }
        final updatedTab = activeTab.copyWith(
          history: newHistory,
          historyIndex: newIndex,
        );
        final newTabs = List<TabState>.of(pane.tabs);
        newTabs[pane.activeIndex] = updatedTab;
        pane = pane.copyWith(tabs: newTabs);
        panes[focusedIndex] = pane;
        state = state.copyWith(panes: panes, focusedPane: focusedIndex);
        _scheduleSave();
        if (content is FileTabContent) {
          ref.read(recentFilesProvider.notifier).add(content.path);
        }
        return;
      }
      // (c) Else create a tab in this pane
    }

    // Creating a tab
    final settingMode = ref.read(vaultSettingsProvider).defaultViewMode;
    final initialMode = settingMode == 'source'
        ? ViewMode.source
        : ViewMode.reading;

    final newTabState = TabState(
      id: _nextTabId(),
      history: [content],
      historyIndex: 0,
      mode: initialMode,
    );

    final newTabs = List<TabState>.of(pane.tabs);
    final insertIndex = pane.tabs.isEmpty ? 0 : pane.activeIndex + 1;
    newTabs.insert(insertIndex, newTabState);

    int newActiveIndex;
    if (background && pane.tabs.isNotEmpty) {
      newActiveIndex = insertIndex <= pane.activeIndex
          ? pane.activeIndex + 1
          : pane.activeIndex;
    } else {
      newActiveIndex = insertIndex;
    }

    pane = pane.copyWith(tabs: newTabs, activeIndex: newActiveIndex);
    panes[focusedIndex] = pane;
    state = state.copyWith(panes: panes, focusedPane: focusedIndex);
    _scheduleSave();

    if (content is FileTabContent) {
      ref.read(recentFilesProvider.notifier).add(content.path);
    }
  }

  void closeTab(String paneId, String tabId) {
    final paneIdx = state.panes.indexWhere((p) => p.id == paneId);
    if (paneIdx == -1) return;
    final pane = state.panes[paneIdx];
    final tabIdx = pane.tabs.indexWhere((t) => t.id == tabId);
    if (tabIdx == -1) return;

    final newTabs = List<TabState>.of(pane.tabs)..removeAt(tabIdx);
    final panes = List<PaneState>.of(state.panes);

    if (newTabs.isEmpty) {
      if (panes.length == 2) {
        panes.removeAt(paneIdx);
        state = state.copyWith(panes: panes, focusedPane: 0);
        _scheduleSave();
        return;
      } else {
        panes[paneIdx] = pane.copyWith(tabs: const [], activeIndex: 0);
        state = state.copyWith(panes: panes);
        _scheduleSave();
        return;
      }
    }

    int newActive;
    if (tabIdx < pane.activeIndex) {
      newActive = pane.activeIndex - 1;
    } else if (tabIdx == pane.activeIndex) {
      newActive = tabIdx < newTabs.length ? tabIdx : newTabs.length - 1;
    } else {
      newActive = pane.activeIndex;
    }

    panes[paneIdx] = pane.copyWith(tabs: newTabs, activeIndex: newActive);
    state = state.copyWith(panes: panes);
    _scheduleSave();
  }

  void closeTabById(String tabId) {
    for (final pane in state.panes) {
      if (pane.tabs.any((t) => t.id == tabId)) {
        closeTab(pane.id, tabId);
        return;
      }
    }
  }

  void closeOtherTabs(String paneId, String tabId) {
    final paneIdx = state.panes.indexWhere((p) => p.id == paneId);
    if (paneIdx == -1) return;
    final pane = state.panes[paneIdx];
    final tab = pane.tabs.where((t) => t.id == tabId).firstOrNull;
    if (tab == null) return;
    final panes = List<PaneState>.of(state.panes);
    panes[paneIdx] = pane.copyWith(tabs: [tab], activeIndex: 0);
    state = state.copyWith(panes: panes);
    _scheduleSave();
  }

  void activateTab(String paneId, String tabId) {
    final paneIdx = state.panes.indexWhere((p) => p.id == paneId);
    if (paneIdx == -1) return;
    final pane = state.panes[paneIdx];
    final tabIdx = pane.tabs.indexWhere((t) => t.id == tabId);
    if (tabIdx == -1) return;
    final panes = List<PaneState>.of(state.panes);
    panes[paneIdx] = pane.copyWith(activeIndex: tabIdx);
    state = state.copyWith(panes: panes, focusedPane: paneIdx);
    _scheduleSave();
  }

  void focusPane(String paneId) {
    final paneIdx = state.panes.indexWhere((p) => p.id == paneId);
    if (paneIdx != -1 && paneIdx != state.focusedPane) {
      state = state.copyWith(focusedPane: paneIdx);
      _scheduleSave();
    }
  }

  void moveTab(String paneId, int from, int to) {
    final paneIdx = state.panes.indexWhere((p) => p.id == paneId);
    if (paneIdx == -1) return;
    final pane = state.panes[paneIdx];
    if (from < 0 || from >= pane.tabs.length) return;
    if (to < 0 || to > pane.tabs.length) return;

    final newTabs = List<TabState>.of(pane.tabs);
    final moved = newTabs.removeAt(from);
    newTabs.insert(to, moved);

    final oldActive = pane.activeIndex;
    int newActive;
    if (oldActive == from) {
      newActive = to;
    } else if (from < oldActive && to >= oldActive) {
      newActive = oldActive - 1;
    } else if (from > oldActive && to <= oldActive) {
      newActive = oldActive + 1;
    } else {
      newActive = oldActive;
    }

    final panes = List<PaneState>.of(state.panes);
    panes[paneIdx] = pane.copyWith(tabs: newTabs, activeIndex: newActive);
    state = state.copyWith(panes: panes);
    _scheduleSave();
  }

  void nextTab() {
    if (state.panes.isEmpty) return;
    final paneIdx = state.focusedPane.clamp(0, state.panes.length - 1);
    final pane = state.panes[paneIdx];
    if (pane.tabs.length <= 1) return;
    final newActive = (pane.activeIndex + 1) % pane.tabs.length;
    final panes = List<PaneState>.of(state.panes);
    panes[paneIdx] = pane.copyWith(activeIndex: newActive);
    state = state.copyWith(panes: panes);
    _scheduleSave();
  }

  void previousTab() {
    if (state.panes.isEmpty) return;
    final paneIdx = state.focusedPane.clamp(0, state.panes.length - 1);
    final pane = state.panes[paneIdx];
    if (pane.tabs.length <= 1) return;
    final newActive =
        (pane.activeIndex - 1 + pane.tabs.length) % pane.tabs.length;
    final panes = List<PaneState>.of(state.panes);
    panes[paneIdx] = pane.copyWith(activeIndex: newActive);
    state = state.copyWith(panes: panes);
    _scheduleSave();
  }

  void goBack() {
    final currentPane = state.currentPane;
    final currentTab = currentPane?.activeTab;
    if (currentTab != null && currentTab.canGoBack) {
      final updatedTab = currentTab.copyWith(
        historyIndex: currentTab.historyIndex - 1,
      );
      final paneIdx = state.focusedPane.clamp(0, state.panes.length - 1);
      final newTabs = List<TabState>.of(currentPane!.tabs);
      newTabs[currentPane.activeIndex] = updatedTab;
      final panes = List<PaneState>.of(state.panes);
      panes[paneIdx] = currentPane.copyWith(tabs: newTabs);
      state = state.copyWith(panes: panes);
      _scheduleSave();
    }
  }

  void goForward() {
    final currentPane = state.currentPane;
    final currentTab = currentPane?.activeTab;
    if (currentTab != null && currentTab.canGoForward) {
      final updatedTab = currentTab.copyWith(
        historyIndex: currentTab.historyIndex + 1,
      );
      final paneIdx = state.focusedPane.clamp(0, state.panes.length - 1);
      final newTabs = List<TabState>.of(currentPane!.tabs);
      newTabs[currentPane.activeIndex] = updatedTab;
      final panes = List<PaneState>.of(state.panes);
      panes[paneIdx] = currentPane.copyWith(tabs: newTabs);
      state = state.copyWith(panes: panes);
      _scheduleSave();
    }
  }

  void setMode(String tabId, ViewMode mode) {
    var modified = false;
    final panes = <PaneState>[];
    for (final p in state.panes) {
      final tabs = <TabState>[];
      for (final t in p.tabs) {
        if (t.id == tabId && t.mode != mode) {
          tabs.add(t.copyWith(mode: mode));
          modified = true;
        } else {
          tabs.add(t);
        }
      }
      panes.add(p.copyWith(tabs: tabs));
    }
    if (modified) {
      state = state.copyWith(panes: panes);
      _scheduleSave();
    }
  }

  void toggleMode() {
    final tab = state.focusedTab;
    if (tab != null) {
      final newMode = tab.mode == ViewMode.reading
          ? ViewMode.source
          : ViewMode.reading;
      setMode(tab.id, newMode);
    }
  }

  void splitFocused(SplitAxis axis) {
    if (state.panes.length == 1) {
      final activeTab = state.panes[0].activeTab;
      if (activeTab != null) {
        final copiedTab = TabState(
          id: _nextTabId(),
          history: List.of(activeTab.history),
          historyIndex: activeTab.historyIndex,
          mode: activeTab.mode,
        );
        final newPane = PaneState(
          id: _nextPaneId(),
          tabs: [copiedTab],
          activeIndex: 0,
        );
        state = state.copyWith(
          panes: [state.panes[0], newPane],
          axis: axis,
          focusedPane: 1,
        );
        _scheduleSave();
      }
    } else if (state.panes.length == 2) {
      state = state.copyWith(axis: axis);
      _scheduleSave();
    }
  }

  void closePane(String paneId) {
    if (state.panes.length != 2) return;
    final closeIdx = state.panes.indexWhere((p) => p.id == paneId);
    if (closeIdx == -1) return;
    final keepIdx = 1 - closeIdx;
    final closingPane = state.panes[closeIdx];
    final keepingPane = state.panes[keepIdx];

    final mergedTabs = List<TabState>.of(keepingPane.tabs)
      ..addAll(closingPane.tabs);
    final newPane = keepingPane.copyWith(tabs: mergedTabs);
    state = state.copyWith(panes: [newPane], focusedPane: 0);
    _scheduleSave();
  }

  void setSplitRatio(double r) {
    state = state.copyWith(splitRatio: r.clamp(0.2, 0.8));
    _scheduleSave();
  }

  void toggleLeftSidebar() {
    state = state.copyWith(leftSidebarVisible: !state.leftSidebarVisible);
    _scheduleSave();
  }

  void setLeftSidebarVisible(bool visible) {
    if (state.leftSidebarVisible != visible) {
      state = state.copyWith(leftSidebarVisible: visible);
      _scheduleSave();
    }
  }

  void toggleRightSidebar() {
    state = state.copyWith(rightSidebarVisible: !state.rightSidebarVisible);
    _scheduleSave();
  }

  void setLeftSidebarWidth(double w) {
    state = state.copyWith(leftSidebarWidth: w.clamp(180.0, 480.0));
    _scheduleSave();
  }

  void setRightSidebarWidth(double w) {
    state = state.copyWith(rightSidebarWidth: w.clamp(200.0, 520.0));
    _scheduleSave();
  }

  void retargetPath(VaultPath from, VaultPath to) {
    TabContent retarget(TabContent c) {
      if (c is FileTabContent) {
        if (c.path == from) {
          return FileTabContent(to, subpath: c.subpath);
        }
        if (c.path.value.startsWith('${from.value}/')) {
          final remainder = c.path.value.substring(from.value.length + 1);
          final newPath = VaultPath('${to.value}/$remainder');
          return FileTabContent(newPath, subpath: c.subpath);
        }
      }
      return c;
    }

    final newPanes = state.panes.map((p) {
      final newTabs = p.tabs.map((t) {
        final newHistory = t.history.map(retarget).toList();
        return t.copyWith(history: newHistory);
      }).toList();
      return p.copyWith(tabs: newTabs);
    }).toList();

    state = state.copyWith(panes: newPanes);
    _scheduleSave();
  }

  void removePath(VaultPath path) {
    bool isMatch(VaultPath target) =>
        target == path || target.value.startsWith('${path.value}/');

    final newPanes = <PaneState>[];
    for (final p in state.panes) {
      final newTabs = <TabState>[];
      for (final t in p.tabs) {
        final validHistory = <TabContent>[];
        var newHistoryIndex = 0;
        for (var i = 0; i < t.history.length; i++) {
          final c = t.history[i];
          var removed = false;
          if (c is FileTabContent && isMatch(c.path)) {
            removed = true;
          }
          if (!removed) {
            if (i <= t.historyIndex) {
              newHistoryIndex = validHistory.length;
            }
            validHistory.add(c);
          }
        }
        if (validHistory.isNotEmpty) {
          if (newHistoryIndex >= validHistory.length) {
            newHistoryIndex = validHistory.length - 1;
          }
          newTabs.add(
            t.copyWith(history: validHistory, historyIndex: newHistoryIndex),
          );
        }
      }
      if (newTabs.isNotEmpty) {
        final newActive = p.activeIndex.clamp(0, newTabs.length - 1);
        newPanes.add(p.copyWith(tabs: newTabs, activeIndex: newActive));
      } else if (state.panes.length == 1) {
        // If it's the only pane, keep it empty
        newPanes.add(p.copyWith(tabs: const [], activeIndex: 0));
      }
    }
    final newFocused = state.focusedPane.clamp(
      0,
      newPanes.isEmpty ? 0 : newPanes.length - 1,
    );
    state = state.copyWith(panes: newPanes, focusedPane: newFocused);
    _scheduleSave();
  }

  Future<void> restore() async {
    final session = ref.read(vaultSessionProvider);
    if (session == null) return;
    final deviceId = ref.read(appSettingsProvider).deviceId;
    final restored = await _persistence.restore(
      fs: session.fs,
      deviceId: deviceId,
    );
    if (restored != null) {
      if (restored.recent.isNotEmpty) {
        ref.read(recentFilesProvider.notifier).set(restored.recent);
      }
      if (restored.state.panes.isNotEmpty) {
        state = restored.state;
      }
    }
  }
}
