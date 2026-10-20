// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../providers.dart';

class CreatePasswordPage extends ConsumerStatefulWidget {
  const CreatePasswordPage({required this.vaultId, super.key});

  final String vaultId;

  @override
  ConsumerState<CreatePasswordPage> createState() => _CreatePasswordPageState();
}

class _CreatePasswordPageState extends ConsumerState<CreatePasswordPage> {
  late final TextEditingController _vaultNameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmController;
  late final TextEditingController _deviceController;

  @override
  void initState() {
    super.initState();
    final state = ref.read(syncSetupControllerProvider(widget.vaultId));
    _vaultNameController = TextEditingController(text: state.vaultName);
    _passwordController = TextEditingController(text: state.password);
    _confirmController = TextEditingController(text: state.passwordConfirm);
    _deviceController = TextEditingController(text: state.deviceName);
  }

  @override
  void dispose() {
    _vaultNameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _deviceController.dispose();
    super.dispose();
  }

  Future<void> _handleEncryptToggle(bool value) async {
    final controller = ref.read(
      syncSetupControllerProvider(widget.vaultId).notifier,
    );
    if (!value) {
      final l10n = AppLocalizations.of(context);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.syncSetupEncryptionOffTitle),
          content: Text(l10n.syncSetupEncryptionOffConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.syncSetupKeepEncryption),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.syncSetupTurnOffEncryption),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        controller.setEncrypt(false);
      }
    } else {
      controller.setEncrypt(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(syncSetupControllerProvider(widget.vaultId));
    final controller = ref.read(
      syncSetupControllerProvider(widget.vaultId).notifier,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.syncSetupCreateNew,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _vaultNameController,
            decoration: InputDecoration(
              labelText: l10n.syncSetupVaultName,
              border: const OutlineInputBorder(),
            ),
            onChanged: controller.setVaultName,
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: Text(l10n.syncSetupEncryptToggle),
            subtitle: Text(l10n.syncSetupEncryptSubtitle),
            value: state.encrypt,
            onChanged: state.isLoading ? null : _handleEncryptToggle,
          ),
          if (state.encrypt) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l10n.syncSetupPassword,
                border: const OutlineInputBorder(),
              ),
              onChanged: controller.setPassword,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l10n.syncSetupPasswordConfirm,
                border: const OutlineInputBorder(),
              ),
              onChanged: controller.setPasswordConfirm,
            ),
            const SizedBox(height: 12),
            Card(
              color: Colors.amber.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.syncSetupPasswordWarning,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _deviceController,
            decoration: InputDecoration(
              labelText: l10n.syncSetupDeviceName,
              border: const OutlineInputBorder(),
            ),
            onChanged: controller.setDeviceName,
          ),
          const SizedBox(height: 24),
          if (state.isLoading) ...[
            Center(
              child: Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 8),
                  Text(l10n.syncSetupCreating),
                ],
              ),
            ),
          ] else ...[
            FilledButton(
              onPressed: controller.submitCreatePassword,
              child: Text(l10n.syncSetupCreateAndContinue),
            ),
          ],
          if (state.errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              state.errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
