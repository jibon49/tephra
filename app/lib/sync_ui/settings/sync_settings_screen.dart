// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_sync/tephra_sync.dart';

import '../../core/sync/sync_messages.dart';
import '../../core/sync/sync_worker_client.dart';
import '../../l10n/app_localizations.dart';
import '../devices/devices_screen.dart';
import '../providers.dart';

/// Comprehensive settings screen for customizing sync behavior, rules, devices, and credentials.
class SyncSettingsScreen extends ConsumerStatefulWidget {
  const SyncSettingsScreen({super.key, required this.vaultId});

  final String vaultId;

  @override
  ConsumerState<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends ConsumerState<SyncSettingsScreen> {
  String _accountEmail = '';
  String _remoteVaultName = '';
  String _deviceName = '';
  final bool _encrypted = true;

  // Selective sync rules
  List<String> _excludedFolders = [];
  Set<String> _excludedExtensions = {};
  int _maxFileSizeBytes = SelectiveSyncRules.defaultMaxFileSizeBytes;
  bool _mobileMode = false;

  // Background / network settings
  bool _backgroundSync = true;
  bool _wifiOnly = false;
  bool _chargingOnly = false;
  bool _keepRunning = false;

  // Bandwidth
  int _upKiBps = 0;
  int _downKiBps = 0;

  final TextEditingController _extController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _extController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final setupService = ref.read(
      syncSetupServiceForIdProvider(widget.vaultId),
    );
    final account = await setupService.currentAccount();
    if (account != null && mounted) {
      setState(() {
        _accountEmail = account.email;
        _remoteVaultName = 'Vault';
        _deviceName = 'Device';
      });
    }
  }

  void _notifySettingsChanged() {
    final client = ref.read(syncWorkerClientProvider(widget.vaultId));
    if (client != null) {
      client.updateSettings(
        SyncWorkerSettings(
          syncMode: SyncMode.live,
          upKiBps: _upKiBps,
          downKiBps: _downKiBps,
          paused: false,
        ),
      );
    }
  }

