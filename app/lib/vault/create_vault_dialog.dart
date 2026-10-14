// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tephra/l10n/app_localizations.dart';
import 'package:tephra/vault/folder_picker.dart';
import 'package:tephra/vault/vault_creator.dart';
import 'package:tephra_core/tephra_core.dart';

/// Dialog to create a new vault folder.
class CreateVaultDialog extends ConsumerStatefulWidget {
  const CreateVaultDialog({
    super.key,
    this.isAppPrivate = false,
    this.initialParentDir,
  });

  final bool isAppPrivate;
  final String? initialParentDir;

  @override
  ConsumerState<CreateVaultDialog> createState() => _CreateVaultDialogState();
}

class _CreateVaultDialogState extends ConsumerState<CreateVaultDialog> {
  final _nameController = TextEditingController();
  String? _parentDir;
  String? _errorMessage;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _initDefaultLocation();
  }

  void _initDefaultLocation() {
    if (widget.initialParentDir != null) {
      _parentDir = widget.initialParentDir;
      return;
    }
    if (widget.isAppPrivate) return;

    if (!kIsWeb && Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null && userProfile.isNotEmpty) {
        _parentDir = p.join(userProfile, 'Documents');
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _chooseLocation() async {
    final chosen = await pickFolderWithAccess(context, ref);
    if (chosen != null && mounted) {
      setState(() {
        _parentDir = chosen;
        _errorMessage = null;
      });
    }
  }

  Future<void> _onCreate() async {
    final name = _nameController.text.trim();
    final l10n = AppLocalizations.of(context);

    if (name.isEmpty) {
      setState(() {
        _errorMessage = l10n.createVaultNameEmpty;
      });
      return;
    }

    final nameErr = VaultPath.checkName(name);
    if (nameErr != null) {
      setState(() {
        _errorMessage = nameErr == 'empty'
            ? l10n.createVaultNameEmpty
            : l10n.createVaultNameInvalid;
      });
      return;
    }

    String parent;
    if (widget.isAppPrivate) {
      final appDocs = await getApplicationDocumentsDirectory();
      final tephraDir = Directory(p.join(appDocs.path, 'Tephra Vaults'));
      if (!tephraDir.existsSync()) {
        tephraDir.createSync(recursive: true);
      }
      parent = tephraDir.path;
    } else {
      if (_parentDir == null || _parentDir!.isEmpty) {
        setState(() {
          _errorMessage = l10n.vaultErrorMissing;
        });
        return;
      }
      parent = _parentDir!;
    }

    setState(() {
      _creating = true;
      _errorMessage = null;
    });

    try {
      final createdPath = await createVault(parentDir: parent, name: name);
      if (mounted) {
        Navigator.of(context).pop(createdPath);
      }
    } on VaultCreateException catch (e) {
      if (mounted) {
        setState(() {
          _creating = false;
          _errorMessage = e.code == 'not-empty'
              ? l10n.vaultErrorNotEmpty
              : (e.code == 'empty'
                    ? l10n.createVaultNameEmpty
                    : l10n.createVaultNameInvalid);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _creating = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(l10n.createVaultTitle),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('createVault.name'),
                controller: _nameController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l10n.createVaultName,
                  errorText: _errorMessage,
                ),
                onSubmitted: (_) => _onCreate(),
              ),
              const SizedBox(height: 16),
              if (widget.isAppPrivate) ...[
                Text(
                  l10n.vaultPrivateHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ] else ...[
                Text(
                  l10n.createVaultLocation,
                  style: theme.textTheme.labelMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _parentDir ?? l10n.vaultErrorMissing,
                        style: theme.textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      key: const Key('createVault.choose'),
                      onPressed: _chooseLocation,
                      child: Text(l10n.createVaultChoose),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('createVault.cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const Key('createVault.create'),
          onPressed: _creating ? null : _onCreate,
          child: _creating
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.createVaultCreate),
        ),
      ],
    );
  }
}
