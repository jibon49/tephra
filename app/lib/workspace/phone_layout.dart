// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
        appBar: AppBar(
          leading: Builder(
            builder: (ctx) => IconButton(
              key: const Key('phone.menu'),
              icon: const Icon(Icons.menu),
              tooltip: l10n.phoneMenu,
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
          title: Text(title),
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
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'reading',
                  child: Text(
                    focusedTab?.mode == ViewMode.reading
                        ? l10n.modeSource
                        : l10n.modeReading,
                  ),
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
