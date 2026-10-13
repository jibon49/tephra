// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../l10n/app_localizations.dart';
import '../settings/providers.dart';
import '../vault/providers.dart';

enum ExplorerAction {
  openInNewTab,
  newNote,
  newFolder,
  rename,
  duplicate,
  moveTo,
  reveal,
  delete,
}

/// Shows context menu for [entry] at [position] on desktop, or returns the action.
Future<ExplorerAction?> showExplorerDesktopMenu({
  required BuildContext context,
  required Offset position,
  required VaultEntry entry,
  bool? isWindows,
}) async {
  final l10n = AppLocalizations.of(context);
  final windows = isWindows ?? Platform.isWindows;
  final items = <PopupMenuEntry<ExplorerAction>>[];

  final isNote = !entry.isFolder && entry.path.extension.toLowerCase() == 'md';

  if (isNote) {
    items.add(
      PopupMenuItem(
        value: ExplorerAction.openInNewTab,
        child: Text(l10n.explorerOpenInNewTab),
      ),
    );
    items.add(
      PopupMenuItem(
        value: ExplorerAction.newNote,
        child: Text(l10n.explorerNewNote),
      ),
    );
    items.add(
      PopupMenuItem(
        value: ExplorerAction.newFolder,
        child: Text(l10n.explorerNewFolder),
      ),
    );
    items.add(
      PopupMenuItem(
        value: ExplorerAction.rename,
        child: Text(l10n.explorerRename),
      ),
    );
    items.add(
      PopupMenuItem(
        value: ExplorerAction.duplicate,
        child: Text(l10n.explorerDuplicate),
      ),
    );
    items.add(
      PopupMenuItem(
        value: ExplorerAction.moveTo,
        child: Text(l10n.explorerMoveTo),
      ),
    );
    if (windows) {
      items.add(
        PopupMenuItem(
          value: ExplorerAction.reveal,
          child: Text(l10n.explorerReveal),
        ),
      );
    }
    items.add(
      PopupMenuItem(
        value: ExplorerAction.delete,
        child: Text(l10n.explorerDelete),
      ),
    );
  } else if (entry.isFolder) {
    items.add(
      PopupMenuItem(
        value: ExplorerAction.newNote,
        child: Text(l10n.explorerNewNote),
      ),
    );
    items.add(
      PopupMenuItem(
        value: ExplorerAction.newFolder,
        child: Text(l10n.explorerNewFolder),
      ),
    );
    items.add(
      PopupMenuItem(
        value: ExplorerAction.rename,
        child: Text(l10n.explorerRename),
      ),
    );
    items.add(
      PopupMenuItem(
        value: ExplorerAction.moveTo,
        child: Text(l10n.explorerMoveTo),
      ),
    );
    if (windows) {
      items.add(
        PopupMenuItem(
          value: ExplorerAction.reveal,
          child: Text(l10n.explorerReveal),
        ),
      );
    }
    items.add(
      PopupMenuItem(
        value: ExplorerAction.delete,
        child: Text(l10n.explorerDelete),
      ),
    );
  } else {
    items.add(
      PopupMenuItem(
        value: ExplorerAction.rename,
        child: Text(l10n.explorerRename),
      ),
    );
    items.add(
      PopupMenuItem(
        value: ExplorerAction.moveTo,
        child: Text(l10n.explorerMoveTo),
      ),
    );
    if (windows) {
      items.add(
        PopupMenuItem(
          value: ExplorerAction.reveal,
          child: Text(l10n.explorerReveal),
        ),
      );
    }
    items.add(
      PopupMenuItem(
        value: ExplorerAction.delete,
        child: Text(l10n.explorerDelete),
      ),
    );
  }

  return showMenu<ExplorerAction>(
    context: context,
    position: RelativeRect.fromLTRB(
      position.dx,
      position.dy,
      position.dx + 1,
      position.dy + 1,
    ),
    items: items,
  );
}

/// Shows empty area desktop context menu.
Future<ExplorerAction?> showExplorerEmptyDesktopMenu({
  required BuildContext context,
  required Offset position,
}) async {
  final l10n = AppLocalizations.of(context);
  return showMenu<ExplorerAction>(
    context: context,
    position: RelativeRect.fromLTRB(
      position.dx,
      position.dy,
      position.dx + 1,
      position.dy + 1,
    ),
    items: [
      PopupMenuItem(
        value: ExplorerAction.newNote,
        child: Text(l10n.explorerNewNote),
      ),
      PopupMenuItem(
        value: ExplorerAction.newFolder,
        child: Text(l10n.explorerNewFolder),
      ),
    ],
  );
}

