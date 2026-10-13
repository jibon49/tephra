// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../l10n/app_localizations.dart';
import '../vault/providers.dart';
import 'providers.dart';

final noteContentProvider = FutureProvider.family<TextDocument, VaultPath>((
  ref,
  path,
) async {
  ref.watch(vaultRevisionProvider);
  final fs = ref.watch(vaultFsProvider);
  return fs.readText(path);
});

class NoteView extends ConsumerWidget {
  const NoteView({
    required this.path,
    this.subpath,
    required this.tabId,
    super.key,
  });

  final VaultPath path;
  final String? subpath;
  final String tabId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final asyncDoc = ref.watch(noteContentProvider(path));

    return asyncDoc.when(
      data: (doc) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (doc.malformed)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    l10n.noteMalformedBanner,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              SelectableText(doc.text),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) {
        if (err is FileNotFoundException) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.noteMissing),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    ref.read(workspaceProvider.notifier).closeTabById(tabId);
                  },
                  child: Text(l10n.tabClose),
                ),
              ],
            ),
          );
        }
        return Center(child: Text('Error loading note: $err'));
      },
    );
  }
}
