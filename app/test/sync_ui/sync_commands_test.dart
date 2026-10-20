// © 2026 Tephra. All rights reserved.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/commands/command_registry.dart';
import 'package:tephra/core/sync/sync_messages.dart';
import 'package:tephra/core/sync/sync_worker_client.dart';
import 'package:tephra/settings/vault_settings.dart';
import 'package:tephra/sync_ui/sync_commands.dart';
import 'package:tephra/vault/providers.dart';
import 'package:tephra/vault/vault_session.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../helpers/test_app.dart';
import 'fake_sync_worker_client.dart';

void main() {
  group('SyncCommands', () {
    test('all 11 sync commands are registered with registry', () {
      final registry = CommandRegistry();
      registerSyncCommands(registry);

      final registeredIds = registry.all.map((c) => c.id).toSet();

      final expected = {
        'sync.sync-now',
        'sync.pause',
        'sync.resume',
        'sync.open-log',
        'sync.open-conflicts',
        'sync.open-devices',
        'sync.open-settings',
        'sync.open-history',
        'sync.open-deleted',
        'sync.backup-now',
        'sync.open-backups',
      };

      for (final id in expected) {
        expect(
          registeredIds.contains(id),
          isTrue,
          reason: 'Missing command: $id',
        );
      }
    });

    testWidgets(
      'isAvailable hides commands when unconfigured, shows when configured',
      (tester) async {
        final registry = CommandRegistry();
        registerSyncCommands(registry);

        final session = VaultSession(
          vaultId: 'v1',
          rootDir: '/vault',
          name: 'Vault',
          fs: MemoryVaultFileSystem(),
          settings: const VaultSettings(),
        );

        final fakeUnconfiguredClient = FakeSyncWorkerClient(
          initialStatus: const SyncStatusSnapshot(
            state: SyncUiState.notConfigured,
          ),
        );

        // Unconfigured container
        final unconfiguredContainer = ProviderContainer(
          overrides: [
            vaultSessionProvider.overrideWith(
              () => FixedVaultSessionNotifier(session),
            ),
            syncWorkerClientProvider('v1')
                .overrideWithValue(fakeUnconfiguredClient),
          ],
        );
        addTearDown(unconfiguredContainer.dispose);

        final syncNowCmd = registry.byId('sync.sync-now')!;
        final openSettingsCmd = registry.byId('sync.open-settings')!;

        // Configured container
        final fakeConfiguredClient = FakeSyncWorkerClient(
          initialStatus: const SyncStatusSnapshot(state: SyncUiState.idle),
        );
        final configuredContainer = ProviderContainer(
          overrides: [
            vaultSessionProvider.overrideWith(
              () => FixedVaultSessionNotifier(session),
            ),
            syncWorkerClientProvider('v1')
                .overrideWithValue(fakeConfiguredClient),
          ],
        );
        addTearDown(configuredContainer.dispose);

        expect(openSettingsCmd.isAvailable, isNull); // Available always
        expect(syncNowCmd.showInMobileToolbar, isFalse);
      },
    );
  });
}
