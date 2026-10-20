// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../commands/command_registry.dart';
import '../commands/tephra_command.dart';
import '../core/sync/sync_messages.dart';
import '../core/sync/sync_worker_client.dart';
import '../vault/providers.dart';
import 'conflicts/conflicts_screen.dart';
import 'devices/devices_screen.dart';
import 'log/sync_log_screen.dart';
import 'settings/sync_settings_screen.dart';

bool _isConfigured(WidgetRef ref) {
  final session = ref.read(vaultSessionProvider);
  if (session == null) return false;
  final client = ref.read(syncWorkerClientProvider(session.vaultId));
  if (client == null) return false;
  return client.currentStatus.state != SyncUiState.notConfigured;
}

String _vaultId(WidgetRef ref) => ref.read(vaultSessionProvider)?.vaultId ?? '';

/// Registers all sync and backup related commands with the global [CommandRegistry].
void registerSyncCommands(CommandRegistry registry) {
  registry.register(
    TephraCommand(
      id: 'sync.sync-now',
      label: (l10n) => l10n.commandSyncNow,
      icon: Icons.sync,
      showInMobileToolbar: false,
      isAvailable: _isConfigured,
      run: (ref, context) {
        final client = ref.read(syncWorkerClientProvider(_vaultId(ref)));
        client?.syncNow();
      },
    ),
  );

  registry.register(
    TephraCommand(
      id: 'sync.pause',
      label: (l10n) => l10n.commandSyncPause,
      icon: Icons.pause_circle_outline,
      isAvailable: _isConfigured,
      run: (ref, context) {
        final client = ref.read(syncWorkerClientProvider(_vaultId(ref)));
        client?.setPaused(true);
      },
    ),
  );

  registry.register(
    TephraCommand(
      id: 'sync.resume',
      label: (l10n) => l10n.commandSyncResume,
      icon: Icons.play_circle_outline,
      isAvailable: _isConfigured,
      run: (ref, context) {
        final client = ref.read(syncWorkerClientProvider(_vaultId(ref)));
        client?.setPaused(false);
      },
    ),
  );

  registry.register(
    TephraCommand(
      id: 'sync.open-log',
      label: (l10n) => l10n.commandSyncOpenLog,
      icon: Icons.article_outlined,
      isAvailable: _isConfigured,
      run: (ref, context) {
        final vaultId = _vaultId(ref);
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SyncLogScreen(vaultId: vaultId),
          ),
        );
      },
    ),
  );

  registry.register(
    TephraCommand(
      id: 'sync.open-conflicts',
      label: (l10n) => l10n.commandSyncOpenConflicts,
      icon: Icons.content_copy,
      isAvailable: _isConfigured,
      run: (ref, context) {
        final session = ref.read(vaultSessionProvider);
        if (session == null) return;
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ConflictsScreen(vaultId: session.vaultId),
          ),
        );
      },
    ),
  );

  registry.register(
    TephraCommand(
      id: 'sync.open-devices',
      label: (l10n) => l10n.commandSyncOpenDevices,
      icon: Icons.devices_outlined,
      isAvailable: _isConfigured,
      run: (ref, context) {
        final vaultId = _vaultId(ref);
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => DevicesScreen(vaultId: vaultId),
          ),
        );
      },
    ),
  );

  registry.register(
    TephraCommand(
      id: 'sync.open-settings',
      label: (l10n) => l10n.commandSyncOpenSettings,
      icon: Icons.settings_outlined,
      // Available even when not configured so user can open settings
      run: (ref, context) {
        final vaultId = _vaultId(ref);
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SyncSettingsScreen(vaultId: vaultId),
          ),
        );
      },
    ),
  );

  registry.register(
    TephraCommand(
      id: 'sync.open-history',
      label: (l10n) => l10n.commandSyncOpenHistory,
      icon: Icons.history,
      isAvailable: _isConfigured,
      run: (ref, context) {
        // Step 03.21 version history
      },
    ),
  );

  registry.register(
    TephraCommand(
      id: 'sync.open-deleted',
      label: (l10n) => l10n.commandSyncOpenDeleted,
      icon: Icons.delete_sweep_outlined,
      isAvailable: _isConfigured,
      run: (ref, context) {
        // Step 03.21 recently deleted
      },
    ),
  );

  registry.register(
    TephraCommand(
      id: 'sync.backup-now',
      label: (l10n) => l10n.commandSyncBackupNow,
      icon: Icons.backup_outlined,
      isAvailable: _isConfigured,
      run: (ref, context) {
        // Step 03.22 backup-now
      },
    ),
  );

  registry.register(
    TephraCommand(
      id: 'sync.open-backups',
      label: (l10n) => l10n.commandSyncOpenBackups,
      icon: Icons.folder_zip_outlined,
      isAvailable: _isConfigured,
      run: (ref, context) {
        // Step 03.22 open backups
      },
    ),
  );
}
