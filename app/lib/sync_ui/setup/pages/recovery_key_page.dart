// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../providers.dart';

class RecoveryKeyPage extends ConsumerWidget {
  const RecoveryKeyPage({required this.vaultId, super.key});

  final String vaultId;

  Future<void> _saveRecoveryKeyFile(
    BuildContext context,
    String vaultName,
    String recoveryKey,
  ) async {
    final l10n = AppLocalizations.of(context);
    try {
      final defaultFileName = 'tephra-recovery-key-${DateTime.now().year}.txt';
      final content =
          '''
TEPHRA EMERGENCY RECOVERY KEY
Vault: $vaultName
Date: ${DateTime.now().toIso8601String()}

Recovery Key:
$recoveryKey

INSTRUCTIONS:
Store this document in a safe location (e.g. encrypted USB drive or password manager).
If you lose your vault password, this key is the only way to recover access to your synchronized notes.
''';
      final savedUri = await FilePicker.saveFile(
        dialogTitle: l10n.syncSetupRecoveryTitle,
        fileName: defaultFileName,
        bytes: Uint8List.fromList(utf8.encode(content)),
        mimeType: 'text/plain',
      );

      if (savedUri != null && context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.syncSetupKeyCopied)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to save file: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(syncSetupControllerProvider(vaultId));
    final controller = ref.read(syncSetupControllerProvider(vaultId).notifier);

    final key = state.recoveryKeyDisplay ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.vpn_key_outlined, size: 56, color: Colors.amber),
          const SizedBox(height: 12),
          Text(
            l10n.syncSetupRecoveryTitle,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.syncSetupRecoveryExplain,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade700),
            ),
            child: SelectableText(
              key,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.copy),
                label: Text(l10n.syncSetupCopy),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: key));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.syncSetupKeyCopied)),
                  );
                },
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.save_alt),
                label: Text(l10n.syncSetupSaveToFile),
                onPressed: () =>
                    _saveRecoveryKeyFile(context, state.vaultName, key),
              ),
            ],
          ),
          const SizedBox(height: 20),
          CheckboxListTile(
            value: state.recoveryKeySaved,
            title: Text(l10n.syncSetupRecoverySavedCheckbox),
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: (val) => controller.setRecoverySaved(val ?? false),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: state.recoveryKeySaved
                ? controller.advanceToConfirmRecovery
                : null,
            child: Text(l10n.syncSetupContinue),
          ),
        ],
      ),
    );
  }
}
