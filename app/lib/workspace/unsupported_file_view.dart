// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../vault/providers.dart';
import 'tab_content.dart';

final fileStatProvider = FutureProvider.family<VaultEntry?, VaultPath>((
  ref,
  path,
) async {
  final fs = ref.watch(vaultFsProvider);
  return fs.stat(path);
});

class UnsupportedFileView extends ConsumerWidget {
  const UnsupportedFileView({
    required this.content,
    required this.tabId,
    super.key,
  });

  final TabContent content;
  final String tabId;

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (content is! FileTabContent) {
      return Center(child: Text(l10n.unsupportedFileTitle));
    }

    final fileContent = content as FileTabContent;
    final path = fileContent.path;
    final statAsync = ref.watch(fileStatProvider(path));
    final session = ref.watch(vaultSessionProvider);
    final isAndroid = !kIsWeb && Platform.isAndroid;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.insert_drive_file_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              path.name,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            statAsync.when(
              data: (entry) {
                if (entry == null) return const SizedBox.shrink();
                return Text(
                  formatBytes(entry.size),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),
            if (isAndroid)
              Text(
                l10n.unsupportedFileAndroid,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              )
            else
              FilledButton.icon(
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text(l10n.openWithSystemApp),
                onPressed: () {
                  if (session != null) {
                    final absPath = p.join(session.rootDir, path.value);
                    launchUrl(Uri.file(absPath));
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}
