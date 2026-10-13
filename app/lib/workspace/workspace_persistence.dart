// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../core/json_file_store.dart';
import 'tab_content.dart';
import 'workspace_models.dart';

final class WorkspacePersistence {
  WorkspacePersistence({TephraJsonStore? jsonStore})
    : _jsonStore = jsonStore ?? const TephraJsonStore();

  final TephraJsonStore _jsonStore;
  static final _workspacePath = VaultPath('.tephra/workspace.json');

  Future<void> save({
    required VaultFileSystem fs,
    required String deviceId,
    required WorkspaceState state,
    required List<VaultPath> recentFiles,
  }) async {
    final entry = <String, Object?>{
      'panes': state.panes.map((p) => p.toJson()).toList(),
      'axis': state.axis.name,
      'focused': state.focusedPane,
      'splitRatio': state.splitRatio,
      'leftSidebar': {
        'visible': state.leftSidebarVisible,
        'width': state.leftSidebarWidth,
      },
      'rightSidebar': {
        'visible': state.rightSidebarVisible,
        'width': state.rightSidebarWidth,
      },
      'recent': recentFiles.map((p) => p.value).toList(),
    };

    await _jsonStore.update(fs, _workspacePath, (map) {
      map[deviceId] = entry;
    });
  }

  Future<({WorkspaceState state, List<VaultPath> recent})?> restore({
    required VaultFileSystem fs,
    required String deviceId,
  }) async {
    final rootMap = await _jsonStore.readMap(fs, _workspacePath);
    final rawDevice = rootMap[deviceId];
    if (rawDevice is! Map) {
      return null;
    }
    final deviceMap = Map<String, Object?>.from(rawDevice);

    final recentList = <VaultPath>[];
    final rawRecent = deviceMap['recent'] as List<dynamic>?;
    if (rawRecent != null) {
      for (final r in rawRecent) {
        if (r is String) {
          final p = VaultPath.tryParse(r);
          if (p != null) {
            recentList.add(p);
          }
        }
      }
    }

    final rawPanes = deviceMap['panes'] as List<dynamic>?;
    final panes = <PaneState>[];
    var paneCounter = 1;
    var tabCounter = 1;

    if (rawPanes != null) {
      for (final rawPane in rawPanes) {
        if (rawPane is! Map) continue;
        final pMap = Map<String, Object?>.from(rawPane);
        final rawTabs = pMap['tabs'] as List<dynamic>?;
        final tabs = <TabState>[];

        if (rawTabs != null) {
          for (final rawTab in rawTabs) {
            if (rawTab is! Map) continue;
            final tMap = Map<String, Object?>.from(rawTab);
            final rawHistory = tMap['history'] as List<dynamic>?;
            if (rawHistory == null || rawHistory.isEmpty) continue;

            final validHistory = <TabContent>[];
            final oldIndex = (tMap['index'] as num?)?.toInt() ?? 0;
            var newIndex = 0;

            for (var i = 0; i < rawHistory.length; i++) {
              final rawContent = rawHistory[i];
              if (rawContent is! Map) continue;
              final content = TabContent.fromJson(
                Map<String, Object?>.from(rawContent),
              );
              if (content == null) continue;

              // Check if file exists on disk
              if (content is FileTabContent) {
                final stat = await fs.stat(content.path);
                if (stat == null) {
                  continue;
                }
              }

              if (i <= oldIndex) {
                newIndex = validHistory.length;
              }
              validHistory.add(content);
            }

            if (validHistory.isNotEmpty) {
              final modeStr = tMap['mode'] as String?;
              final mode = modeStr == 'source'
                  ? ViewMode.source
                  : ViewMode.reading;
              if (newIndex >= validHistory.length) {
                newIndex = validHistory.length - 1;
              }
              tabs.add(
                TabState(
                  id: 'tab-${tabCounter++}',
                  history: validHistory,
                  historyIndex: newIndex,
                  mode: mode,
                ),
              );
            }
          }
        }

        if (tabs.isNotEmpty) {
          var active = (pMap['active'] as num?)?.toInt() ?? 0;
          if (active < 0) active = 0;
          if (active >= tabs.length) active = tabs.length - 1;
          panes.add(
            PaneState(
              id: 'pane-${paneCounter++}',
              tabs: tabs,
              activeIndex: active,
            ),
          );
        }
      }
    }

    final axisStr = deviceMap['axis'] as String?;
    final axis = axisStr == 'vertical'
        ? SplitAxis.vertical
        : SplitAxis.horizontal;

    var focused = (deviceMap['focused'] as num?)?.toInt() ?? 0;
    if (focused < 0) focused = 0;
    if (panes.isNotEmpty && focused >= panes.length) focused = panes.length - 1;

    final splitRatio = (deviceMap['splitRatio'] as num?)?.toDouble() ?? 0.5;

    final leftSidebar = deviceMap['leftSidebar'] as Map?;
    final leftVisible = leftSidebar?['visible'] as bool? ?? true;
    final leftWidth = (leftSidebar?['width'] as num?)?.toDouble() ?? 280.0;

    final rightSidebar = deviceMap['rightSidebar'] as Map?;
    final rightVisible = rightSidebar?['visible'] as bool? ?? true;
    final rightWidth = (rightSidebar?['width'] as num?)?.toDouble() ?? 300.0;

    final state = WorkspaceState(
      panes: panes,
      axis: axis,
      focusedPane: focused,
      splitRatio: splitRatio.clamp(0.2, 0.8),
      leftSidebarVisible: leftVisible,
      leftSidebarWidth: leftWidth.clamp(180.0, 480.0),
      rightSidebarVisible: rightVisible,
      rightSidebarWidth: rightWidth.clamp(200.0, 520.0),
    );

    return (state: state, recent: recentList);
  }
}
