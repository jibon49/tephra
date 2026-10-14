// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../explorer/providers.dart';
import '../l10n/app_localizations.dart';
import '../search/providers.dart';
import 'bookmark.dart';
import 'providers.dart';

/// Returns display label for a bookmark: custom title or derived fallback.
String bookmarkLabel(Bookmark b) {
  if (b.title != null && b.title!.trim().isNotEmpty) {
    return b.title!;
  }
  return switch (b) {
    FileBookmark(:final path, :final subpath) => () {
      if (subpath != null && subpath.isNotEmpty) {
        final cleanSub = subpath.startsWith('#')
            ? subpath.substring(1)
            : subpath;
        return '${path.stem} > $cleanSub';
      }
      return path.stem;
    }(),
    FolderBookmark(:final path) =>
      path.name.isNotEmpty ? path.name : path.value,
    SearchBookmark(:final query) => query,
    GroupBookmark(:final title) => title ?? 'Group',
    UnknownBookmark(:final raw) =>
      (raw['title'] as String?) ?? (raw['type'] as String?) ?? 'Bookmark',
  };
}

/// Returns icon representing the bookmark kind.
IconData bookmarkIcon(Bookmark b, {bool isExpanded = false}) {
  return switch (b) {
    FileBookmark(:final subpath) => () {
      if (subpath != null && subpath.startsWith('#^')) {
        return Icons.view_headline;
      } else if (subpath != null && subpath.startsWith('#')) {
        return Icons.tag;
      }
      return Icons.description_outlined;
    }(),
    FolderBookmark() => Icons.folder_outlined,
    SearchBookmark() => Icons.search,
    GroupBookmark() => isExpanded ? Icons.folder_open : Icons.folder,
    UnknownBookmark() => Icons.help_outline,
  };
}

/// Dialog for creating a new bookmark group.
Future<String?> showBookmarkGroupDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.bookmarkNewGroup),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(hintText: l10n.bookmarkGroupPrompt),
        onSubmitted: (val) => Navigator.of(ctx).pop(val.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(l10n.bookmarkCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
          child: Text(l10n.bookmarkCreate),
        ),
      ],
    ),
  );
}

/// Dialog for renaming a bookmark.
Future<String?> showBookmarkRenameDialog(
  BuildContext context,
  String currentTitle,
) async {
  final l10n = AppLocalizations.of(context);
  final controller = TextEditingController(text: currentTitle);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.bookmarkRename),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(hintText: l10n.bookmarkRenamePrompt),
        onSubmitted: (val) => Navigator.of(ctx).pop(val.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(l10n.bookmarkCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
          child: Text(l10n.bookmarkSave),
        ),
      ],
    ),
  );
}

/// Flattened representation of a visible bookmark row for the tree list.
final class _FlatBookmarkRow {
  const _FlatBookmarkRow({
    required this.bookmark,
    required this.depth,
    this.parentGroup,
    required this.indexInParent,
    required this.parentCount,
  });

  final Bookmark bookmark;
  final int depth;
  final GroupBookmark? parentGroup;
  final int indexInParent;
  final int parentCount;
}

/// Sidebar pane displaying vault bookmarks in a hierarchical tree.
class BookmarksPane extends ConsumerStatefulWidget {
  const BookmarksPane({super.key});

  @override
  ConsumerState<BookmarksPane> createState() => _BookmarksPaneState();
}

class _BookmarksPaneState extends ConsumerState<BookmarksPane> {
  final Set<int> _collapsedGroupCtimes = {};

  void _toggleGroup(GroupBookmark group) {
    setState(() {
      if (_collapsedGroupCtimes.contains(group.ctime)) {
        _collapsedGroupCtimes.remove(group.ctime);
      } else {
        _collapsedGroupCtimes.add(group.ctime);
      }
    });
  }

  void _flatten(
    List<Bookmark> items,
    int depth,
    GroupBookmark? parentGroup,
    List<_FlatBookmarkRow> result,
  ) {
    for (var i = 0; i < items.length; i++) {
      final b = items[i];
      result.add(
        _FlatBookmarkRow(
          bookmark: b,
          depth: depth,
          parentGroup: parentGroup,
          indexInParent: i,
          parentCount: items.length,
        ),
      );
      if (b is GroupBookmark && !_collapsedGroupCtimes.contains(b.ctime)) {
        _flatten(b.items, depth + 1, b, result);
      }
    }
  }

  bool _isTargetMissing(Bookmark b, Set<String>? indexedPaths) {
    if (indexedPaths == null) return false;
    if (b is FileBookmark) {
      return !indexedPaths.contains(b.path.value);
    }
    if (b is FolderBookmark) {
      final val = b.path.value;
      return !indexedPaths.any((p) => p == val || p.startsWith('$val/'));
    }
    return false;
  }