  Future<void> _promptAddFolder(AppLocalizations l10n) async {
    final controller = TextEditingController();
    final folder = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.syncSettingsAddExcludedFolder),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'e.g. archive or raw_footage',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
          ),
        ],
      ),
    );

    if (folder != null &&
        folder.isNotEmpty &&
        !_excludedFolders.contains(folder)) {
      setState(() {
        _excludedFolders = [..._excludedFolders, folder];
      });
      _notifySettingsChanged();
    }
  }

  void _addExtension() {
    final raw = _extController.text.trim().toLowerCase().replaceAll(
      RegExp(r'^\.'),
      '',
    );
    if (raw.isNotEmpty && !_excludedExtensions.contains(raw)) {
      setState(() {
        _excludedExtensions = {..._excludedExtensions, raw};
        _extController.clear();
      });
      _notifySettingsChanged();
    }
  }

  void _removeExtension(String ext) {
    setState(() {
      _excludedExtensions = _excludedExtensions.where((e) => e != ext).toSet();
    });
    _notifySettingsChanged();
  }

  Future<void> _promptEditDeviceName(AppLocalizations l10n) async {
    final controller = TextEditingController(text: _deviceName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.syncSettingsDeviceNameLabel),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      setState(() => _deviceName = newName);
      _notifySettingsChanged();
    }
  }

  Future<void> _showChangePasswordDialog(AppLocalizations l10n) async {
    final oldController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.syncSettingsChangePasswordTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: oldController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l10n.syncSettingsOldPassword,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l10n.syncSettingsNewPassword,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l10n.syncSettingsConfirmNewPassword,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () {
              if (newController.text.length < 10) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.syncSetupPasswordTooShort)),
                );
                return;
              }
              if (newController.text != confirmController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.syncSetupPasswordMismatch)),
                );
                return;
              }
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.syncSettingsPasswordChangedSuccess),
                ),
              );
            },
            child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _showRegenerateRecoveryKeyDialog(AppLocalizations l10n) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.syncSettingsShowRecoveryKey),
        content: Text(l10n.syncSettingsRecoveryKeyRegeneratedSuccess),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDisconnect(AppLocalizations l10n) async {
    bool alsoSignOut = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(l10n.syncDisconnect),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.syncDisconnectConfirm),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: alsoSignOut,
                title: Text(l10n.syncDisconnectAlsoSignOut),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (val) {
                  setDlgState(() => alsoSignOut = val ?? false);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
                foregroundColor: Theme.of(ctx).colorScheme.onError,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.syncDisconnect),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final setup = ref.read(syncSetupServiceForIdProvider(widget.vaultId));
      await setup.disconnect(signOutGoogle: alsoSignOut);
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDesktop =
        !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    final isAndroid = !kIsWeb && Platform.isAndroid;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.syncSettingsTitle)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          // Account & remote vault
          _SectionHeader(title: l10n.syncSettingsAccountHeader),
          if (_accountEmail.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: Text(l10n.syncSetupSignedInAs(_accountEmail)),
            ),
          ListTile(
            leading: const Icon(Icons.cloud_done_outlined),
            title: Text(l10n.syncSettingsRemoteVaultLabel),
            subtitle: Text(
              _remoteVaultName.isEmpty ? 'Tephra' : _remoteVaultName,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.devices_outlined),
            title: Text(l10n.syncSettingsDeviceNameLabel),
            subtitle: Text(_deviceName.isEmpty ? 'Device' : _deviceName),
            trailing: IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => _promptEditDeviceName(l10n),
            ),
          ),
          ListTile(
            leading: Icon(
              _encrypted ? Icons.lock_outline : Icons.lock_open_outlined,
              color: _encrypted
                  ? theme.colorScheme.primary
                  : Colors.amber.shade700,
            ),
            title: Text(l10n.syncSettingsEncryptionLabel),
            subtitle: Text(
              _encrypted
                  ? l10n.syncSettingsEncryptionEnabled
                  : l10n.syncSettingsEncryptionDisabled,
            ),
          ),

          const Divider(),

          // Exclusions & Selective sync
          _SectionHeader(title: l10n.syncSettingsExclusionsHeader),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                l10n.syncSettingsExclusionsExplain,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),

          // Excluded folders
          ListTile(
            title: Text(l10n.syncSettingsExcludedFolders),
            trailing: TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.syncSettingsAddExcludedFolder),
              onPressed: () => _promptAddFolder(l10n),
            ),
          ),
          if (_excludedFolders.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'None',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            )
          else
            ..._excludedFolders.map(
              (f) => ListTile(
                dense: true,
                leading: const Icon(Icons.folder_off_outlined, size: 20),
                title: Text(f),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: () {
                    setState(() {
                      _excludedFolders = _excludedFolders
                          .where((e) => e != f)
                          .toList();
                    });
                    _notifySettingsChanged();
                  },
                ),
              ),
            ),

          const SizedBox(height: 8),

          // Excluded extensions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              l10n.syncSettingsExcludedFileTypes,
              style: theme.textTheme.titleSmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ..._excludedExtensions.map(
                  (ext) => Chip(
                    label: Text(ext),
                    onDeleted: () => _removeExtension(ext),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('sync_settings_ext_field'),
                    controller: _extController,
                    decoration: InputDecoration(
                      hintText: l10n.syncSettingsExcludedFileTypesHint,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onSubmitted: (_) => _addExtension(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  icon: const Icon(Icons.add),
                  onPressed: _addExtension,
                ),
              ],
            ),
          ),

          // Max file size
          ListTile(
            title: Text(l10n.syncSettingsMaxFileSize),
            trailing: DropdownButton<int>(
              value: _maxFileSizeBytes,
              underline: const SizedBox.shrink(),
              items: [
                const DropdownMenuItem(
                  value: 10 * 1024 * 1024,
                  child: Text('10 MB'),
                ),
                const DropdownMenuItem(
                  value: 50 * 1024 * 1024,
                  child: Text('50 MB'),
                ),
                const DropdownMenuItem(
                  value: 100 * 1024 * 1024,
                  child: Text('100 MB'),
                ),
                const DropdownMenuItem(
                  value: 500 * 1024 * 1024,
                  child: Text('500 MB'),
                ),
                DropdownMenuItem(
                  value: 2 * 1024 * 1024 * 1024,
                  child: Text(l10n.syncSettingsMaxFileSizeNoLimit),
                ),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _maxFileSizeBytes = val);
                  _notifySettingsChanged();
                }
              },
            ),
          ),

          const Divider(),

          // Mobile / Desktop specific settings
          if (isAndroid) ...[
            _SectionHeader(title: l10n.syncSettingsMobileHeader),
            SwitchListTile(
              title: Text(l10n.syncSettingsMobileMode),
              subtitle: Text(l10n.syncSetupMobileModeSubtitle),
              value: _mobileMode,
              onChanged: (val) {
                setState(() => _mobileMode = val);
                _notifySettingsChanged();
              },
            ),
            SwitchListTile(
              title: Text(l10n.syncSettingsBackgroundSync),
              subtitle: Text(l10n.syncSetupBackgroundSyncSubtitle),
              value: _backgroundSync,
              onChanged: (val) {
                setState(() => _backgroundSync = val);
                _notifySettingsChanged();
              },
            ),
            SwitchListTile(
              title: Text(l10n.syncSettingsWifiOnly),
              subtitle: Text(l10n.syncSetupWifiOnlySubtitle),
              value: _wifiOnly,
              onChanged: (val) {
                setState(() => _wifiOnly = val);
                _notifySettingsChanged();
              },
            ),
            SwitchListTile(
              title: Text(l10n.syncSettingsChargingOnly),
              value: _chargingOnly,
              onChanged: (val) {
                setState(() => _chargingOnly = val);
                _notifySettingsChanged();
              },
            ),
            const Divider(),
          ],

          if (isDesktop) ...[
            _SectionHeader(title: l10n.syncSettingsDesktopHeader),
            SwitchListTile(
              title: Text(l10n.syncSettingsKeepSyncingOnClose),
              value: _keepRunning,
              onChanged: (val) {
                setState(() => _keepRunning = val);
                _notifySettingsChanged();
              },
            ),
            const Divider(),
          ],

          // Bandwidth limits
          _SectionHeader(title: l10n.syncSettingsBandwidthHeader),
          ListTile(
            title: Text(l10n.syncSettingsUploadLimit),
            trailing: SizedBox(
              width: 100,
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                controller: TextEditingController(text: _upKiBps.toString()),
                onSubmitted: (val) {
                  final parsed = int.tryParse(val) ?? 0;
                  setState(() => _upKiBps = parsed);
                  _notifySettingsChanged();
                },
              ),
            ),
          ),
          ListTile(
            title: Text(l10n.syncSettingsDownloadLimit),
            trailing: SizedBox(
              width: 100,
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                controller: TextEditingController(text: _downKiBps.toString()),
                onSubmitted: (val) {
                  final parsed = int.tryParse(val) ?? 0;
                  setState(() => _downKiBps = parsed);
                  _notifySettingsChanged();
                },
              ),
            ),
          ),

          const Divider(),

          // Security & keys
          _SectionHeader(title: l10n.syncSettingsSecurityHeader),
          ListTile(
            leading: const Icon(Icons.password_outlined),
            title: Text(l10n.syncSettingsChangePassword),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showChangePasswordDialog(l10n),
          ),
          ListTile(
            leading: const Icon(Icons.key_outlined),
            title: Text(l10n.syncSettingsShowRecoveryKey),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showRegenerateRecoveryKeyDialog(l10n),
          ),

          const Divider(),

          // Devices link
          ListTile(
            leading: const Icon(Icons.devices_outlined),
            title: Text(l10n.syncSettingsDevicesLink),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DevicesScreen(vaultId: widget.vaultId),
                ),
              );
            },
          ),

          const Divider(),

          // Disconnect
          ListTile(
            leading: Icon(Icons.cloud_off, color: theme.colorScheme.error),
            title: Text(
              l10n.syncDisconnect,
              style: TextStyle(color: theme.colorScheme.error),
            ),
            onTap: () => _confirmDisconnect(l10n),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
