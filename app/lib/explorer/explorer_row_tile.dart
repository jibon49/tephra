// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../vault/providers.dart';
import '../workspace/open_file.dart';
import '../workspace/providers.dart';
import 'explorer_menus.dart';
import 'explorer_rows.dart';
import 'providers.dart';
import 'visible_file_types.dart';

class ExplorerRowTile extends ConsumerStatefulWidget {
  const ExplorerRowTile({
    super.key,
    required this.row,
    required this.isDesktop,
    this.isWindows,
    required this.onPerformAction,
  });

  final ExplorerRow row;
  final bool isDesktop;
  final bool? isWindows;
  final Future<void> Function(ExplorerAction action, VaultEntry entry)
  onPerformAction;

  @override
  ConsumerState<ExplorerRowTile> createState() => _ExplorerRowTileState();
}

class _ExplorerRowTileState extends ConsumerState<ExplorerRowTile> {
  late final TextEditingController _renameController;
  late final FocusNode _renameFocusNode;
  String? _renameError;
  bool _isDragHovering = false;
  Timer? _hoverExpandTimer;

  @override
  void initState() {
    super.initState();
    final entry = widget.row.entry;
    final initialName = entry.isFolder
        ? entry.path.name
        : (entry.path.isMarkdown ? entry.path.stem : entry.path.name);
    _renameController = TextEditingController(text: initialName);
    _renameFocusNode = FocusNode(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          _cancelRename();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
    );

    _renameFocusNode.addListener(_onFocusChange);

    if (ref.read(explorerRenamingProvider) == entry.path) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _renameFocusNode.requestFocus();
          _renameController.selection = TextSelection(
            baseOffset: 0,
            extentOffset: initialName.length,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _hoverExpandTimer?.cancel();
    _renameFocusNode.removeListener(_onFocusChange);
    _renameFocusNode.dispose();
    _renameController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_renameFocusNode.hasFocus) {
      final isRenaming =
          ref.read(explorerRenamingProvider) == widget.row.entry.path;
      if (isRenaming) {
        _commitRename(isBlur: true);
      }
    }
  }

  Future<void> _commitRename({bool isBlur = false}) async {
    final newName = _renameController.text.trim();
    final entry = widget.row.entry;
    final originalName = entry.isFolder
        ? entry.path.name
        : (entry.path.isMarkdown ? entry.path.stem : entry.path.name);

    if (newName == originalName) {
      ref.read(explorerRenamingProvider.notifier).stop();
      return;
    }

    final l10n = AppLocalizations.of(context);
    try {
      final service = ref.read(explorerServiceProvider);
      await service.rename(entry.path, newName, context: context);
      ref.read(explorerRenamingProvider.notifier).stop();
    } on InvalidPathException {
      setState(() {
        _renameError = l10n.explorerNameInvalid;
      });
      if (isBlur) {
        ref.read(explorerRenamingProvider.notifier).stop();
      }
    } on FileConflictException {
      setState(() {
        _renameError = l10n.explorerNameExists;
      });
      if (isBlur) {
        ref.read(explorerRenamingProvider.notifier).stop();
      }
    } catch (_) {
      if (isBlur) {
        ref.read(explorerRenamingProvider.notifier).stop();
      }
    }
  }

  void _cancelRename() {
    ref.read(explorerRenamingProvider.notifier).stop();
  }

