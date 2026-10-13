// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';

import '../l10n/app_localizations.dart';
import 'explorer_state.dart';

/// Opens the [MoveToDialog] allowing the user to select a target folder for [sourcePath].
Future<VaultPath?> showMoveToDialog(
  BuildContext context, {
  required VaultPath sourcePath,
}) {
  return showDialog<VaultPath>(
    context: context,
    builder: (context) => MoveToDialog(sourcePath: sourcePath),
  );
}

/// A dialog showing the vault folder tree for selecting a move destination.
class MoveToDialog extends ConsumerStatefulWidget {
  const MoveToDialog({super.key, required this.sourcePath});

  final VaultPath sourcePath;

  @override
  ConsumerState<MoveToDialog> createState() => _MoveToDialogState();
}

class _MoveToDialogState extends ConsumerState<MoveToDialog> {
  final Set<VaultPath> _expanded = {VaultPath.root};
  VaultPath? _selectedFolder;

  bool _isInvalidTarget(VaultPath folder) {
    if (folder == widget.sourcePath) return true;
    if (folder == widget.sourcePath.parent) return true;
    if (folder.isWithin(widget.sourcePath)) return true;
    return false;
  }

  void _toggleExpand(VaultPath path) {
    setState(() {
      if (_expanded.contains(path)) {
        _expanded.remove(path);
      } else {
        _expanded.add(path);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.explorerMoveTo,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildFolderTile(path: VaultPath.root, name: '/', depth: 0),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.commonCancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed:
                        _selectedFolder != null &&
                            !_isInvalidTarget(_selectedFolder!)
                        ? () => Navigator.of(context).pop(_selectedFolder)
                        : null,
                    child: Text(l10n.explorerMoveHere),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderTile({
    required VaultPath path,
    required String name,
    required int depth,
  }) {
    final theme = Theme.of(context);
    final isInvalid = _isInvalidTarget(path);
    final isSelected = _selectedFolder == path;
    final isExpanded = _expanded.contains(path);

    final childrenAsync = ref.watch(explorerChildrenProvider(path));
    final folderChildren = (childrenAsync.value ?? const [])
        .where((e) => e.isFolder)
        .toList();
    final hasFolders = folderChildren.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: isInvalid
              ? null
              : () {
                  setState(() {
                    _selectedFolder = path;
                  });
                },
          child: Container(
            height: 48,
            padding: EdgeInsets.only(left: 16.0 * depth + 8, right: 16),
            color: isSelected
                ? theme.colorScheme.secondaryContainer
                : Colors.transparent,
            child: Row(
              children: [
                if (hasFolders)
                  IconButton(
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      isExpanded ? Icons.expand_more : Icons.chevron_right,
                    ),
                    onPressed: () => _toggleExpand(path),
                  )
                else
                  const SizedBox(width: 32),
                Icon(
                  isExpanded
                      ? Icons.folder_open_outlined
                      : Icons.folder_outlined,
                  size: 20,
                  color: isInvalid
                      ? theme.disabledColor
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isInvalid
                          ? theme.disabledColor
                          : (isSelected
                                ? theme.colorScheme.onSecondaryContainer
                                : theme.colorScheme.onSurface),
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded && hasFolders)
          for (final child in folderChildren)
            _buildFolderTile(
              path: child.path,
              name: child.path.name,
              depth: depth + 1,
            ),
      ],
    );
  }
}
