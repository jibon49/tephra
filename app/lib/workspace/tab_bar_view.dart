// © 2026 Tephra. All rights reserved.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import 'providers.dart';
import 'tab_content.dart';
import 'workspace_models.dart';

class WorkspaceTabBarView extends ConsumerWidget {
  const WorkspaceTabBarView({required this.pane, super.key});

  final PaneState pane;

  void _showContextMenu(
    BuildContext context,
    WidgetRef ref,
    String paneId,
    String tabId,
    Offset position,
  ) {
    final l10n = AppLocalizations.of(context);
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(value: 'close', child: Text(l10n.tabClose)),
        PopupMenuItem(value: 'closeOthers', child: Text(l10n.tabCloseOthers)),
        PopupMenuItem(value: 'splitRight', child: Text(l10n.tabSplitRight)),
        PopupMenuItem(value: 'splitDown', child: Text(l10n.tabSplitDown)),
      ],
    ).then((value) {
      if (value == null) return;
      final notifier = ref.read(workspaceProvider.notifier);
      switch (value) {
        case 'close':
          notifier.closeTab(paneId, tabId);
        case 'closeOthers':
          notifier.closeOtherTabs(paneId, tabId);
        case 'splitRight':
          notifier.activateTab(paneId, tabId);
          notifier.splitFocused(SplitAxis.horizontal);
        case 'splitDown':
          notifier.activateTab(paneId, tabId);
          notifier.splitFocused(SplitAxis.vertical);
      }
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final viewRegistry = ref.watch(viewRegistryProvider);
    final activeTab = pane.activeTab;

    return Container(
      key: const Key('desktop.tabbar'),
      height: 40,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(60),
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withAlpha(50), width: 1),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(Icons.arrow_back),
            tooltip: l10n.workspaceBack,
            onPressed: (activeTab?.canGoBack ?? false)
                ? () => ref.read(workspaceProvider.notifier).goBack()
                : null,
          ),
          IconButton(
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(Icons.arrow_forward),
            tooltip: l10n.workspaceForward,
            onPressed: (activeTab?.canGoForward ?? false)
                ? () => ref.read(workspaceProvider.notifier).goForward()
                : null,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              buildDefaultDragHandles: false,
              itemCount: pane.tabs.length,
              onReorderItem: (from, to) {
                ref.read(workspaceProvider.notifier).moveTab(pane.id, from, to);
              },
              itemBuilder: (context, index) {
                final tab = pane.tabs[index];
                final isActive = index == pane.activeIndex;
                final isDirty =
                    tab.content is FileTabContent &&
                    ref.watch(
                      tabDirtyProvider((tab.content as FileTabContent).path),
                    );

                return ReorderableDragStartListener(
                  key: ValueKey(tab.id),
                  index: index,
                  child: Listener(
                    onPointerDown: (event) {
                      if (event.buttons == kMiddleMouseButton) {
                        ref
                            .read(workspaceProvider.notifier)
                            .closeTab(pane.id, tab.id);
                      }
                    },
                    child: GestureDetector(
                      onTap: () {
                        ref
                            .read(workspaceProvider.notifier)
                            .activateTab(pane.id, tab.id);
                      },
                      onSecondaryTapDown: (details) {
                        _showContextMenu(
                          context,
                          ref,
                          pane.id,
                          tab.id,
                          details.globalPosition,
                        );
                      },
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 180),
                        margin: const EdgeInsets.only(top: 4, right: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: isActive
                              ? theme.colorScheme.surface
                              : Colors.transparent,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                          border: Border(
                            top: BorderSide(
                              color: isActive
                                  ? theme.colorScheme.primary
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              viewRegistry.iconFor(tab.content),
                              size: 16,
                              color: isActive
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                viewRegistry.titleFor(tab.content, l10n),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: isActive
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (isDirty) ...[
                              const SizedBox(width: 4),
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.close, size: 14),
                              tooltip: l10n.tabClose,
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints(
                                minWidth: 20,
                                minHeight: 20,
                              ),
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                ref
                                    .read(workspaceProvider.notifier)
                                    .closeTab(pane.id, tab.id);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
