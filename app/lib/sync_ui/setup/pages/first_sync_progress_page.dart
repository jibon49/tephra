// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../providers.dart';

class FirstSyncProgressPage extends ConsumerWidget {
  const FirstSyncProgressPage({required this.vaultId, super.key});

  final String vaultId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(syncSetupControllerProvider(vaultId));
    final controller = ref.read(syncSetupControllerProvider(vaultId).notifier);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.sync, size: 56, color: Colors.blue),
          const SizedBox(height: 16),
          Text(
            l10n.syncSetupProgressTitle,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          LinearProgressIndicator(value: state.progressFraction),
          const SizedBox(height: 16),
          Text(
            state.progressMessage,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          if (state.errorMessage != null) ...[
            Text(
              state.errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: controller.startFirstSync,
              child: Text(l10n.syncSetupRetry),
            ),
          ] else ...[
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.syncSetupRunInBackground),
            ),
          ],
        ],
      ),
    );
  }
}
