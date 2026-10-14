// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'empty_workspace_view.dart';
import 'providers.dart';
import 'tab_bar_view.dart';
import 'workspace_models.dart';

class PaneView extends ConsumerWidget {
  const PaneView({required this.pane, this.isSinglePane = false, super.key});

  final PaneState pane;
  final bool isSinglePane;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final viewRegistry = ref.watch(viewRegistryProvider);
    final focusedIndex = ref.watch(
      workspaceProvider.select((w) => w.focusedPane),
    );
    final allPanes = ref.watch(workspaceProvider.select((w) => w.panes));
    final isFocused =
        allPanes.isNotEmpty &&
        allPanes[focusedIndex.clamp(0, allPanes.length - 1)].id == pane.id;

    final activeTab = pane.activeTab;

    return Listener(
      onPointerDown: (_) {
        ref.read(workspaceProvider.notifier).focusPane(pane.id);
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: (!isSinglePane && isFocused)
                ? BorderSide(color: theme.colorScheme.primary, width: 2)
                : BorderSide.none,
          ),
        ),
        child: Column(
          children: [
            WorkspaceTabBarView(pane: pane),
            Expanded(
              child: activeTab == null
                  ? const EmptyWorkspaceView()
                  : KeyedSubtree(
                      key: ValueKey(activeTab.id),
                      child: viewRegistry.build(
                        context,
                        ref,
                        activeTab.content,
                        activeTab.id,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
