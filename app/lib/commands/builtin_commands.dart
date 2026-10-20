// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../bookmarks/bookmark_commands.dart';
import '../core/perf/perf_command.dart';
import '../editor/folding/fold_commands.dart';
import '../editor/live_preview/editing_mode_commands.dart';
import '../editor/providers.dart';
import '../l10n/app_localizations.dart';
import '../search/copy_results.dart';
import '../search/providers.dart';
import '../search/search_screen.dart';
import '../sync_ui/sync_commands.dart';
import '../vault/note_document.dart';
import '../vault/note_tools/note_tools_commands.dart';
import '../vault/providers.dart';
import '../vault/vault_undo.dart';
import '../workspace/open_file.dart';
import '../workspace/providers.dart';
import '../workspace/workspace_models.dart';
import 'command_palette.dart';
import 'command_registry.dart';
import 'index_commands.dart';
import 'providers.dart';
import 'quick_switcher.dart';
import 'tephra_command.dart';

void registerBuiltinCommands(CommandRegistry registry) {
  registerIndexCommands(registry);
  registerBookmarkCommands(registry);
  registerEditingModeCommands(registry);
  registerFoldCommands(registry);
  registerNoteToolsCommands(registry);
  registerPerfCommand(registry);
  registerSyncCommands(registry);
  registry.register(
    TephraCommand(
      id: 'app.open-quick-switcher',
      label: (l10n) => l10n.commandAppOpenQuickSwitcher,
      icon: Icons.search,
      defaultShortcuts: const [
        SingleActivator(LogicalKeyboardKey.keyO, control: true),
      ],
      run: (ref, context) => showQuickSwitcher(context),
    ),
  );

  registry.register(
    TephraCommand(
      id: 'app.open-command-palette',
      label: (l10n) => l10n.commandAppOpenCommandPalette,
      icon: Icons.terminal,
      defaultShortcuts: const [
        SingleActivator(LogicalKeyboardKey.keyP, control: true),
      ],
      run: (ref, context) => showCommandPalette(context),
    ),
  );

  registry.register(
    TephraCommand(
      id: 'app.open-settings',
      label: (l10n) => l10n.commandAppOpenSettings,
      icon: Icons.settings_outlined,
      defaultShortcuts: const [
        SingleActivator(LogicalKeyboardKey.comma, control: true),
      ],
      run: (ref, context) => Navigator.of(context).pushNamed('/settings'),
    ),
  );

  registry.register(
    TephraCommand(
      id: 'app.open-vault',
      label: (l10n) => l10n.commandAppOpenVault,
      icon: Icons.folder_open_outlined,
      defaultShortcuts: const [],
      run: (ref, context) => ref.read(vaultSessionProvider.notifier).close(),
    ),
  );

  registry.register(
    TephraCommand(
      id: 'app.toggle-left-sidebar',
      label: (l10n) => l10n.commandAppToggleLeftSidebar,
      icon: Icons.view_sidebar_outlined,
      defaultShortcuts: const [
        SingleActivator(LogicalKeyboardKey.backslash, control: true),
      ],
      run: (ref, context) {
        if (MediaQuery.sizeOf(context).width < 840) {
          final scaffold = ref.read(phoneScaffoldKeyProvider).currentState;
          if (scaffold != null) {
            if (scaffold.isDrawerOpen) {
              scaffold.closeDrawer();
            } else {
              scaffold.openDrawer();
            }
          } else {
            ref.read(workspaceProvider.notifier).toggleLeftSidebar();
          }
        } else {
          ref.read(workspaceProvider.notifier).toggleLeftSidebar();
        }
      },
    ),
  );

  registry.register(
    TephraCommand(
      id: 'workspace.close-tab',
      label: (l10n) => l10n.commandWorkspaceCloseTab,
      icon: Icons.close,
      defaultShortcuts: const [
        SingleActivator(LogicalKeyboardKey.keyW, control: true),
      ],
      isAvailable: (ref) => ref.read(workspaceProvider).focusedTab != null,
      run: (ref, context) {
        final ws = ref.read(workspaceProvider);
        final tab = ws.focusedTab;
        if (tab != null && ws.panes.isNotEmpty) {
          final pane = ws.panes[ws.focusedPane];
          ref.read(workspaceProvider.notifier).closeTab(pane.id, tab.id);
        }
      },
    ),
  );

  registry.register(
    TephraCommand(
      id: 'workspace.next-tab',
      label: (l10n) => l10n.commandWorkspaceNextTab,
      icon: Icons.keyboard_arrow_right,
      defaultShortcuts: const [
        SingleActivator(LogicalKeyboardKey.tab, control: true),
      ],
      isAvailable: (ref) => ref.read(workspaceProvider).focusedTab != null,
      run: (ref, context) => ref.read(workspaceProvider.notifier).nextTab(),
    ),
  );

  registry.register(
    TephraCommand(
      id: 'workspace.previous-tab',
      label: (l10n) => l10n.commandWorkspacePreviousTab,
      icon: Icons.keyboard_arrow_left,
      defaultShortcuts: const [
        SingleActivator(LogicalKeyboardKey.tab, control: true, shift: true),
      ],
      isAvailable: (ref) => ref.read(workspaceProvider).focusedTab != null,
      run: (ref, context) => ref.read(workspaceProvider.notifier).previousTab(),
    ),
  );

  registry.register(
    TephraCommand(
      id: 'workspace.go-back',
      label: (l10n) => l10n.commandWorkspaceGoBack,
      icon: Icons.arrow_back,
      defaultShortcuts: const [
        SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true),
      ],
      isAvailable: (ref) =>
          ref.read(workspaceProvider).focusedTab?.canGoBack ?? false,
      run: (ref, context) => ref.read(workspaceProvider.notifier).goBack(),
    ),
  );

  registry.register(
    TephraCommand(
      id: 'workspace.go-forward',
      label: (l10n) => l10n.commandWorkspaceGoForward,
      icon: Icons.arrow_forward,
      defaultShortcuts: const [
        SingleActivator(LogicalKeyboardKey.arrowRight, alt: true),
      ],
      isAvailable: (ref) =>
          ref.read(workspaceProvider).focusedTab?.canGoForward ?? false,
      run: (ref, context) => ref.read(workspaceProvider.notifier).goForward(),
    ),
  );

  registry.register(
    TephraCommand(
      id: 'workspace.split-right',
      label: (l10n) => l10n.commandWorkspaceSplitRight,
      icon: Icons.vertical_split_outlined,
      defaultShortcuts: const [],
      isAvailable: (ref) => ref.read(workspaceProvider).focusedTab != null,
      run: (ref, context) => ref
          .read(workspaceProvider.notifier)
          .splitFocused(SplitAxis.horizontal),
    ),
  );

  registry.register(
    TephraCommand(
      id: 'workspace.split-down',
      label: (l10n) => l10n.commandWorkspaceSplitDown,
      icon: Icons.horizontal_split_outlined,
      defaultShortcuts: const [],
      isAvailable: (ref) => ref.read(workspaceProvider).focusedTab != null,
      run: (ref, context) =>
          ref.read(workspaceProvider.notifier).splitFocused(SplitAxis.vertical),
    ),
  );

  registry.register(
    TephraCommand(
      id: 'workspace.close-pane',
      label: (l10n) => l10n.commandWorkspaceClosePane,
      icon: Icons.tab_unselected,
      defaultShortcuts: const [],
      isAvailable: (ref) => ref.read(workspaceProvider).panes.length > 1,
      run: (ref, context) {
        final ws = ref.read(workspaceProvider);
        if (ws.panes.length > 1 && ws.focusedPane < ws.panes.length) {
          final pane = ws.panes[ws.focusedPane];
          ref.read(workspaceProvider.notifier).closePane(pane.id);
        }
      },
    ),
  );

  registry.register(
    TephraCommand(
      id: 'editor.toggle-reading-view',
      label: (l10n) => l10n.commandEditorToggleReadingView,
      icon: Icons.visibility_outlined,
      defaultShortcuts: const [
        SingleActivator(LogicalKeyboardKey.keyE, control: true),
      ],
      isAvailable: (ref) => ref.read(workspaceProvider).focusedTab != null,
      run: (ref, context) => ref.read(workspaceProvider.notifier).toggleMode(),
    ),
  );

  registry.register(
    TephraCommand(
      id: 'editor.trigger-autocomplete',
      label: (l10n) => l10n.commandTriggerAutocomplete,
      icon: Icons.auto_awesome,
      defaultShortcuts: const [
        SingleActivator(LogicalKeyboardKey.space, control: true),
      ],
      isAvailable: (ref) => ref.read(activeEditorProvider) != null,
      run: (ref, context) {
        final focusedTab = ref.read(workspaceProvider).focusedTab;
        if (focusedTab != null) {
          ref
              .read(autocompleteControllerProvider(focusedTab.id).notifier)
              .trigger(force: true);
        }
      },
    ),
  );

  registry.register(
    TephraCommand(
      id: 'note.create-note',
      label: (l10n) => l10n.commandNoteCreateNote,
      icon: Icons.add,
      defaultShortcuts: const [
        SingleActivator(LogicalKeyboardKey.keyN, control: true),
      ],
      run: (ref, context) async {
        final creator = ref.read(noteCreatorProvider);
        final activePath = ref.read(activeNotePathProvider);
        final path = await creator.createUntitled(contextNote: activePath);
        ref.read(focusEditorOnOpenProvider.notifier).set(true);
        openFile(ref, path, newTab: true);
      },
    ),
  );

  registry.register(
    TephraCommand(
      id: 'note.save',
      label: (l10n) => l10n.commandNoteSave,
      icon: Icons.save_outlined,
      defaultShortcuts: const [
        SingleActivator(LogicalKeyboardKey.keyS, control: true),
      ],
      isAvailable: (ref) => ref.read(activeNotePathProvider) != null,
      run: (ref, context) async {
        final path = ref.read(activeNotePathProvider);
        if (path == null) return;
        final doc = ref.read(noteDocumentProvider(path));
        final result = await doc.save();
        if (result == SaveOutcome.failed && context.mounted) {
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(l10n.saveFailed)));
        }
      },
    ),
  );

  registry.register(
    TephraCommand(
      id: 'vault.undo-last-rename',
      label: (l10n) => l10n.commandVaultUndoLastRename,
      icon: Icons.undo,
      defaultShortcuts: const [],
      isAvailable: (ref) => ref.read(vaultUndoStackProvider).isNotEmpty,
      run: (ref, context) async {
        await ref.read(vaultUndoStackProvider.notifier).undoLast();
      },
    ),
  );

  registry.register(
    TephraCommand(
      id: 'search.open',
      label: (l10n) => l10n.commandSearchOpen,
      icon: Icons.search,
      defaultShortcuts: const [
        SingleActivator(LogicalKeyboardKey.keyF, control: true, shift: true),
      ],
      run: (ref, context) {
        final activeEditor = ref.read(activeEditorProvider);
        String? prefill;
        if (activeEditor != null && !activeEditor.selection.isCollapsed) {
          final sel = activeEditor.selection;
          final text = activeEditor.text;
          if (sel.start >= 0 && sel.end <= text.length) {
            prefill = text.substring(sel.start, sel.end).trim();
          }
        }
        if (prefill != null && prefill.isNotEmpty) {
          ref.read(searchControllerProvider.notifier).setQuery(prefill);
        }

        final width = MediaQuery.sizeOf(context).width;
        if (width >= 840) {
          ref.read(activeLeftSidebarPanelProvider.notifier).select('search');
        } else {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SearchScreen(initialQuery: prefill),
            ),
          );
        }
      },
    ),
  );

  registry.register(
    TephraCommand(
      id: 'search.copy-results',
      label: (l10n) => l10n.commandSearchCopyResults,
      icon: Icons.copy,
      defaultShortcuts: const [],
      isAvailable: (ref) =>
          ref.read(searchControllerProvider).results.isNotEmpty,
      run: (ref, context) {
        final results = ref.read(searchControllerProvider).results;
        if (results.isNotEmpty) {
          copyResultsToClipboard(context, ref, results);
        }
      },
    ),
  );
}
