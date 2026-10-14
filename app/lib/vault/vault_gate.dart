// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tephra/core/platform/platform_providers.dart';
import 'package:tephra/core/platform/storage_permission_service.dart';
import 'package:tephra/settings/providers.dart';
import 'package:tephra/vault/providers.dart';
import 'package:tephra/vault/vault_opener.dart';
import 'package:tephra/vault/vault_picker_screen.dart';
import 'package:tephra/workspace/workspace_shell.dart';

import 'autosave_host.dart';

/// Routes between [VaultPickerScreen] and the open vault workspace,
/// automatically reopening the last active vault on startup when available.
class VaultGate extends ConsumerStatefulWidget {
  const VaultGate({super.key});

  @override
  ConsumerState<VaultGate> createState() => _VaultGateState();
}

class _VaultGateState extends ConsumerState<VaultGate> {
  bool _initialized = false;
  bool _openingLast = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryReopenLastVault();
    });
  }

  Future<bool> _isPathAccessible(String path) async {
    if (kIsWeb || !Platform.isAndroid) return true;

    final service = ref.read(storagePermissionServiceProvider);
    final status = await service.status();
    if (status == StorageAccess.granted || status == StorageAccess.notNeeded) {
      return true;
    }

    try {
      final appDocs = await getApplicationDocumentsDirectory();
      if (path.startsWith(appDocs.path)) {
        return true;
      }
    } catch (_) {
      // ignore
    }

    return false;
  }

  Future<void> _tryReopenLastVault() async {
    if (_initialized) return;
    _initialized = true;

    final appSettings = ref.read(appSettingsProvider);
    final lastPath = appSettings.lastVaultPath;

    if (lastPath != null && lastPath.isNotEmpty) {
      final dir = Directory(lastPath);
      if (dir.existsSync()) {
        final accessible = await _isPathAccessible(lastPath);
        if (accessible && mounted) {
          setState(() {
            _openingLast = true;
          });

          try {
            final opener = ref.read(vaultOpenerProvider);
            await opener.open(lastPath);
          } catch (_) {
            // Fall back to showing vault picker screen
          } finally {
            if (mounted) {
              setState(() {
                _openingLast = false;
              });
            }
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(vaultSessionProvider);

    if (_openingLast) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (session == null) {
      return const VaultPickerScreen();
    }

    return const AutosaveHost(child: WorkspaceShell());
  }
}
