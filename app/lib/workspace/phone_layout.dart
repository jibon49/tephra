// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../commands/command_palette.dart';
import '../commands/providers.dart';
import '../commands/quick_switcher.dart';
import '../editor/save_state_indicator.dart';
import '../l10n/app_localizations.dart';
import '../vault/providers.dart';
import 'empty_workspace_view.dart';
import 'providers.dart';
import 'sidebar_registry.dart';
import 'workspace_models.dart';

class PhoneLayout extends ConsumerWidget {
  const PhoneLayout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final viewRegistry = ref.watch(viewRegistryProvider);
    final focusedTab = ref.watch(workspaceProvider.select((w) => w.focusedTab));
    final session = ref.watch(vaultSessionProvider);
    final scaffoldKey = ref.watch(phoneScaffoldKeyProvider);
    final activeNotePath = ref.watch(activeNotePathProvider);
    final noteDoc = activeNotePath != null
        ? ref.watch(noteDocumentProvider(activeNotePath))
        : null;

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
            : KeyedSubtree(
                key: ValueKey(focusedTab.id),
                child: viewRegistry.build(
                  context,
                  ref,
                  focusedTab.content,
                  focusedTab.id,
                ),
              ),
      ),
    );
  }
}
