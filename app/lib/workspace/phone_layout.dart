// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../commands/command_palette.dart';
import '../commands/providers.dart';
import '../commands/quick_switcher.dart';
import '../editor/editor_controller.dart';
import '../editor/live_preview/editing_mode.dart';
import '../editor/mobile_toolbar.dart';
import '../editor/providers.dart';
import '../editor/save_state_indicator.dart';
import '../l10n/app_localizations.dart';
import '../sync_ui/status/sync_status_indicator.dart';
import '../vault/providers.dart';
import 'empty_workspace_view.dart';
import 'index_status.dart';
import 'providers.dart';
import 'sidebar_registry.dart';
import 'tab_content.dart';
import 'workspace_models.dart';

class PhoneLayout extends ConsumerStatefulWidget {
  const PhoneLayout({super.key});

  @override
  ConsumerState<PhoneLayout> createState() => _PhoneLayoutState();
}

class _PhoneLayoutState extends ConsumerState<PhoneLayout> {
  StreamSubscription<bool>? _focusSub;
  EditorController? _subscribedEditor;
  int _activeDrawerIndex = 0;
  int _activeEndDrawerIndex = 0;

  @override
  void dispose() {
    _focusSub?.cancel();
    super.dispose();
  }

  void _updateFocusSubscription(EditorController? editor) {
    if (_subscribedEditor == editor) return;
    _focusSub?.cancel();
    _subscribedEditor = editor;
    _focusSub = editor?.focusChanges.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final viewRegistry = ref.watch(viewRegistryProvider);
    final focusedTab = ref.watch(workspaceProvider.select((w) => w.focusedTab));
    final session = ref.watch(vaultSessionProvider);
    final scaffoldKey = ref.watch(phoneScaffoldKeyProvider);
    final activeNotePath = ref.watch(activeNotePathProvider);
    final noteDoc = activeNotePath != null
        ? ref.watch(noteDocumentProvider(activeNotePath))
        : null;

    final activeEditor = ref.watch(activeEditorProvider);
    _updateFocusSubscription(activeEditor);

    final title = focusedTab != null
        ? viewRegistry.titleFor(focusedTab.content, l10n)
        : (session?.name ?? '');

    final leftPanels = ref
        .watch(sidebarRegistryProvider.notifier)
        .phonePanelsFor(SidebarSide.left);
    final rightPanels = ref
        .watch(sidebarRegistryProvider.notifier)
        .phonePanelsFor(SidebarSide.right);

    final canGoBack = focusedTab?.canGoBack ?? false;
    final canGoForward = focusedTab?.canGoForward ?? false;

    final isSourceMode = focusedTab?.mode == ViewMode.source;
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    final hasFocus = activeEditor?.hasFocus ?? false;
    final showMobileToolbar =
        isSourceMode && activeEditor != null && (insets > 0 || hasFocus);

    return PopScope(
      canPop: !canGoBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          ref.read(workspaceProvider.notifier).goBack();
        }
      },
      child: Scaffold(
        key: scaffoldKey,
        appBar: AppBar(
          bottom: const PhoneIndexProgressBar(),
          leading: Builder(
            builder: (ctx) => IconButton(
              key: const Key('phone.menu'),
              icon: const Icon(Icons.menu),
              tooltip: l10n.phoneMenu,
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
          title: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title),
              if (noteDoc != null) SaveStateIndicator(doc: noteDoc),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: l10n.workspaceBack,
              onPressed: canGoBack
                  ? () => ref.read(workspaceProvider.notifier).goBack()
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward),
              tooltip: l10n.workspaceForward,
              onPressed: canGoForward
                  ? () => ref.read(workspaceProvider.notifier).goForward()
                  : null,
            ),
            IconButton(
              icon: Icon(
                focusedTab?.mode == ViewMode.reading
                    ? Icons.edit_outlined
                    : Icons.visibility_outlined,
              ),
              tooltip: l10n.commandToggleMode,
              onPressed: () {
                ref.read(workspaceProvider.notifier).toggleMode();
              },
            ),
            const SyncStatusIndicator(compact: true),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                switch (value) {
                  case 'toggle-editing-mode':
                    ref.read(workspaceProvider.notifier).toggleEditingMode();
                  case 'palette':
                    showCommandPalette(context);
                  case 'switcher':
                    showQuickSwitcher(context);
                  case 'settings':
                    Navigator.of(context).pushNamed('/settings');
                }
              },
              itemBuilder: (context) {
                final isNote = focusedTab?.content is FileTabContent;
                final fileContent = focusedTab?.content as FileTabContent?;
                final targetModeLabel =
                    fileContent?.editingMode == EditingMode.livePreview
                    ? l10n.editingModeSource
                    : l10n.editingModeLivePreview;
                return [
                  if (isNote)
                    PopupMenuItem(
                      value: 'toggle-editing-mode',
                      child: Text(targetModeLabel),
                    ),
                  PopupMenuItem(
                    value: 'palette',
                    child: Text(l10n.commandAppOpenCommandPalette),
                  ),
                  PopupMenuItem(
                    value: 'switcher',
                    child: Text(l10n.commandAppOpenQuickSwitcher),
                  ),
                  PopupMenuItem(
                    value: 'settings',
                    child: Text(l10n.commandAppOpenSettings),
                  ),
                ];
              },
            ),
          ],
        ),
        drawer: Drawer(
          child: leftPanels.isNotEmpty
              ? SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            Text(
                              session?.name ?? 'Tephra',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const Spacer(),
                            for (var i = 0; i < leftPanels.length; i++)
                              IconButton(
                                iconSize: 20,
                                icon: Icon(leftPanels[i].icon),
                                tooltip: leftPanels[i].label(l10n),
                                color:
                                    i ==
                                        (_activeDrawerIndex < leftPanels.length
                                            ? _activeDrawerIndex
                                            : 0)
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                onPressed: () =>
                                    setState(() => _activeDrawerIndex = i),
                              ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child:
                            leftPanels[_activeDrawerIndex < leftPanels.length
                                    ? _activeDrawerIndex
                                    : 0]
                                .builder(context, ref),
                      ),
                    ],
                  ),
                )
              : Center(child: Text(l10n.sidebarExplorer)),
        ),
        endDrawer: rightPanels.isNotEmpty
            ? Drawer(
                child: SafeArea(
                  child: Column(
                    children: [
                      if (rightPanels.length > 1) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              for (var i = 0; i < rightPanels.length; i++)
                                IconButton(
                                  iconSize: 20,
                                  icon: Icon(rightPanels[i].icon),
                                  tooltip: rightPanels[i].label(l10n),
                                  color:
                                      i ==
                                          (_activeEndDrawerIndex <
                                                  rightPanels.length
                                              ? _activeEndDrawerIndex
                                              : 0)
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                  onPressed: () =>
                                      setState(() => _activeEndDrawerIndex = i),
                                ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                      ],
                      Expanded(
                        child:
                            rightPanels[_activeEndDrawerIndex <
                                        rightPanels.length
                                    ? _activeEndDrawerIndex
                                    : 0]
                                .builder(context, ref),
                      ),
                    ],
                  ),
                ),
              )
            : null,
        body: focusedTab == null
            ? const EmptyWorkspaceView()
            : Column(
                children: [
                  Expanded(
                    child: KeyedSubtree(
                      key: ValueKey(focusedTab.id),
                      child: viewRegistry.build(
                        context,
                        ref,
                        focusedTab.content,
                        focusedTab.id,
                      ),
                    ),
                  ),
                  if (showMobileToolbar) const MobileToolbar(),
                ],
              ),
      ),
    );
  }
}