  Future<void> _handleTap(Bookmark b) async {
    switch (b) {
      case FileBookmark(:final path, :final subpath):
        String? heading;
        String? blockRef;
        if (subpath != null && subpath.isNotEmpty) {
          if (subpath.startsWith('#^')) {
            blockRef = subpath.substring(2);
          } else if (subpath.startsWith('#')) {
            heading = subpath.substring(1);
          }
        }
        await ref
            .read(linkNavigatorProvider)
            .open(
              from: path,
              target: path.value,
              heading: heading,
              blockRef: blockRef,
            );
      case FolderBookmark(:final path):
        ref.read(explorerSelectedProvider.notifier).select(path);
        ref.read(explorerExpandedProvider.notifier).expand(path);
        ref.read(activeLeftSidebarPanelProvider.notifier).select('explorer');
      case SearchBookmark(:final query):
        ref.read(searchControllerProvider.notifier).setQuery(query);
        ref.read(activeLeftSidebarPanelProvider.notifier).select('search');
      case GroupBookmark():
        _toggleGroup(b);
      case UnknownBookmark():
        break;
    }
  }

  Future<void> _showContextMenu({
    required BuildContext context,
    required Bookmark bookmark,
    required GroupBookmark? parentGroup,
    required int indexInParent,
    required int parentCount,
    Offset? position,
  }) async {
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(bookmarksProvider.notifier);

    final canMoveUp = indexInParent > 0;
    final canMoveDown = indexInParent < parentCount - 1;

    // Collect all existing groups for "Move to group..."
    final allBookmarks = ref.read(bookmarksProvider).value ?? const [];
    final availableGroups = <GroupBookmark>[];
    void collectGroups(List<Bookmark> list) {
      for (final item in list) {
        if (item is GroupBookmark && item != bookmark) {
          availableGroups.add(item);
          collectGroups(item.items);
        }
      }
    }

    collectGroups(allBookmarks);

    void onMoveUp() {
      notifier.move(bookmark, parentGroup, indexInParent - 1);
    }

    void onMoveDown() {
      notifier.move(bookmark, parentGroup, indexInParent + 1);
    }

    Future<void> onMoveToGroup() async {
      final selectedGroup = await showDialog<GroupBookmark?>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: Text(l10n.bookmarkMoveToGroup),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: Text(l10n.bookmarkRoot),
            ),
            for (final g in availableGroups)
              SimpleDialogOption(
                onPressed: () => Navigator.of(ctx).pop(g),
                child: Text(g.title ?? 'Group'),
              ),
          ],
        ),
      );

      final targetList = selectedGroup != null
          ? selectedGroup.items
          : allBookmarks;
      await notifier.move(bookmark, selectedGroup, targetList.length);
    }

    Future<void> onRename() async {
      final currentTitle = bookmark.title ?? bookmarkLabel(bookmark);
      final newTitle = await showBookmarkRenameDialog(context, currentTitle);
      if (newTitle != null) {
        await notifier.rename(bookmark, newTitle.isEmpty ? null : newTitle);
      }
    }

    Future<void> onRemove() async {
      await notifier.remove(bookmark);
    }

    if (position != null) {
      // Desktop context popup menu
      final action = await showMenu<String>(
        context: context,
        position: RelativeRect.fromLTRB(
          position.dx,
          position.dy,
          position.dx,
          position.dy,
        ),
        items: [
          PopupMenuItem(
            value: 'up',
            enabled: canMoveUp,
            child: Text(l10n.bookmarkMoveUp),
          ),
          PopupMenuItem(
            value: 'down',
            enabled: canMoveDown,
            child: Text(l10n.bookmarkMoveDown),
          ),
          PopupMenuItem(value: 'group', child: Text(l10n.bookmarkMoveToGroup)),
          PopupMenuItem(value: 'rename', child: Text(l10n.bookmarkRename)),
          PopupMenuItem(value: 'remove', child: Text(l10n.bookmarkRemove)),
        ],
      );

      switch (action) {
        case 'up':
          onMoveUp();
        case 'down':
          onMoveDown();
        case 'group':
          await onMoveToGroup();
        case 'rename':
          await onRename();
        case 'remove':
          await onRemove();
      }
    } else {
      // Phone bottom sheet
      await showModalBottomSheet<void>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canMoveUp)
                ListTile(
                  leading: const Icon(Icons.arrow_upward),
                  title: Text(l10n.bookmarkMoveUp),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onMoveUp();
                  },
                ),
              if (canMoveDown)
                ListTile(
                  leading: const Icon(Icons.arrow_downward),
                  title: Text(l10n.bookmarkMoveDown),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onMoveDown();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.drive_file_move_outlined),
                title: Text(l10n.bookmarkMoveToGroup),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await onMoveToGroup();
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(l10n.bookmarkRename),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await onRename();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(l10n.bookmarkRemove),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await onRemove();
                },
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildDropGap({
    required BuildContext context,
    required GroupBookmark? parentGroup,
    required int insertIndex,
  }) {
    return DragTarget<Bookmark>(
      hitTestBehavior: HitTestBehavior.translucent,
      onWillAcceptWithDetails: (details) => details.data != parentGroup,
      onAcceptWithDetails: (details) {
        ref
            .read(bookmarksProvider.notifier)
            .move(details.data, parentGroup, insertIndex);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered =
            candidateData.isNotEmpty && candidateData.first != null;
        final colorScheme = Theme.of(context).colorScheme;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: isHovered ? 6 : 4,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: isHovered ? colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      },
    );
  }

  Widget _buildRowTile({
    required BuildContext context,
    required _FlatBookmarkRow row,
    required Set<String>? indexedPaths,
    required bool isDesktop,
  }) {
    final theme = Theme.of(context);
    final b = row.bookmark;
    final isExpanded =
        b is GroupBookmark && !_collapsedGroupCtimes.contains(b.ctime);
    final label = bookmarkLabel(b);
    final icon = bookmarkIcon(b, isExpanded: isExpanded);
    final isMissing = _isTargetMissing(b, indexedPaths);

    final rowContent = Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () => _handleTap(b),
        onLongPress: () => _showContextMenu(
          context: context,
          bookmark: b,
          parentGroup: row.parentGroup,
          indexInParent: row.indexInParent,
          parentCount: row.parentCount,
        ),
        onSecondaryTapDown: (details) => _showContextMenu(
          context: context,
          bookmark: b,
          parentGroup: row.parentGroup,
          indexInParent: row.indexInParent,
          parentCount: row.parentCount,
          position: details.globalPosition,
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: 4.0 + 16.0 * row.depth,
            right: 8.0,
            top: 6.0,
            bottom: 6.0,
          ),
          child: Row(
            children: [
              if (b is GroupBookmark)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _toggleGroup(b),
                  child: Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: Icon(
                      isExpanded ? Icons.expand_more : Icons.chevron_right,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                const SizedBox(width: 22),
              const SizedBox(width: 4),
              Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    Widget wrapped = Opacity(
      opacity: isMissing ? 0.60 : 1.0,
      child: rowContent,
    );

    // If it's a group bookmark, it also accepts drops into the group
    if (isDesktop && b is GroupBookmark) {
      final inner = wrapped;
      wrapped = DragTarget<Bookmark>(
        onWillAcceptWithDetails: (details) => details.data != b,
        onAcceptWithDetails: (details) {
          ref
              .read(bookmarksProvider.notifier)
              .move(details.data, b, b.items.length);
        },
        builder: (context, candidateData, rejectedData) {
          final isHovered = candidateData.isNotEmpty;
          return Container(
            decoration: isHovered
                ? BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(
                      alpha: 0.3,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  )
                : null,
            child: inner,
          );
        },
      );
    }

    if (isDesktop) {
      return Draggable<Bookmark>(
        data: b,
        feedback: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(4),
          color: theme.colorScheme.surfaceContainerHigh,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 8),
                Text(label, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.35, child: wrapped),
        child: wrapped,
      );
    }

    return wrapped;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 840;

    final bookmarksAsync = ref.watch(bookmarksProvider);
    final indexedPathsAsync = ref.watch(indexedPathsProvider);
    final indexedPaths = indexedPathsAsync.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Toolbar
        Container(
          height: isDesktop ? 32.0 : 48.0,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Text(l10n.sidebarBookmarks, style: theme.textTheme.titleSmall),
              const Spacer(),
              IconButton(
                iconSize: 18,
                tooltip: l10n.bookmarkNewGroup,
                icon: const Icon(Icons.create_new_folder_outlined),
                onPressed: () async {
                  final title = await showBookmarkGroupDialog(context);
                  if (title != null && title.isNotEmpty) {
                    final group = GroupBookmark(
                      title: title,
                      ctime: DateTime.now().millisecondsSinceEpoch,
                      items: [],
                    );
                    await ref.read(bookmarksProvider.notifier).add(group);
                  }
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Content
        Expanded(
          child: bookmarksAsync.when(
            loading: () => const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (err, _) => Center(child: Text(err.toString())),
            data: (bookmarks) {
              if (bookmarks.isEmpty) {
                return Center(
                  child: Text(
                    l10n.bookmarkNoBookmarks,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }

              final flatRows = <_FlatBookmarkRow>[];
              _flatten(bookmarks, 0, null, flatRows);

              final totalCount = flatRows.length * 2 + 1;

              return ListView.builder(
                itemCount: totalCount,
                itemBuilder: (context, index) {
                  if (index.isEven) {
                    final gapIndex = index ~/ 2;
                    final parentGroup = gapIndex < flatRows.length
                        ? flatRows[gapIndex].parentGroup
                        : null;
                    final insertIdx = gapIndex < flatRows.length
                        ? flatRows[gapIndex].indexInParent
                        : (parentGroup?.items.length ?? bookmarks.length);

                    return _buildDropGap(
                      context: context,
                      parentGroup: parentGroup,
                      insertIndex: insertIdx,
                    );
                  }

                  final rowIndex = index ~/ 2;
                  final row = flatRows[rowIndex];
                  return _buildRowTile(
                    context: context,
                    row: row,
                    indexedPaths: indexedPaths,
                    isDesktop: isDesktop,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