  Future<void> _onFileTapped({bool newTab = false}) async {
    final entry = widget.row.entry;
    ref.read(explorerSelectedProvider.notifier).select(entry.path);

    final ext = entry.path.extension.toLowerCase();
    if (ext == 'md' || ext == 'canvas' || ext == 'base') {
      openFile(ref, entry.path, newTab: newTab);
    } else {
      final isWin = widget.isWindows ?? Platform.isWindows;
      if (isWin) {
        final session = ref.read(vaultSessionProvider);
        if (session != null) {
          final abs = p.join(session.rootDir, entry.path.value);
          final uri = Uri.file(abs);
          await launchUrl(uri);
        }
      } else {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.embedOpenLater)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final isDesktop = widget.isDesktop;
    final height = isDesktop ? 32.0 : 48.0;
    final theme = Theme.of(context);

    if (row.loading) {
      return SizedBox(
        height: height,
        child: Padding(
          padding: EdgeInsets.only(left: 16.0 * row.depth + 32),
          child: const Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    final entry = row.entry;
    ref.listen<VaultPath?>(explorerRenamingProvider, (prev, next) {
      if (next == entry.path && prev != entry.path) {
        final initialName = entry.isFolder
            ? entry.path.name
            : (entry.path.isMarkdown ? entry.path.stem : entry.path.name);
        _renameController.text = initialName;
        _renameController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: initialName.length,
        );
        _renameError = null;
        _renameFocusNode.requestFocus();
      }
    });

    final isRenaming = ref.watch(explorerRenamingProvider) == entry.path;
    final isSelected = ref.watch(explorerSelectedProvider) == entry.path;
    final activePath = ref.watch(activeNotePathProvider);
    final isActive = activePath == entry.path;

    Color? backgroundColor;
    if (_isDragHovering) {
      backgroundColor = theme.colorScheme.tertiaryContainer;
    } else if (isActive) {
      backgroundColor = theme.colorScheme.secondaryContainer;
    } else if (isSelected) {
      backgroundColor = theme.colorScheme.surfaceContainerHighest;
    }

    Widget content = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isRenaming
            ? null
            : () {
                if (entry.isFolder) {
                  ref
                      .read(explorerSelectedProvider.notifier)
                      .select(entry.path);
                  ref
                      .read(explorerExpandedProvider.notifier)
                      .toggle(entry.path);
                } else {
                  final isCtrl = HardwareKeyboard.instance.isControlPressed;
                  _onFileTapped(newTab: isCtrl);
                }
              },
        onSecondaryTapDown: (details) async {
          if (!isDesktop) return;
          ref.read(explorerSelectedProvider.notifier).select(entry.path);
          final action = await showExplorerDesktopMenu(
            context: context,
            position: details.globalPosition,
            entry: entry,
            isWindows: widget.isWindows,
          );
          if (action != null) {
            await widget.onPerformAction(action, entry);
          }
        },
        onLongPress: isDesktop
            ? null
            : () async {
                ref.read(explorerSelectedProvider.notifier).select(entry.path);
                final action = await showExplorerBottomSheet(
                  context: context,
                  entry: entry,
                  isWindows: widget.isWindows,
                );
                if (action != null) {
                  await widget.onPerformAction(action, entry);
                }
              },
        child: Listener(
          onPointerDown: (event) {
            if (event.buttons == kTertiaryButton && !entry.isFolder) {
              _onFileTapped(newTab: true);
            }
          },
          child: Container(
            height: height,
            color: backgroundColor,
            padding: EdgeInsets.only(left: 16.0 * row.depth + 8, right: 8),
            child: Row(
              children: [
                if (entry.isFolder)
                  SizedBox(
                    width: 24,
                    child: Icon(
                      row.expanded ? Icons.expand_more : Icons.chevron_right,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  const SizedBox(width: 24),
                Icon(
                  iconFor(entry, isOpen: row.expanded),
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: isRenaming
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 28,
                              child: TextField(
                                key: const ValueKey('explorer.renameField'),
                                controller: _renameController,
                                focusNode: _renameFocusNode,
                                autofocus: true,
                                maxLines: 1,
                                textInputAction: TextInputAction.done,
                                style: theme.textTheme.bodyMedium,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 4,
                                  ),
                                  border: OutlineInputBorder(),
                                ),
                                onSubmitted: (_) => _commitRename(),
                              ),
                            ),
                            if (_renameError != null)
                              Text(
                                _renameError!,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: theme.colorScheme.error,
                                ),
                              ),
                          ],
                        )
                      : Text(
                          displayName(entry),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: isActive
                                ? theme.colorScheme.onSecondaryContainer
                                : theme.colorScheme.onSurface,
                            fontWeight: isActive
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Desktop Drag & Drop
    if (isDesktop) {
      if (entry.isFolder) {
        final folderTile = content;
        content = DragTarget<VaultPath>(
          onWillAcceptWithDetails: (details) {
            final dragged = details.data;
            if (dragged == entry.path) return false;
            if (dragged.parent == entry.path) return false;
            if (entry.path.isWithin(dragged)) return false;
            return true;
          },
          onAcceptWithDetails: (details) async {
            setState(() {
              _isDragHovering = false;
            });
            _hoverExpandTimer?.cancel();
            final service = ref.read(explorerServiceProvider);
            try {
              await service.move(details.data, entry.path);
            } catch (_) {}
          },
          onMove: (details) {
            if (!_isDragHovering) {
              setState(() {
                _isDragHovering = true;
              });
              if (!row.expanded) {
                _hoverExpandTimer?.cancel();
                _hoverExpandTimer = Timer(
                  const Duration(milliseconds: 600),
                  () {
                    if (mounted && _isDragHovering) {
                      ref
                          .read(explorerExpandedProvider.notifier)
                          .expand(entry.path);
                    }
                  },
                );
              }
            }
          },
          onLeave: (_) {
            setState(() {
              _isDragHovering = false;
            });
            _hoverExpandTimer?.cancel();
          },
          builder: (context, candidateData, rejectedData) => folderTile,
        );
      }

      final rowWidget = content;
      content = Draggable<VaultPath>(
        data: entry.path,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(displayName(entry), style: theme.textTheme.bodyMedium),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.4, child: rowWidget),
        child: rowWidget,
      );
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _cancelRename,
      },
      child: content,
    );
  }
}
