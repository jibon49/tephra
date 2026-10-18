// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../search/providers.dart';
import 'empty_workspace_view.dart';
import 'pane_view.dart';
import 'providers.dart';
import 'sidebar_registry.dart';
import 'split_divider.dart';
import 'status_bar.dart';
import 'workspace_models.dart';

class DesktopLayout extends ConsumerStatefulWidget {
  const DesktopLayout({super.key});

  @override
  ConsumerState<DesktopLayout> createState() => _DesktopLayoutState();
}

class _DesktopLayoutState extends ConsumerState<DesktopLayout> {
  int _activeLeftPanelIndex = 0;
  int _activeRightPanelIndex = 0;

  Widget _buildSidebarContent(
    List<SidebarPanelSpec> panels,
    int activeIndex,
    ValueChanged<int> onSelect,
  ) {
    if (panels.isEmpty) return const SizedBox.shrink();
    if (panels.length == 1) {
      return panels[0].builder(context, ref);
    }

    final safeIndex = activeIndex.clamp(0, panels.length - 1);
    final theme = Theme.of(context);

    return Column(
      children: [
        Container(
          height: 36,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withAlpha(40),
            border: Border(
              bottom: BorderSide(
                color: theme.dividerColor.withAlpha(40),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              for (var i = 0; i < panels.length; i++)
                IconButton(
                  iconSize: 18,
                  icon: Icon(panels[i].icon),
                  color: i == safeIndex
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  onPressed: () => onSelect(i),
                ),
            ],
          ),
        ),
        Expanded(child: panels[safeIndex].builder(context, ref)),
      ],
    );
  }

  Widget _buildPanes(WorkspaceState state) {
    if (state.panes.isEmpty) {
      return const EmptyWorkspaceView();
    }
    if (state.panes.length == 1) {
      return PaneView(pane: state.panes[0], isSinglePane: true);
    }

    final isHorizontal = state.axis == SplitAxis.horizontal;
    final firstFlex = (state.splitRatio * 1000).round();
    final secondFlex = 1000 - firstFlex;

    if (isHorizontal) {
      return Row(
        children: [
          Expanded(
            flex: firstFlex,
            child: PaneView(pane: state.panes[0]),
          ),
          const SplitDivider(axis: SplitAxis.horizontal),
          Expanded(
            flex: secondFlex,
            child: PaneView(pane: state.panes[1]),
          ),
        ],
      );
    } else {
      return Column(
        children: [
          Expanded(
            flex: firstFlex,
            child: PaneView(pane: state.panes[0]),
          ),
          const SplitDivider(axis: SplitAxis.vertical),
          Expanded(
            flex: secondFlex,
            child: PaneView(pane: state.panes[1]),
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workspaceProvider);
    final theme = Theme.of(context);

    final leftPanels = ref
        .watch(sidebarRegistryProvider.notifier)
        .panelsFor(SidebarSide.left);
    final rightPanels = ref
        .watch(sidebarRegistryProvider.notifier)
        .panelsFor(SidebarSide.right);

    final showLeft = state.leftSidebarVisible && leftPanels.isNotEmpty;
    final showRight = state.rightSidebarVisible && rightPanels.isNotEmpty;

    ref.listen<String?>(activeLeftSidebarPanelProvider, (prev, next) {
      if (next != null) {
        final idx = leftPanels.indexWhere((p) => p.id == next);
        if (idx != -1) {
          setState(() => _activeLeftPanelIndex = idx);
          ref.read(workspaceProvider.notifier).setLeftSidebarVisible(true);
        }
        ref.read(activeLeftSidebarPanelProvider.notifier).select(null);
      }
    });

    return Material(
      color: theme.colorScheme.surface,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showLeft) ...[
            SizedBox(
              width: state.leftSidebarWidth,
              child: Container(
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(20),
                child: _buildSidebarContent(
                  leftPanels,
                  _activeLeftPanelIndex,
                  (idx) => setState(() => _activeLeftPanelIndex = idx),
                ),
              ),
            ),
            MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (details) {
                  ref
                      .read(workspaceProvider.notifier)
                      .setLeftSidebarWidth(
                        state.leftSidebarWidth + details.delta.dx,
                      );
                },
                child: Container(
                  width: 6,
                  color: theme.dividerColor.withAlpha(40),
                ),
              ),
            ),
          ],
          Expanded(
            child: Column(
              children: [
                Expanded(child: _buildPanes(state)),
                const StatusBar(),
              ],
            ),
          ),
          if (showRight) ...[
            MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (details) {
                  ref
                      .read(workspaceProvider.notifier)
                      .setRightSidebarWidth(
                        state.rightSidebarWidth - details.delta.dx,
                      );
                },
                child: Container(
                  width: 6,
                  color: theme.dividerColor.withAlpha(40),
                ),
              ),
            ),
            SizedBox(
              width: state.rightSidebarWidth,
              child: Container(
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(20),
                child: _buildSidebarContent(
                  rightPanels,
                  _activeRightPanelIndex,
                  (idx) => setState(() => _activeRightPanelIndex = idx),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
