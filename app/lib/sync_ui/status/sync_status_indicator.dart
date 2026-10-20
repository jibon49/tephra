// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_sync/tephra_sync.dart';

import '../../core/sync/sync_messages.dart';
import '../../core/sync/sync_worker_client.dart';
import '../../l10n/app_localizations.dart';
import '../../vault/providers.dart';
import 'sync_panel.dart';

/// Interactive sync status indicator displayed in the desktop status bar and phone app bar.
class SyncStatusIndicator extends ConsumerStatefulWidget {
  const SyncStatusIndicator({super.key, this.vaultId, this.compact = false});

  final String? vaultId;
  final bool compact;

  @override
  ConsumerState<SyncStatusIndicator> createState() =>
      _SyncStatusIndicatorState();
}

class _SyncStatusIndicatorState extends ConsumerState<SyncStatusIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  void _showSyncPanel(BuildContext context, String effectiveVaultId) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 840) {
      showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SyncPanel(vaultId: effectiveVaultId),
          ),
        ),
      );
    } else {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => SyncPanel(vaultId: effectiveVaultId),
      );
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
        return theme.colorScheme.outline;
      case SyncUiState.idle:
      case SyncUiState.syncing:
      case SyncUiState.pending:
        return theme.colorScheme.primary;
      case SyncUiState.offline:
      case SyncUiState.paused:
        return theme.colorScheme.outline;
      case SyncUiState.needsAttention:
        return Colors.amber.shade700;
      case SyncUiState.error:
        return theme.colorScheme.error;
    }
  }

  String _shortText(
    AppLocalizations l10n,
    SyncStatusSnapshot snapshot,
    SyncProgress? progress,
  ) {
    switch (snapshot.state) {
      case SyncUiState.notConfigured:
        return l10n.syncStatusNotConfigured;
      case SyncUiState.idle:
        return l10n.syncStatusUpToDate;
      case SyncUiState.syncing:
        final done = progress != null ? '${progress.filesDone}' : '…';
        final total = progress != null ? '${progress.filesTotal}' : '…';
        return l10n.syncStatusSyncing(done, total);
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

  String _tooltip(AppLocalizations l10n, SyncStatusSnapshot snapshot) {
    if (snapshot.lastSyncAt != null) {
      final now = DateTime.now();
      final diff = now.difference(snapshot.lastSyncAt!.toLocal());
      if (diff.inMinutes < 1) {
        return l10n.syncPanelLastSynced('just now');
      } else if (diff.inHours < 1) {
        return l10n.syncPanelLastSynced('${diff.inMinutes} minutes ago');
      } else {
        return l10n.syncPanelLastSynced('${diff.inHours} hours ago');
      }
    }
    return _shortText(l10n, snapshot, null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final effectiveVaultId =
        widget.vaultId ?? ref.watch(vaultSessionProvider)?.vaultId ?? '';

    final client = ref.watch(syncWorkerClientProvider(effectiveVaultId));
    final statusAsync = ref.watch(syncStatusProvider(effectiveVaultId));
    final progressAsync = ref.watch(syncProgressProvider(effectiveVaultId));

    final snapshot =
        statusAsync.value ??
        client?.currentStatus ??
        const SyncStatusSnapshot(state: SyncUiState.notConfigured);
    final progress = progressAsync.value;

    final isSyncing = snapshot.state == SyncUiState.syncing;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    if (isSyncing && !reduceMotion) {
      if (!_rotationController.isAnimating) {
        _rotationController.repeat();
      }
    } else {
      if (_rotationController.isAnimating) {
        _rotationController.stop();
        _rotationController.reset();
      }
    }

    final iconColor = _colorForState(context, snapshot.state);
    final iconData = _iconForState(snapshot.state);
    final text = _shortText(l10n, snapshot, progress);
    final tooltipText = _tooltip(l10n, snapshot);

    Widget iconWidget = Icon(iconData, size: 18, color: iconColor);
    if (isSyncing && !reduceMotion) {
      iconWidget = RotationTransition(
        turns: _rotationController,
        child: iconWidget,
      );
    }

    return Semantics(
      label: tooltipText,
      button: true,
      child: Tooltip(
        message: tooltipText,
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () => _showSyncPanel(context, effectiveVaultId),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                iconWidget,
                if (!widget.compact) ...[
                  const SizedBox(width: 6),
                  Text(text, style: Theme.of(context).textTheme.labelSmall),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
