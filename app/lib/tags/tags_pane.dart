// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_index/tephra_index.dart';

import '../l10n/app_localizations.dart';
import '../search/providers.dart';
import '../search/search_screen.dart';
import 'providers.dart';
import 'tag_tree.dart';

/// Sidebar panel presenting the nested tag tree with counts.
class TagsPane extends ConsumerStatefulWidget {
  const TagsPane({super.key});

  @override
  ConsumerState<TagsPane> createState() => _TagsPaneState();
}

class _TagsPaneState extends ConsumerState<TagsPane> {
  final Set<String> _expanded = {};

  void _onTagTap(BuildContext context, TagNode node) {
    final query = 'tag:#${node.fullTag}';
    ref.read(searchControllerProvider.notifier).setQuery(query);

    final width = MediaQuery.sizeOf(context).width;
    if (width >= 840) {
      ref.read(activeLeftSidebarPanelProvider.notifier).select('search');
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SearchScreen(initialQuery: query),
        ),
      );
    }
  }

  List<Widget> _buildTreeRows(
    BuildContext context,
    List<TagNode> nodes,
    int depth,
  ) {
    final widgets = <Widget>[];
    final theme = Theme.of(context);

    for (final node in nodes) {
      final hasChildren = node.children.isNotEmpty;
      final isExpanded = _expanded.contains(node.fullTag);

      widgets.add(
        InkWell(
          onTap: () => _onTagTap(context, node),
          child: Padding(
            padding: EdgeInsets.only(
              left: 8.0 + depth * 16.0,
              right: 12.0,
              top: 4.0,
              bottom: 4.0,
            ),
            child: Row(
              children: [
                if (hasChildren)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      setState(() {
                        if (isExpanded) {
                          _expanded.remove(node.fullTag);
                        } else {
                          _expanded.add(node.fullTag);
                        }
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4.0),
                      child: Icon(
                        isExpanded ? Icons.expand_more : Icons.chevron_right,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 22),
                Expanded(
                  child: Text(
                    '#${node.segment}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 13,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${node.count}',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      if (hasChildren && isExpanded) {
        widgets.addAll(_buildTreeRows(context, node.children, depth + 1));
      }
    }
    return widgets;
  }

  String _sortLabel(AppLocalizations l10n, TagSortMode mode) {
    switch (mode) {
      case TagSortMode.nameAZ:
        return l10n.tagSortNameAZ;
      case TagSortMode.frequency:
        return l10n.tagSortFrequency;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final sortMode = ref.watch(tagSortModeProvider);
    final showNested = ref.watch(tagShowNestedProvider);
    final treeAsync = ref.watch(tagTreeProvider);

    return Column(
      children: [
        // Toolbar
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: theme.dividerColor.withAlpha(40),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Text(
                l10n.sidebarTags,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                iconSize: 18,
                tooltip: showNested ? l10n.tagShowFlat : l10n.tagShowNested,
                icon: Icon(
                  showNested
                      ? Icons.account_tree_outlined
                      : Icons.format_list_bulleted,
                ),
                onPressed: () {
                  ref.read(tagShowNestedProvider.notifier).toggle();
                },
              ),
              PopupMenuButton<TagSortMode>(
                iconSize: 18,
                icon: const Icon(Icons.sort),
                tooltip: _sortLabel(l10n, sortMode),
                initialValue: sortMode,
                onSelected: (mode) {
                  ref.read(tagSortModeProvider.notifier).setMode(mode);
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: TagSortMode.nameAZ,
                    child: Text(l10n.tagSortNameAZ),
                  ),
                  PopupMenuItem(
                    value: TagSortMode.frequency,
                    child: Text(l10n.tagSortFrequency),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Tag List / Tree
        Expanded(
          child: treeAsync.when(
            loading: () => const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (err, _) {
              if (err is IndexUnavailableException) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      l10n.indexUnavailableOnWeb,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              }
              return Center(
                child: Text(
                  '$err',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              );
            },
            data: (nodes) {
              if (nodes.isEmpty) {
                return Center(
                  child: Text(
                    l10n.tagNoTags,
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                );
              }

              if (showNested) {
                return ListView(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  children: _buildTreeRows(context, nodes, 0),
                );
              } else {
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: nodes.length,
                  itemBuilder: (context, index) {
                    final node = nodes[index];
                    return InkWell(
                      onTap: () => _onTagTap(context, node),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: 6.0,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '#${node.fullTag}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${node.count}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }
            },
          ),
        ),
      ],
    );
  }
}
