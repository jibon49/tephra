// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra/core/platform/platform_providers.dart';
import 'package:tephra/core/platform/storage_permission_service.dart';
import 'package:tephra/l10n/app_localizations.dart';
import 'package:tephra/settings/providers.dart';
import 'package:tephra/vault/create_vault_dialog.dart';
import 'package:tephra/vault/folder_picker.dart';
import 'package:tephra/vault/recent_vault_tile.dart';
import 'package:tephra/vault/vault_creator.dart';
import 'package:tephra/vault/vault_metadata.dart';
import 'package:tephra/vault/vault_opener.dart';

/// Screen allowing the user to select an existing vault, create a new vault,
/// or pick from recently opened vaults.
class VaultPickerScreen extends ConsumerStatefulWidget {
  const VaultPickerScreen({super.key, this.isAndroid});

  final bool? isAndroid;

  @override
  ConsumerState<VaultPickerScreen> createState() => _VaultPickerScreenState();
}

class _VaultPickerScreenState extends ConsumerState<VaultPickerScreen> {
  bool _opening = false;
  StorageAccess _storageStatus = StorageAccess.notNeeded;

  bool get _effectiveIsAndroid =>
      widget.isAndroid ?? (!kIsWeb && Platform.isAndroid);

  @override
  void initState() {
    super.initState();
    _checkStorageStatus();
  }

  Future<void> _checkStorageStatus() async {
    if (_effectiveIsAndroid) {
      final service = ref.read(storagePermissionServiceProvider);
      final status = await service.status();
      if (mounted) {
        setState(() {
          _storageStatus = status;
        });
      }
    }
  }

  Future<void> _openVault(String path, {bool isAppPrivate = false}) async {
    setState(() {
      _opening = true;
    });

    final l10n = AppLocalizations.of(context);
    try {
      final opener = ref.read(vaultOpenerProvider);
      final session = await opener.open(path, isAppPrivate: isAppPrivate);

      if (session.settings.importedFromObsidian && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.vaultImportedFromObsidian)));
      }
    } catch (e) {
      if (mounted) {
        String msg;
        if (e is VaultOpenException) {
          switch (e.code) {
            case 'missing':
              msg = l10n.vaultErrorMissing;
              break;
            case 'not-a-folder':
              msg = l10n.vaultErrorNotAFolder;
              break;
            case 'no-access':
              msg = l10n.vaultErrorNoAccess;
              break;
            case 'too-new':
              msg = l10n.vaultErrorTooNew;
              break;
            default:
              msg = e.toString();
          }
        } else if (e is VaultCreateException) {
          msg = e.code == 'not-empty'
              ? l10n.vaultErrorNotEmpty
              : l10n.createVaultNameInvalid;
        } else if (e is VaultTooNewException) {
          msg = l10n.vaultErrorTooNew;
        } else {
          msg = e.toString();
        }

        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            content: Text(msg),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l10n.commonOk),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _opening = false;
        });
      }
    }
  }

  Future<void> _onOpenTapped() async {
    final chosen = await pickFolderWithAccess(
      context,
      ref,
      isAndroid: _effectiveIsAndroid,
    );
    if (chosen != null) {
      await _openVault(chosen);
    }
  }

  Future<void> _onCreateTapped() async {
    final path = await showDialog<String>(
      context: context,
      builder: (_) => const CreateVaultDialog(),
    );
    if (path != null) {
      await _openVault(path);
    }
  }

  Future<void> _onCreatePrivateTapped() async {
    final path = await showDialog<String>(
      context: context,
      builder: (_) => const CreateVaultDialog(isAppPrivate: true),
    );
    if (path != null) {
      await _openVault(path, isAppPrivate: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final appSettings = ref.watch(appSettingsProvider);
    final recentVaults = appSettings.recentVaults;

    final showCreatePrivate =
        _effectiveIsAndroid &&
        _storageStatus != StorageAccess.granted &&
        _storageStatus != StorageAccess.notNeeded;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 32.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.edit_note_rounded,
                    size: 80,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.welcomeTitle,
                    style: theme.textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.welcomeSubtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  if (_opening) ...[
                    const Center(child: CircularProgressIndicator()),
                  ] else ...[
                    FilledButton.icon(
                      key: const Key('vaultPicker.open'),
                      icon: const Icon(Icons.folder_open_outlined),
                      label: Text(l10n.welcomeOpenVault),
                      onPressed: _onOpenTapped,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      key: const Key('vaultPicker.create'),
                      icon: const Icon(Icons.create_new_folder_outlined),
                      label: Text(l10n.welcomeCreateVault),
                      onPressed: _onCreateTapped,
                    ),
                    if (showCreatePrivate) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        key: const Key('vaultPicker.createPrivate'),
                        icon: const Icon(Icons.shield_outlined),
                        label: Text(l10n.vaultPickerCreatePrivate),
                        onPressed: _onCreatePrivateTapped,
                      ),
                    ],
                  ],
                  if (recentVaults.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 16),
                    Text(
                      l10n.vaultPickerRecent,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: recentVaults.length,
                      itemBuilder: (context, index) {
                        final v = recentVaults[index];
                        return RecentVaultTile(
                          vault: v,
                          index: index,
                          onOpen: () => _openVault(v.path),
                          onRemove: () => ref
                              .read(appSettingsProvider.notifier)
                              .removeRecentVault(v.path),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
