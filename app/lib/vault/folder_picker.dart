// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra/core/platform/platform_providers.dart';
import 'package:tephra/core/platform/storage_permission_service.dart';
import 'package:tephra/l10n/app_localizations.dart';
import 'package:tephra/vault/storage_access_screen.dart';

/// Prompts for Android All Files Access if required, then opens system directory picker.
Future<String?> pickFolderWithAccess(
  BuildContext context,
  WidgetRef ref, {
  bool? isAndroid,
}) async {
  final onAndroid = isAndroid ?? (!kIsWeb && Platform.isAndroid);

  if (onAndroid) {
    final service = ref.read(storagePermissionServiceProvider);
    final status = await service.status();
    if (status != StorageAccess.granted && status != StorageAccess.notNeeded) {
      if (!context.mounted) return null;
      final result = await Navigator.of(context).push<dynamic>(
        MaterialPageRoute(builder: (_) => const StorageAccessScreen()),
      );
      if (result != true) {
        return null;
      }
    }
  }

  final chosen = await FilePicker.getDirectoryPath();
  if (chosen == null) return null;

  if (onAndroid && chosen.startsWith('content://')) {
    if (context.mounted) {
      final l10n = AppLocalizations.of(context);
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.vaultErrorNoAccess),
          content: Text(l10n.vaultErrorNoAccess),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.commonOk),
            ),
          ],
        ),
      );
    }
    return null;
  }

  return chosen;
}
