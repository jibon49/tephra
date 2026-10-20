// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_sync/tephra_sync.dart';

import '../../core/sync/sync_worker_client.dart';
import '../../l10n/app_localizations.dart';
import '../providers.dart';

/// Screen listing all paired devices syncing with the current remote vault.
class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key, required this.vaultId});

  final String vaultId;

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  List<RemoteDevice> _devices = [];
  String? _currentDeviceId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    final client = ref.read(syncWorkerClientProvider(widget.vaultId));
    final setupService = ref.read(
      syncSetupServiceForIdProvider(widget.vaultId),
    );

    try {
      final devices = await client?.queryDevices() ?? [];
      // Device ID from setup or device
      final currentDev = await setupService.currentAccount();
      // Look up current device id from local storage if available
      final deviceList = devices;

      if (mounted) {
        setState(() {
          _devices = deviceList;
          _currentDeviceId = currentDev?.email;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _formatLastSeen(DateTime? dt, AppLocalizations l10n) {
    if (dt == null || dt.millisecondsSinceEpoch == 0) {
      return l10n.syncDevicesLastSeen('recently');
    }
    final now = DateTime.now();
    final diff = now.difference(dt.toLocal());

    if (diff.inMinutes < 1) {
      return l10n.syncDevicesLastSeen('just now');
    } else if (diff.inHours < 1) {
      return l10n.syncDevicesLastSeen('${diff.inMinutes}m ago');
    } else if (diff.inDays < 1) {
      return l10n.syncDevicesLastSeen('${diff.inHours}h ago');
    } else {
      return l10n.syncDevicesLastSeen('${diff.inDays}d ago');
    }
  }

  IconData _platformIcon(String platform) {
    final p = platform.toLowerCase();
    if (p.contains('android')) return Icons.phone_android;
    if (p.contains('windows')) return Icons.laptop_windows;
    if (p.contains('mac') || p.contains('darwin')) return Icons.laptop_mac;
    if (p.contains('ios')) return Icons.phone_iphone;
    if (p.contains('linux')) return Icons.computer;
    return Icons.devices;
  }

  Future<void> _confirmRemoveDevice(
    RemoteDevice device,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.syncDevicesRemove),
        content: Text(l10n.syncDevicesRemoveConfirm(device.deviceName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(
            key: const Key('confirm_remove_device_button'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.syncDevicesRemoveButton),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final client = ref.read(syncWorkerClientProvider(widget.vaultId));
      if (client != null) {
        await client.revokeDevice(device.deviceId);
      }
      await _loadDevices();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.syncDevicesTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadDevices,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _devices.isEmpty
          ? Center(
              child: Text(
                'No paired devices found.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _devices.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, idx) {
                final device = _devices[idx];
                final isCurrent =
                    _currentDeviceId != null &&
                    device.deviceId == _currentDeviceId;
                final isRevoked = device.revoked;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    child: Icon(
                      _platformIcon(device.platform),
                      color: theme.colorScheme.primary,
                      size: 22,
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(
                        device.deviceName,
                        style: theme.textTheme.titleMedium,
                      ),
                      if (isCurrent) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            l10n.syncDevicesThisDevice,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      if (isRevoked) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            l10n.syncDevicesRemoved,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onErrorContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    _formatLastSeen(device.updatedAt, l10n),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  trailing: !isCurrent && !isRevoked
                      ? TextButton(
                          key: Key('remove_device_${device.deviceId}'),
                          style: TextButton.styleFrom(
                            foregroundColor: theme.colorScheme.error,
                          ),
                          onPressed: () => _confirmRemoveDevice(device, l10n),
                          child: Text(l10n.syncDevicesRemove),
                        )
                      : null,
                );
              },
            ),
    );
  }
}
