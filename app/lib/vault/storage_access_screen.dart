// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra/core/platform/platform_providers.dart';
import 'package:tephra/core/platform/storage_permission_service.dart';
import 'package:tephra/l10n/app_localizations.dart';

/// Full-screen Android permission explanation screen for All Files Access.
class StorageAccessScreen extends ConsumerStatefulWidget {
  const StorageAccessScreen({super.key, this.service});

  final StoragePermissionService? service;

  @override
  ConsumerState<StorageAccessScreen> createState() =>
      _StorageAccessScreenState();
}

class _StorageAccessScreenState extends ConsumerState<StorageAccessScreen> {
  late final AppLifecycleListener _lifecycleListener;
  bool _requested = false;

  StoragePermissionService get _service =>
      widget.service ?? ref.read(storagePermissionServiceProvider);

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(onResume: _handleResume);
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  Future<void> _handleResume() async {
    if (!_requested) return;
    final status = await _service.status();
    if (status == StorageAccess.granted && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _allowAccess() async {
    _requested = true;
    final currentStatus = await _service.status();
    if (currentStatus == StorageAccess.permanentlyDenied) {
      await _service.openSystemSettings();
      return;
    }

    final newStatus = await _service.request();
    if (newStatus == StorageAccess.granted && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.storageAccessTitle),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Icon(
                Icons.folder_shared_outlined,
                size: 72,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                l10n.storageAccessTitle,
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    l10n.storageAccessBody,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('storageAccess.allow'),
                onPressed: _allowAccess,
                child: Text(l10n.storageAccessAllow),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('storageAccess.private'),
                onPressed: () => Navigator.of(context).pop('private'),
                child: Text(l10n.storageAccessPrivate),
              ),
              const SizedBox(height: 8),
              TextButton(
                key: const Key('storageAccess.notNow'),
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.storageAccessNotNow),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
