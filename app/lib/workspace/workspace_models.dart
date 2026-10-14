// © 2026 Tephra. All rights reserved.

import 'package:flutter/foundation.dart';

import 'tab_content.dart';

enum ViewMode { reading, source }

enum SplitAxis { horizontal, vertical }

@immutable
final class TabState {
  const TabState({
    required this.id,
    required this.history,
    required this.historyIndex,
    required this.mode,
  });

  final String id;
  final List<TabContent> history;
  final int historyIndex;
  final ViewMode mode;

  TabContent get content => history[historyIndex];
  bool get canGoBack => historyIndex > 0;
  bool get canGoForward => historyIndex < history.length - 1;

  TabState copyWith({
    String? id,
    List<TabContent>? history,
    int? historyIndex,
    ViewMode? mode,
  }) => TabState(
    id: id ?? this.id,
    history: history ?? this.history,
    historyIndex: historyIndex ?? this.historyIndex,
    mode: mode ?? this.mode,
  );

  Map<String, Object?> toJson() => {
    'history': history.map((c) => c.toJson()).toList(),
    'index': historyIndex,
    'mode': mode.name,
  };

  static TabState? fromJson(Map<String, Object?> json, {required String id}) {
    final rawHistory = json['history'] as List<dynamic>?;
    if (rawHistory == null || rawHistory.isEmpty) return null;

    final history = <TabContent>[];
    for (final item in rawHistory) {
      if (item is Map) {
        final content = TabContent.fromJson(Map<String, Object?>.from(item));
        if (content != null) {
          history.add(content);
        }
      }
    }
    if (history.isEmpty) return null;

    var index = (json['index'] as num?)?.toInt() ?? 0;
    if (index < 0) index = 0;
    if (index >= history.length) index = history.length - 1;

    final modeStr = json['mode'] as String?;
    final mode = modeStr == 'source' ? ViewMode.source : ViewMode.reading;

    return TabState(id: id, history: history, historyIndex: index, mode: mode);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TabState &&
          other.runtimeType == runtimeType &&
          other.id == id &&
          listEquals(other.history, history) &&
          other.historyIndex == historyIndex &&
          other.mode == mode;

  @override
  int get hashCode =>
      Object.hash(id, Object.hashAll(history), historyIndex, mode);

  @override
  String toString() =>
      'TabState(id: $id, content: $content, historyIndex: $historyIndex, mode: $mode)';
}

@immutable
final class PaneState {
  const PaneState({
    required this.id,
    required this.tabs,
    required this.activeIndex,
  });

  final String id;
  final List<TabState> tabs;
  final int activeIndex;

  TabState? get activeTab =>
      tabs.isEmpty ? null : tabs[activeIndex.clamp(0, tabs.length - 1)];

  PaneState copyWith({String? id, List<TabState>? tabs, int? activeIndex}) =>
      PaneState(
        id: id ?? this.id,
        tabs: tabs ?? this.tabs,
        activeIndex: activeIndex ?? this.activeIndex,
      );

  Map<String, Object?> toJson() => {
    'tabs': tabs.map((t) => t.toJson()).toList(),
    'active': activeIndex,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaneState &&
          other.runtimeType == runtimeType &&
          other.id == id &&
          listEquals(other.tabs, tabs) &&
          other.activeIndex == activeIndex;

  @override
  int get hashCode => Object.hash(id, Object.hashAll(tabs), activeIndex);

  @override
  String toString() =>
      'PaneState(id: $id, tabs: ${tabs.length}, activeIndex: $activeIndex)';
}

@immutable
final class WorkspaceState {
  const WorkspaceState({
    this.panes = const [],
    this.axis = SplitAxis.horizontal,
    this.focusedPane = 0,
    this.splitRatio = 0.5,
    this.leftSidebarVisible = true,
    this.leftSidebarWidth = 280,
    this.rightSidebarVisible = true,
    this.rightSidebarWidth = 300,
  });

  final List<PaneState> panes;
  final SplitAxis axis;
  final int focusedPane;
  final double splitRatio;
  final bool leftSidebarVisible;
  final double leftSidebarWidth;
  final bool rightSidebarVisible;
  final double rightSidebarWidth;

  PaneState? get currentPane =>
      panes.isEmpty ? null : panes[focusedPane.clamp(0, panes.length - 1)];

  TabState? get focusedTab => currentPane?.activeTab;

  TabState? findTab(String id) {
    for (final pane in panes) {
      for (final tab in pane.tabs) {
        if (tab.id == id) return tab;
      }
    }
    return null;
  }

  WorkspaceState copyWith({
    List<PaneState>? panes,
    SplitAxis? axis,
    int? focusedPane,
    double? splitRatio,
    bool? leftSidebarVisible,
    double? leftSidebarWidth,
    bool? rightSidebarVisible,
    double? rightSidebarWidth,
  }) => WorkspaceState(
    panes: panes ?? this.panes,
    axis: axis ?? this.axis,
    focusedPane: focusedPane ?? this.focusedPane,
    splitRatio: splitRatio ?? this.splitRatio,
    leftSidebarVisible: leftSidebarVisible ?? this.leftSidebarVisible,
    leftSidebarWidth: leftSidebarWidth ?? this.leftSidebarWidth,
    rightSidebarVisible: rightSidebarVisible ?? this.rightSidebarVisible,
    rightSidebarWidth: rightSidebarWidth ?? this.rightSidebarWidth,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkspaceState &&
          other.runtimeType == runtimeType &&
          listEquals(other.panes, panes) &&
          other.axis == axis &&
          other.focusedPane == focusedPane &&
          other.splitRatio == splitRatio &&
          other.leftSidebarVisible == leftSidebarVisible &&
          other.leftSidebarWidth == leftSidebarWidth &&
          other.rightSidebarVisible == rightSidebarVisible &&
          other.rightSidebarWidth == rightSidebarWidth;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(panes),
    axis,
    focusedPane,
    splitRatio,
    leftSidebarVisible,
    leftSidebarWidth,
    rightSidebarVisible,
    rightSidebarWidth,
  );

  @override
  String toString() =>
      'WorkspaceState(panes: ${panes.length}, focused: $focusedPane, axis: $axis)';
}
