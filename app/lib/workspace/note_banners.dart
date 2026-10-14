// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../vault/note_document.dart';
import 'providers.dart';

/// Banner shown above note content when the file was deleted on disk outside Tephra.
class DeletedOnDiskBanner extends ConsumerWidget {
  const DeletedOnDiskBanner({
    super.key,
    required this.doc,
    required this.tabId,
  });

  final NoteDocument doc;
  final String tabId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Container(
      key: const ValueKey('note.deletedBanner'),
      color: theme.colorScheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.noteDeletedBanner,
              style: TextStyle(color: theme.colorScheme.onErrorContainer),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(workspaceProvider.notifier).closeTabById(tabId);
            },
            child: Text(l10n.tabClose),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: () async {
              await doc.save(force: true);
            },
            child: Text(l10n.noteRecreate),
          ),
        ],
      ),
    );
  }
}
