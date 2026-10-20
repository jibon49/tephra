// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../providers.dart';

class ConfirmRecoveryPage extends ConsumerStatefulWidget {
  const ConfirmRecoveryPage({required this.vaultId, super.key});

  final String vaultId;

  @override
  ConsumerState<ConfirmRecoveryPage> createState() =>
      _ConfirmRecoveryPageState();
}

class _ConfirmRecoveryPageState extends ConsumerState<ConfirmRecoveryPage> {
  late final TextEditingController _group2Controller;
  late final TextEditingController _group7Controller;

  @override
  void initState() {
    super.initState();
    final state = ref.read(syncSetupControllerProvider(widget.vaultId));
    _group2Controller = TextEditingController(text: state.recoveryGroup2);
    _group7Controller = TextEditingController(text: state.recoveryGroup7);
  }

  @override
  void dispose() {
    _group2Controller.dispose();
    _group7Controller.dispose();
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
          const Icon(
            Icons.verified_user_outlined,
            size: 56,
            color: Colors.blue,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.syncSetupConfirmRecoveryTitle,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.syncSetupConfirmRecoveryExplain,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _group2Controller,
                  maxLength: 4,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: l10n.syncSetupConfirmRecoveryGroup(2),
                    border: const OutlineInputBorder(),
                    counterText: '',
                  ),
                  onChanged: controller.setRecoveryGroup2,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _group7Controller,
                  maxLength: 4,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: l10n.syncSetupConfirmRecoveryGroup(7),
                    border: const OutlineInputBorder(),
                    counterText: '',
                  ),
                  onChanged: controller.setRecoveryGroup7,
                ),
              ),
            ],
          ),
          if (state.recoveryError != null) ...[
            const SizedBox(height: 12),
            Text(
              l10n.syncSetupConfirmRecoveryWrong,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: controller.back,
              child: Text(l10n.syncSetupShowKeyAgain),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed:
                (state.recoveryGroup2.length == 4 &&
                    state.recoveryGroup7.length == 4)
                ? controller.submitConfirmRecovery
                : null,
            child: Text(l10n.syncSetupVerifyAndContinue),
          ),
        ],
      ),
    );
  }
}
