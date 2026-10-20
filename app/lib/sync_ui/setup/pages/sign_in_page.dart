// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../providers.dart';

class SignInPage extends ConsumerWidget {
  const SignInPage({required this.vaultId, super.key});

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
          const Icon(Icons.cloud_sync_outlined, size: 64, color: Colors.blue),
          const SizedBox(height: 16),
          Text(
            l10n.syncSetupTitle,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.syncSetupSignInExplain,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          if (state.account != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(Icons.account_circle, size: 40),
                    const SizedBox(height: 8),
                    Text(
                      l10n.syncSetupSignedInAs(state.account!.email),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: state.isLoading ? null : controller.signOut,
                      child: Text(l10n.syncSetupUseAnotherAccount),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: state.isLoading
                          ? null
                          : () => controller.loadRemoteVaults(),
                      child: Text(l10n.syncSetupContinue),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            FilledButton.icon(
              icon: const Icon(Icons.login),
              label: Text(l10n.syncSetupSignInButton),
              onPressed: state.isLoading ? null : controller.signIn,
            ),
          ],
          if (state.isLoading) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
          if (state.errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              state.errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
