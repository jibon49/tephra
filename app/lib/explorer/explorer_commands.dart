// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tephra_core/tephra_core.dart';

import '../commands/command_registry.dart';
import '../commands/providers.dart';
import '../commands/tephra_command.dart';
import '../vault/providers.dart';
import '../workspace/providers.dart';
import 'explorer_menus.dart';
import 'providers.dart';

/// Registers file explorer commands into [registry].
void registerExplorerCommands(CommandRegistry registry) {
  registry.register(
    TephraCommand(
      id: 'note.create-folder',
      label: (l10n) => l10n.commandNoteCreateFolder,
      icon: Icons.create_new_folder_outlined,
      defaultShortcuts: const [],
      run: (ref, context) async {
        final active = ref.read(activeNotePathProvider);
        final folder = active?.parent ?? VaultPath.root;
        await ref.read(explorerServiceProvider).createFolder(folder);
      },
    ),
  );

  registry.register(
    TephraCommand(
      id: 'note.rename-note',
      label: (l10n) => l10n.commandNoteRenameNote,
      icon: Icons.drive_file_rename_outline,
      defaultShortcuts: const [SingleActivator(LogicalKeyboardKey.f2)],
      isAvailable: (ref) => ref.read(activeNotePathProvider) != null,
      run: (ref, context) async {
        final active = ref.read(activeNotePathProvider);
        if (active == null) return;

        final isDesktop = MediaQuery.of(context).size.width >= 840;
        if (isDesktop) {
          ref.read(workspaceProvider.notifier).setLeftSidebarVisible(true);
        } else {
          ref.read(phoneScaffoldKeyProvider).currentState?.openDrawer();
        }

        ref.read(explorerExpandedProvider.notifier).expandAncestors(active);
        ref.read(explorerSelectedProvider.notifier).select(active);
        ref.read(explorerRenamingProvider.notifier).start(active);
      },
    ),
  );

  registry.register(
    TephraCommand(
      id: 'note.delete-note',
      label: (l10n) => l10n.commandNoteDeleteNote,
      icon: Icons.delete_outline,
      defaultShortcuts: const [],
      isAvailable: (ref) => ref.read(activeNotePathProvider) != null,
      run: (ref, context) async {
        final active = ref.read(activeNotePathProvider);
        if (active == null) return;

        final fs = ref.read(vaultFsProvider);
        final entry = await fs.stat(active);
        if (entry == null) return;

        if (!context.mounted) return;
        final confirmed = await showDeleteDialog(
          context: context,
          ref: ref,
          entry: entry,
        );
        if (confirmed) {
          await ref.read(explorerServiceProvider).delete(active);
        }
      },
    ),
  );

  registry.register(
    TephraCommand(
      id: 'note.duplicate-note',
      label: (l10n) => l10n.commandNoteDuplicateNote,
      icon: Icons.copy,
      defaultShortcuts: const [],
      isAvailable: (ref) => ref.read(activeNotePathProvider) != null,
      run: (ref, context) async {
        final active = ref.read(activeNotePathProvider);
        if (active == null) return;
        await ref.read(explorerServiceProvider).duplicate(active);
      },
    ),
  );

  registry.register(
    TephraCommand(
      id: 'note.reveal-in-explorer',
      label: (l10n) => l10n.commandNoteRevealInExplorer,
      icon: Icons.folder_open,
      defaultShortcuts: const [],
      isAvailable: (ref) =>
          (!kIsWeb && Platform.isWindows) &&
          ref.read(activeNotePathProvider) != null,
      run: (ref, context) async {
        final active = ref.read(activeNotePathProvider);
        if (active == null) return;
        await ref.read(explorerServiceProvider).reveal(active);
      },
    ),
  );

  registry.register(
    TephraCommand(
      id: 'explorer.collapse-all',
      label: (l10n) => l10n.commandExplorerCollapseAll,
      icon: Icons.unfold_less,
      defaultShortcuts: const [],
      run: (ref, context) {
        ref.read(explorerExpandedProvider.notifier).collapseAll();
      },
    ),
  );

  registry.register(
    TephraCommand(
      id: 'explorer.reveal-active-file',
      label: (l10n) => l10n.commandExplorerRevealActiveFile,
      icon: Icons.my_location,
      defaultShortcuts: const [],
      isAvailable: (ref) => ref.read(activeNotePathProvider) != null,
      run: (ref, context) {
        final active = ref.read(activeNotePathProvider);
        if (active == null) return;
        ref.read(explorerExpandedProvider.notifier).expandAncestors(active);
        ref.read(explorerSelectedProvider.notifier).select(active);
      },
    ),
  );
}
