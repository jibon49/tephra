// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../providers.dart';

class UnlockPage extends ConsumerStatefulWidget {
  const UnlockPage({required this.vaultId, super.key});

  final String vaultId;

  @override
  ConsumerState<UnlockPage> createState() => _UnlockPageState();
}

class _UnlockPageState extends ConsumerState<UnlockPage> {
  late final TextEditingController _passwordController;
  late final TextEditingController _recoveryKeyController;
  late final TextEditingController _deviceController;

  @override
  void initState() {
    super.initState();
    final state = ref.read(syncSetupControllerProvider(widget.vaultId));
    _passwordController = TextEditingController(text: state.unlockPassword);
    _recoveryKeyController = TextEditingController(
      text: state.unlockRecoveryKey,
    );
    _deviceController = TextEditingController(text: state.deviceName);
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _recoveryKeyController.dispose();
    _deviceController.dispose();
    super.dispose();
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
          const Icon(Icons.lock_outline, size: 56, color: Colors.amber),
          const SizedBox(height: 12),
          Text(
            l10n.syncSetupUnlockTitle,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            state.vaultName,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (!state.useRecoveryKey) ...[
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l10n.syncSetupPassword,
                border: const OutlineInputBorder(),
              ),
              onChanged: controller.setUnlockPassword,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => controller.setUseRecoveryKey(true),
                child: Text(l10n.syncSetupUseRecoveryKey),
              ),
            ),
          ] else ...[
            TextField(
              controller: _recoveryKeyController,
              decoration: InputDecoration(
                labelText: l10n.syncSetupRecoveryKeyLabel,
                hintText: l10n.syncSetupRecoveryKeyHint,
                border: const OutlineInputBorder(),
              ),
              onChanged: controller.setUnlockRecoveryKey,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => controller.setUseRecoveryKey(false),
                child: Text(l10n.syncSetupUsePassword),
              ),
            ),
          ],
          const SizedBox(height: 12),
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
            const Center(child: CircularProgressIndicator()),
          ] else ...[
            FilledButton(
              onPressed: controller.submitUnlock,
              child: Text(l10n.syncSetupUnlockButton),
            ),
          ],
          if (state.errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              state.useRecoveryKey
                  ? l10n.syncErrorWrongRecoveryKey
                  : l10n.syncErrorWrongPassword,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
