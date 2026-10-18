// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../l10n/app_localizations.dart';
import '../settings/providers.dart';
import '../settings/vault_settings.dart';
import '../vault/providers.dart';
import '../workspace/open_file.dart';
import 'explorer_menus.dart';
import 'explorer_row_tile.dart';
import 'explorer_rows.dart';
import 'move_to_dialog.dart';
import 'providers.dart';

class ExplorerPane extends ConsumerStatefulWidget {
  const ExplorerPane({super.key, this.isWindows});

  final bool? isWindows;

  @override
  ConsumerState<ExplorerPane> createState() => _ExplorerPaneState();
}

class _ExplorerPaneState extends ConsumerState<ExplorerPane> {
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _scrollController.dispose();
    _renameFocusNodeDispose();
    super.dispose();
  }

  void _renameFocusNodeDispose() {
    _focusNode.dispose();
  }

  VaultPath _resolveTargetFolder() {
    final selected = ref.read(explorerSelectedProvider);
    if (selected == null) return VaultPath.root;
    final rows = ref.read(explorerRowsProvider).value ?? const [];
    final match = rows.where((r) => r.entry.path == selected).firstOrNull;
    if (match != null && match.entry.isFolder) {
      return selected;
    }
    return selected.parent ?? VaultPath.root;
  }

  Future<void> _handleAction(ExplorerAction action, VaultEntry entry) async {
    final service = ref.read(explorerServiceProvider);
    switch (action) {
      case ExplorerAction.openInNewTab:
        openFile(ref, entry.path, newTab: true);
      case ExplorerAction.newNote:
        final folder = entry.isFolder
            ? entry.path
            : (entry.path.parent ?? VaultPath.root);
        await service.createNote(folder);
      case ExplorerAction.newFolder:
        final folder = entry.isFolder
            ? entry.path
            : (entry.path.parent ?? VaultPath.root);
        await service.createFolder(folder);
      case ExplorerAction.rename:
        ref.read(explorerRenamingProvider.notifier).start(entry.path);
      case ExplorerAction.duplicate:
        await service.duplicate(entry.path);
      case ExplorerAction.moveTo:
        final target = await showMoveToDialog(context, sourcePath: entry.path);
        if (target != null && mounted) {
          try {
            await service.move(entry.path, target, context: context);
          } on FileConflictException {
            if (!mounted) return;
            final l10n = AppLocalizations.of(context);
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(l10n.explorerNameExists)));
          }
        }
      case ExplorerAction.reveal:
        await service.reveal(entry.path);
      case ExplorerAction.delete:
        final confirmed = await showDeleteDialog(
          context: context,
          ref: ref,
          entry: entry,
        );
        if (confirmed) {
          await service.delete(entry.path);
        }
    }
  }

  void _onKey(KeyEvent event, List<ExplorerRow> rows) {
    if (event is! KeyDownEvent) return;
    if (rows.isEmpty) return;

    final selected = ref.read(explorerSelectedProvider);
    var currentIndex = -1;
    if (selected != null) {
      currentIndex = rows.indexWhere((r) => r.entry.path == selected);
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      final nextIndex = (currentIndex + 1).clamp(0, rows.length - 1);
      final target = rows[nextIndex].entry.path;
      ref.read(explorerSelectedProvider.notifier).select(target);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      final prevIndex = (currentIndex - 1).clamp(0, rows.length - 1);
      final target = rows[prevIndex].entry.path;
      ref.read(explorerSelectedProvider.notifier).select(target);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (currentIndex >= 0) {
        final row = rows[currentIndex];
        if (row.entry.isFolder && !row.expanded) {
          ref.read(explorerExpandedProvider.notifier).expand(row.entry.path);
        }
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (currentIndex >= 0) {
        final row = rows[currentIndex];
        if (row.entry.isFolder && row.expanded) {
          ref.read(explorerExpandedProvider.notifier).collapse(row.entry.path);
        } else {
          final parent = row.entry.path.parent;
          if (parent != null && !parent.isRoot) {
            ref.read(explorerSelectedProvider.notifier).select(parent);
          }
        }
      }
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (currentIndex >= 0) {
        final row = rows[currentIndex];
        if (row.entry.isFolder) {
          ref.read(explorerExpandedProvider.notifier).toggle(row.entry.path);
        } else {
          openFile(ref, row.entry.path);
        }
      }
    } else if (event.logicalKey == LogicalKeyboardKey.f2) {
      if (currentIndex >= 0) {
        ref
            .read(explorerRenamingProvider.notifier)
            .start(rows[currentIndex].entry.path);
      }
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      ref.read(explorerRenamingProvider.notifier).stop();
    } else if (event.logicalKey == LogicalKeyboardKey.delete) {
      if (currentIndex >= 0) {
        _handleAction(ExplorerAction.delete, rows[currentIndex].entry);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 840;

    final rowsAsync = ref.watch(explorerRowsProvider);
    final rows = rowsAsync.value ?? const [];

    return LayoutBuilder(
      builder: (context, constraints) {
        return Material(
          color: Colors.transparent,
          child: Focus(
            focusNode: _focusNode,
            autofocus: true,
            onKeyEvent: (node, event) {
              _onKey(event, rows);
              return KeyEventResult.ignored;
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildToolbar(context, isDesktop),
                const Divider(height: 1),
                Expanded(
                  child: DragTarget<VaultPath>(
                    onWillAcceptWithDetails: (details) =>
                        isDesktop && details.data.parent != VaultPath.root,
                    onAcceptWithDetails: (details) async {
                      final service = ref.read(explorerServiceProvider);
                      try {
                        await service.move(
                          details.data,
                          VaultPath.root,
                          context: context,
                        );
                      } catch (_) {}
                    },
                    builder: (context, candidateData, rejectedData) {
                      return GestureDetector(
                        onSecondaryTapDown: (details) async {
                          if (!isDesktop) return;
                          final action = await showExplorerEmptyDesktopMenu(
                            context: context,
                            position: details.globalPosition,
                          );
                          if (action == ExplorerAction.newNote) {
                            await ref
                                .read(explorerServiceProvider)
                                .createNote(VaultPath.root);
                          } else if (action == ExplorerAction.newFolder) {
                            await ref
                                .read(explorerServiceProvider)
                                .createFolder(VaultPath.root);
                          }
                        },
                        child: rowsAsync.when(
                          loading: () => Column(
                            children: [
                              const LinearProgressIndicator(minHeight: 2),
                              if (rows.isNotEmpty)
                                Expanded(child: _buildList(rows, isDesktop)),
                            ],
                          ),
                          error: (err, _) => Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(l10n.explorerNotFound),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () =>
                                      ref.invalidate(explorerRowsProvider),
                                  child: Text(l10n.commonOk),
                                ),
                              ],
                            ),
                          ),
                          data: (rowList) {
                            if (rowList.isEmpty) {
                              return Center(
                                child: Text(
                                  l10n.explorerEmpty,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              );
                            }
                            return _buildList(rowList, isDesktop);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildList(List<ExplorerRow> rows, bool isDesktop) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        return ExplorerRowTile(
          key: ValueKey('row:${row.entry.path.value}'),
          row: row,
          isDesktop: isDesktop,
          isWindows: widget.isWindows,
          onPerformAction: _handleAction,
        );
      },
    );
  }

  Widget _buildToolbar(BuildContext context, bool isDesktop) {
    final l10n = AppLocalizations.of(context);
    final buttonSize = isDesktop ? 32.0 : 48.0;
    final iconSize = isDesktop ? 18.0 : 22.0;
    final currentSort = ref.watch(
      vaultSettingsProvider.select((s) => s.explorerSortEnum),
    );

    return Container(
      key: const ValueKey('explorer.toolbar'),
      height: buttonSize,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          SizedBox(
            width: buttonSize,
            height: buttonSize,
            child: IconButton(
              key: const ValueKey('explorer.newNote'),
              iconSize: iconSize,
              padding: EdgeInsets.zero,
              tooltip: l10n.explorerNewNote,
              icon: const Icon(Icons.note_add_outlined),
              onPressed: () async {
                final folder = _resolveTargetFolder();
                await ref.read(explorerServiceProvider).createNote(folder);
              },
            ),
          ),
          SizedBox(
            width: buttonSize,
            height: buttonSize,
            child: IconButton(
              key: const ValueKey('explorer.newFolder'),
              iconSize: iconSize,
              padding: EdgeInsets.zero,
              tooltip: l10n.explorerNewFolder,
              icon: const Icon(Icons.create_new_folder_outlined),
              onPressed: () async {
                final folder = _resolveTargetFolder();
                await ref.read(explorerServiceProvider).createFolder(folder);
              },
            ),
          ),
          SizedBox(
            width: buttonSize,
            height: buttonSize,
            child: PopupMenuButton<ExplorerSort>(
              key: const ValueKey('explorer.sort'),
              iconSize: iconSize,
              padding: EdgeInsets.zero,
              tooltip: l10n.explorerSort,
              icon: const Icon(Icons.sort),
              initialValue: currentSort,
              onSelected: (sort) {
                ref
                    .read(vaultSettingsProvider.notifier)
                    .update((s) => s.copyWith(explorerSort: sort.name));
              },
              itemBuilder: (context) => [
                _buildSortItem(
                  ExplorerSort.nameAsc,
                  l10n.explorerSortNameAsc,
                  currentSort,
                ),
                _buildSortItem(
                  ExplorerSort.nameDesc,
                  l10n.explorerSortNameDesc,
                  currentSort,
                ),
                _buildSortItem(
                  ExplorerSort.modifiedNew,
                  l10n.explorerSortModifiedNew,
                  currentSort,
                ),
                _buildSortItem(
                  ExplorerSort.modifiedOld,
                  l10n.explorerSortModifiedOld,
                  currentSort,
                ),
                _buildSortItem(
                  ExplorerSort.createdNew,
                  l10n.explorerSortCreatedNew,
                  currentSort,
                ),
                _buildSortItem(
                  ExplorerSort.createdOld,
                  l10n.explorerSortCreatedOld,
                  currentSort,
                ),
              ],
            ),
          ),
          SizedBox(
            width: buttonSize,
            height: buttonSize,
            child: IconButton(
              key: const ValueKey('explorer.collapseAll'),
              iconSize: iconSize,
              padding: EdgeInsets.zero,
              tooltip: l10n.explorerCollapseAll,
              icon: const Icon(Icons.unfold_less),
              onPressed: () {
                ref.read(explorerExpandedProvider.notifier).collapseAll();
              },
            ),
          ),
          SizedBox(
            width: buttonSize,
            height: buttonSize,
            child: IconButton(
              key: const ValueKey('explorer.openVault'),
              iconSize: iconSize,
              padding: EdgeInsets.zero,
              tooltip: l10n.commandAppOpenVault,
              icon: const Icon(Icons.folder_shared_outlined),
              onPressed: () {
                ref.read(vaultSessionProvider.notifier).close();
              },
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<ExplorerSort> _buildSortItem(
    ExplorerSort sort,
    String label,
    ExplorerSort current,
  ) {
    return PopupMenuItem(
      value: sort,
      child: Row(
        children: [
          if (sort == current)
            const Icon(Icons.check, size: 18)
          else
            const SizedBox(width: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}