/// Shows phone bottom sheet for [entry].
Future<ExplorerAction?> showExplorerBottomSheet({
  required BuildContext context,
  required VaultEntry entry,
  bool? isWindows,
}) async {
  final l10n = AppLocalizations.of(context);
  final windows = isWindows ?? Platform.isWindows;
  final isNote = !entry.isFolder && entry.path.extension.toLowerCase() == 'md';

  return showModalBottomSheet<ExplorerAction>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      final tiles = <Widget>[];

      void addTile(ExplorerAction action, String text, IconData icon) {
        tiles.add(
          ListTile(
            dense: false,
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            leading: Icon(icon),
            title: Text(text),
            onTap: () => Navigator.of(context).pop(action),
          ),
        );
      }

      if (isNote) {
        addTile(
          ExplorerAction.openInNewTab,
          l10n.explorerOpenInNewTab,
          Icons.tab,
        );
        addTile(
          ExplorerAction.newNote,
          l10n.explorerNewNote,
          Icons.note_add_outlined,
        );
        addTile(
          ExplorerAction.newFolder,
          l10n.explorerNewFolder,
          Icons.create_new_folder_outlined,
        );
        addTile(
          ExplorerAction.rename,
          l10n.explorerRename,
          Icons.drive_file_rename_outline,
        );
        addTile(ExplorerAction.duplicate, l10n.explorerDuplicate, Icons.copy);
        addTile(
          ExplorerAction.moveTo,
          l10n.explorerMoveTo,
          Icons.drive_file_move_outlined,
        );
        if (windows) {
          addTile(
            ExplorerAction.reveal,
            l10n.explorerReveal,
            Icons.folder_open,
          );
        }
        addTile(
          ExplorerAction.delete,
          l10n.explorerDelete,
          Icons.delete_outline,
        );
      } else if (entry.isFolder) {
        addTile(
          ExplorerAction.newNote,
          l10n.explorerNewNote,
          Icons.note_add_outlined,
        );
        addTile(
          ExplorerAction.newFolder,
          l10n.explorerNewFolder,
          Icons.create_new_folder_outlined,
        );
        addTile(
          ExplorerAction.rename,
          l10n.explorerRename,
          Icons.drive_file_rename_outline,
        );
        addTile(
          ExplorerAction.moveTo,
          l10n.explorerMoveTo,
          Icons.drive_file_move_outlined,
        );
        if (windows) {
          addTile(
            ExplorerAction.reveal,
            l10n.explorerReveal,
            Icons.folder_open,
          );
        }
        addTile(
          ExplorerAction.delete,
          l10n.explorerDelete,
          Icons.delete_outline,
        );
      } else {
        addTile(
          ExplorerAction.rename,
          l10n.explorerRename,
          Icons.drive_file_rename_outline,
        );
        addTile(
          ExplorerAction.moveTo,
          l10n.explorerMoveTo,
          Icons.drive_file_move_outlined,
        );
        if (windows) {
          addTile(
            ExplorerAction.reveal,
            l10n.explorerReveal,
            Icons.folder_open,
          );
        }
        addTile(
          ExplorerAction.delete,
          l10n.explorerDelete,
          Icons.delete_outline,
        );
      }

      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: tiles),
        ),
      );
    },
  );
}

/// Shows the confirmation dialog for deleting [entry].
Future<bool> showDeleteDialog({
  required BuildContext context,
  required WidgetRef ref,
  required VaultEntry entry,
}) async {
  final l10n = AppLocalizations.of(context);
  final settings = ref.read(vaultSettingsProvider);
  final fs = ref.read(vaultFsProvider);
  final store = ref.read(noteDocumentStoreProvider);

  final String bodyText;
  switch (settings.trashModeEnum) {
    case TrashMode.system:
      bodyText = l10n.explorerDeleteBodySystem;
    case TrashMode.vaultTrash:
      bodyText = l10n.explorerDeleteBodyVault;
    case TrashMode.permanent:
      bodyText = l10n.explorerDeleteBodyPermanent;
  }

  int? folderCount;
  if (entry.isFolder) {
    final list = await fs.list(folder: entry.path, recursive: true);
    folderCount = list.where((e) => !e.isFolder).length;
  }

  bool hasDirtyNotes = false;
  for (final doc in store.open) {
    if (doc.isDirty) {
      if (doc.path == entry.path || doc.path.isWithin(entry.path)) {
        hasDirtyNotes = true;
        break;
      }
    }
  }

  if (!context.mounted) return false;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      return AlertDialog(
        title: Text(l10n.explorerDeleteTitle(entry.path.name)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(bodyText),
            if (folderCount != null && folderCount > 0) ...[
              const SizedBox(height: 8),
              Text(l10n.explorerDeleteFolderExtra(folderCount)),
            ],
            if (hasDirtyNotes) ...[
              const SizedBox(height: 8),
              Text(
                l10n.explorerDeleteUnsaved,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      );
    },
  );

  return confirmed ?? false;
}
