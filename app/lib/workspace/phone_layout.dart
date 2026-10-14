// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../commands/command_palette.dart';
import '../commands/providers.dart';
import '../commands/quick_switcher.dart';
import '../editor/editor_controller.dart';
import '../editor/mobile_toolbar.dart';
import '../editor/providers.dart';
import '../editor/save_state_indicator.dart';
import '../l10n/app_localizations.dart';
import '../vault/providers.dart';
import 'empty_workspace_view.dart';
import 'providers.dart';
import 'sidebar_registry.dart';
import 'workspace_models.dart';

class PhoneLayout extends ConsumerStatefulWidget {
  const PhoneLayout({super.key});

  @override
  ConsumerState<PhoneLayout> createState() => _PhoneLayoutState();
}

class _PhoneLayoutState extends ConsumerState<PhoneLayout> {
  StreamSubscription<bool>? _focusSub;
  EditorController? _subscribedEditor;

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
        .panelsFor(SidebarSide.left);
    final rightPanels = ref
        .watch(sidebarRegistryProvider.notifier)
        .panelsFor(SidebarSide.right);

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
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                switch (value) {
                  case 'palette':
                    showCommandPalette(context);
                  case 'switcher':
                    showQuickSwitcher(context);
                  case 'settings':
                    Navigator.of(context).pushNamed('/settings');
                }
              },
              itemBuilder: (context) => [
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
              ],
            ),
          ],
        ),
        drawer: Drawer(
          child: leftPanels.isNotEmpty
              ? Column(
                  children: [
                    DrawerHeader(
                      child: Center(
                        child: Text(
                          session?.name ?? 'Tephra',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ),
                    Expanded(child: leftPanels.first.builder(context, ref)),
                  ],
                )
              : Center(child: Text(l10n.sidebarExplorer)),
        ),
        endDrawer: rightPanels.isNotEmpty
            ? Drawer(child: rightPanels.first.builder(context, ref))
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
