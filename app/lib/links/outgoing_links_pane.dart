// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/tephra_index.dart';

import '../l10n/app_localizations.dart';
import '../workspace/providers.dart';
import 'providers.dart';

/// Pane displaying outgoing links from the active note.
class OutgoingLinksPane extends ConsumerWidget {
  const OutgoingLinksPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activePath = ref.watch(activeNotePathProvider);
    final l10n = AppLocalizations.of(context);

    if (activePath == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            l10n.noActiveNote,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: Theme.of(context).hintColor),
          ),
        ),
      );
    }

    final outgoingAsync = ref.watch(outgoingLinksProvider(activePath));

    return outgoingAsync.when(
      data: (links) {
        if (links.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No outgoing links',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: Theme.of(context).hintColor),
              ),
            ),
          );
        }

        // Group by (targetPath ?? targetRaw.toLowerCase(), kind)
        final groups = <String, List<LinkRecord>>{};
        for (final l in links) {
          final key =
              '${l.targetPath?.value ?? l.targetRaw.toLowerCase()}:${l.kind}';
          groups.putIfAbsent(key, () => []).add(l);
        }

        final resolvedGroups = <List<LinkRecord>>[];
        final unresolvedGroups = <List<LinkRecord>>[];

        for (final group in groups.values) {
          if (group.first.resolved && group.first.targetPath != null) {
            resolvedGroups.add(group);
          } else {
            unresolvedGroups.add(group);
          }
        }

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            if (resolvedGroups.isNotEmpty) ...[
              for (final group in resolvedGroups)
                _buildResolvedTile(context, ref, activePath, group),
            ],
            if (unresolvedGroups.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  l10n.unresolvedLinksSection,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              for (final group in unresolvedGroups)
                _buildUnresolvedTile(context, ref, activePath, group, l10n),
            ],
          ],
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (err, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Error: $err'),
      ),
    );
  }

  Widget _buildResolvedTile(
    BuildContext context,
    WidgetRef ref,
    VaultPath activePath,
    List<LinkRecord> group,
  ) {
    final first = group.first;
    final targetPath = first.targetPath!;
    final isEmbed = first.kind == LinkKind.embed;

    return ListTile(
      dense: true,
      leading: Icon(
        isEmbed ? Icons.image_outlined : Icons.description_outlined,
        size: 18,
      ),
      title: Text(targetPath.stem, overflow: TextOverflow.ellipsis),
      subtitle: targetPath.parent != null
          ? Text(
              targetPath.parent!.value,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: group.length > 1
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${group.length}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            )
          : null,
      onTap: () async {
        await ref
            .read(linkNavigatorProvider)
            .open(
              target: first.targetRaw,
              from: activePath,
              heading: first.heading,
              blockRef: first.blockRef,
            );
      },
    );
  }

  Widget _buildUnresolvedTile(
    BuildContext context,
    WidgetRef ref,
    VaultPath activePath,
    List<LinkRecord> group,
    AppLocalizations l10n,
  ) {
    final first = group.first;
    final isPhone = MediaQuery.of(context).size.width < 840;

    return ListTile(
      dense: true,
      title: Opacity(
        opacity: 0.6,
        child: Text(first.targetRaw, overflow: TextOverflow.ellipsis),
      ),
      trailing: SizedBox(
        height: isPhone ? 48 : 32,
        child: TextButton(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          onPressed: () async {
            await ref
                .read(linkNavigatorProvider)
                .open(target: first.targetRaw, from: activePath);
          },
          child: Text(l10n.createLinkAction),
        ),
      ),
    );
  }
}
