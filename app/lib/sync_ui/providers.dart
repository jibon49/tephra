// © 2026 Tephra. All rights reserved.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../vault/providers.dart';
import 'setup/sync_setup_controller.dart';
import 'setup/sync_setup_service.dart';

export 'setup/sync_setup_controller.dart';
export 'setup/sync_setup_service.dart';

/// Provider for [SyncSetupService] for a given vault id and local root path.
final syncSetupServiceProvider =
    Provider.family<
      SyncSetupService,
      ({String vaultId, String localVaultRootPath})
    >((ref, arg) {
      final auth = ref.watch(googleAuthServiceProvider);
      return DriveSyncSetupService(
        vaultId: arg.vaultId,
        localVaultRootPath: arg.localVaultRootPath,
        googleAuthService: auth,
      );
    });

/// State notifier provider for the sync setup wizard.
final syncSetupControllerProvider =
    NotifierProvider.family<SyncSetupController, SyncSetupState, String>(
      SyncSetupController.new,
    );

/// Convenient provider to get the [SyncSetupService] for a vault by ID, looking up
/// the active vault root path from [vaultSessionProvider] when available.
final syncSetupServiceForIdProvider = Provider.family<SyncSetupService, String>(
  (ref, vaultId) {
    final session = ref.watch(vaultSessionProvider);
    final rootPath = (session != null && session.vaultId == vaultId)
        ? session.rootDir
        : '';
    return ref.watch(
      syncSetupServiceProvider((
        vaultId: vaultId,
        localVaultRootPath: rootPath,
      )),
    );
  },
);

/// Asynchronous provider checking whether sync is configured for a given vault.
final isSyncConfiguredProvider =
    FutureProvider.family<bool, ({String vaultId, String localVaultRootPath})>((
      ref,
      arg,
    ) async {
      final service = ref.watch(syncSetupServiceProvider(arg));
      return service.isConfigured();
    });
