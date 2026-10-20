// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sync/sync_messages.dart';
import '../../core/sync/sync_worker_client.dart';
import '../../l10n/app_localizations.dart';
import '../../vault/providers.dart';
import '../conflicts/conflicts_screen.dart';
import '../held_deletes/held_deletes_sheet.dart';
import '../history/deleted_files_screen.dart';
import '../log/sync_log_screen.dart';
import '../providers.dart';
import '../settings/sync_settings_screen.dart';
import '../setup/sync_setup_wizard.dart';

/// Interactive panel displaying sync status, quota, triggers, and navigation links.
class SyncPanel extends ConsumerWidget {
  const SyncPanel({super.key, required this.vaultId});

  final String vaultId;

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(1)} GB';
  }

  String _formatLastSynced(DateTime? dt, AppLocalizations l10n) {
    if (dt == null) return l10n.syncPanelLastSynced('never');
    final now = DateTime.now();
    final diff = now.difference(dt.toLocal());

    if (diff.inMinutes < 1) {
      return l10n.syncPanelLastSynced('just now');
    } else if (diff.inHours < 1) {
      return l10n.syncPanelLastSynced('${diff.inMinutes}m ago');
    } else if (diff.inDays < 1) {
      return l10n.syncPanelLastSynced('${diff.inHours}h ago');
    } else {
      return l10n.syncPanelLastSynced('${diff.inDays}d ago');
    }
  }

  IconData _iconForState(SyncUiState state) {
    switch (state) {
      case SyncUiState.notConfigured:
        return Icons.cloud_outlined;
      case SyncUiState.idle:
        return Icons.cloud_done_outlined;
      case SyncUiState.syncing:
        return Icons.sync;
      case SyncUiState.pending:
        return Icons.cloud_upload_outlined;
      case SyncUiState.offline:
        return Icons.cloud_off_outlined;
      case SyncUiState.paused:
        return Icons.pause_circle_outline;
      case SyncUiState.needsAttention:
        return Icons.warning_amber_rounded;
      case SyncUiState.error:
        return Icons.error_outline;
    }
  }

  Color _colorForState(BuildContext context, SyncUiState state) {
    final theme = Theme.of(context);
    switch (state) {
      case SyncUiState.notConfigured:
      case SyncUiState.paused:
      case SyncUiState.offline:
        return theme.colorScheme.outline;
      case SyncUiState.idle:
      case SyncUiState.syncing:
      case SyncUiState.pending:
        return theme.colorScheme.primary;
      case SyncUiState.needsAttention:
        return Colors.amber.shade700;
      case SyncUiState.error:
        return theme.colorScheme.error;
    }
  }

  String _labelForState(AppLocalizations l10n, SyncStatusSnapshot snapshot) {
    switch (snapshot.state) {
      case SyncUiState.notConfigured:
        return l10n.syncStatusNotConfigured;
      case SyncUiState.idle:
        return l10n.syncStatusUpToDate;
      case SyncUiState.syncing:
        return l10n.syncStatusSyncing('…', '…');
      case SyncUiState.pending:
        return l10n.syncStatusPending(snapshot.pendingLocalChanges);
      case SyncUiState.offline:
        return l10n.syncStatusOffline;
      case SyncUiState.paused:
        return l10n.syncStatusPaused;
      case SyncUiState.needsAttention:
        return l10n.syncStatusNeedsAttention;
      case SyncUiState.error:
        return l10n.syncStatusError;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final client = ref.watch(syncWorkerClientProvider(vaultId));
    final statusAsync = ref.watch(syncStatusProvider(vaultId));
    final snapshot =
        statusAsync.value ??
        client?.currentStatus ??
        const SyncStatusSnapshot(state: SyncUiState.notConfigured);

    final isPaused = snapshot.state == SyncUiState.paused;
    final isSyncing = snapshot.state == SyncUiState.syncing;
    final needsReconnect =
        snapshot.errorKind == 'authRevoked' ||
        (snapshot.state == SyncUiState.needsAttention &&
            snapshot.errorKind?.contains('auth') == true);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Header
            Row(
              children: [
                Icon(
                  _iconForState(snapshot.state),
                  size: 28,
                  color: _colorForState(context, snapshot.state),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _labelForState(l10n, snapshot),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _formatLastSynced(snapshot.lastSyncAt, l10n),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                if (snapshot.state == SyncUiState.notConfigured)
                  FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      final session = ref.read(vaultSessionProvider);
                      showSyncSetupWizard(
                        context,
                        vaultId: vaultId,
                        localVaultRootPath: session?.rootDir ?? '',
                      );
                    },
                    child: Text(l10n.syncSetupAction),
                  ),
              ],
            ),

            if (snapshot.accountEmail != null &&
                snapshot.accountEmail!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.account_circle_outlined,
                    size: 16,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    snapshot.accountEmail!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ],

            // Reconnect Banner
            if (needsReconnect) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade400),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.amber.shade900,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.syncReconnectBanner,
                            style: TextStyle(
                              color: Colors.amber.shade900,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                      key: const Key('sync_panel_reconnect_button'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.amber.shade800,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        final setup = ref.read(
                          syncSetupServiceForIdProvider(vaultId),
                        );
                        try {
                          await setup.signInInteractive();
                          await client?.syncNow();
                        } catch (_) {}
                      },
                      child: Text(l10n.syncReconnectButton),
                    ),
                  ],
                ),
              ),
            ],

            // Quota / Usage Bar
            if (snapshot.quota != null) ...[
              const SizedBox(height: 16),
              Builder(
                builder: (context) {
                  final quota = snapshot.quota!;
                  final limit = quota.limitBytes ?? 0;
                  final used = quota.usedBytes;
                  final progress = limit > 0
                      ? (used / limit).clamp(0.0, 1.0)
                      : 0.0;
                  final limitStr = limit > 0 ? _formatBytes(limit) : '∞';

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.syncPanelDriveUsage(_formatBytes(used), limitStr),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],

            const SizedBox(height: 16),

            // Action Buttons
            if (snapshot.state != SyncUiState.notConfigured) ...[
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('sync_panel_sync_now_button'),
                      icon: const Icon(Icons.sync, size: 18),
                      label: Text(l10n.syncPanelSyncNow),
                      onPressed: isSyncing || isPaused
                          ? null
                          : () => client?.syncNow(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('sync_panel_pause_resume_button'),
                      icon: Icon(
                        isPaused ? Icons.play_arrow : Icons.pause,
                        size: 18,
                      ),
                      label: Text(
                        isPaused ? l10n.syncPanelResume : l10n.syncPanelPause,
                      ),
                      onPressed: () => client?.setPaused(!isPaused),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            const Divider(),

            // Links / Rows
            if (snapshot.unresolvedConflicts > 0)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.content_copy,
                  color: theme.colorScheme.error,
                  size: 20,
                ),
                title: Text(
                  l10n.syncPanelConflicts(snapshot.unresolvedConflicts),
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ConflictsScreen(vaultId: vaultId),
                    ),
                  );
                },
              ),

            if (snapshot.heldDeletes.isNotEmpty)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.shield_outlined,
                  color: Colors.amber.shade700,
                  size: 20,
                ),
                title: Text(
                  l10n.syncPanelHeldDeletes(snapshot.heldDeletes.length),
                  style: TextStyle(
                    color: Colors.amber.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () {
                  Navigator.of(context).pop();
                  showHeldDeletesSheet(
                    context,
                    vaultId: vaultId,
                    heldDeletes: snapshot.heldDeletes,
                  );
                },
              ),

            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.delete_sweep_outlined, size: 20),
              title: Text(l10n.deletedTitle),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => DeletedFilesScreen(vaultId: vaultId),
                  ),
                );
              },
            ),

            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.article_outlined, size: 20),
              title: Text(l10n.syncPanelLog),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SyncLogScreen(vaultId: vaultId),
                  ),
                );
              },
            ),

            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.settings_outlined, size: 20),
              title: Text(l10n.syncPanelSettings),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SyncSettingsScreen(vaultId: vaultId),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
