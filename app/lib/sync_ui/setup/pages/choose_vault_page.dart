// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../providers.dart';

class ChooseVaultPage extends ConsumerWidget {
  const ChooseVaultPage({required this.vaultId, super.key});

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
          Text(
            l10n.syncSetupChooseTitle,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            child: ListTile(
              leading: const Icon(Icons.add_circle_outline, color: Colors.blue),
              title: Text(l10n.syncSetupCreateNew),
              subtitle: Text(l10n.syncSetupCreateNewSubtitle),
              onTap: state.isLoading ? null : controller.selectCreateNew,
            ),
          ),
          const SizedBox(height: 16),
          if (state.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (state.remoteVaults.isNotEmpty) ...[
            Text(
              l10n.syncSetupExistingVaults,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: state.remoteVaults.length,
                itemBuilder: (context, index) {
                  final vault = state.remoteVaults[index];
                  final createdDateStr =
                      '${vault.createdAt.year}-${vault.createdAt.month.toString().padLeft(2, '0')}-${vault.createdAt.day.toString().padLeft(2, '0')}';

                  return Card(
                    child: ListTile(
                      leading: Icon(
                        vault.encrypted ? Icons.lock : Icons.lock_open,
                        color: vault.encrypted ? Colors.amber : Colors.grey,
                      ),
                      title: Text(vault.vaultName),
                      subtitle: Text(
                        '${l10n.syncSetupRemoteVaultCreated(createdDateStr)} · ${vault.createdByDeviceName}',
                      ),
                      onTap: () => controller.selectExistingVault(vault),
                    ),
                  );
                },
              ),
            ),
          ] else ...[
            Center(
              child: Text(
                'No existing vaults found.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
          if (state.errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              state.errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: controller.loadRemoteVaults,
              child: Text(l10n.syncSetupRetry),
            ),
          ],
        ],
      ),
    );
  }
}
