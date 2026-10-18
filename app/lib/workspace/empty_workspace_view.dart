// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../commands/providers.dart';
import '../l10n/app_localizations.dart';
import '../vault/providers.dart';

class EmptyWorkspaceView extends ConsumerWidget {
  const EmptyWorkspaceView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant.withAlpha(160);
    final registry = ref.watch(commandRegistryProvider);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.description_outlined, size: 64, color: color),
          const SizedBox(height: 16),
          Text(
            l10n.workspaceEmptyTitle,
            style: theme.textTheme.titleMedium?.copyWith(color: color),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.icon(
                key: const Key('empty.switcher'),
                icon: const Icon(Icons.search, size: 18),
                label: Text(l10n.commandAppOpenQuickSwitcher),
                onPressed: () {
                  registry.byId('app.open-quick-switcher')?.run(ref, context);
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.commandNoteCreateNote),
                onPressed: () {
                  registry.byId('note.create-note')?.run(ref, context);
                },
              ),
              OutlinedButton.icon(
                key: const Key('empty.openVault'),
                icon: const Icon(Icons.folder_open_outlined, size: 18),
                label: Text(l10n.commandAppOpenVault),
                onPressed: () {
                  ref.read(vaultSessionProvider.notifier).close();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
