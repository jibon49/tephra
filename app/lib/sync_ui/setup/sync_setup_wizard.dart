// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../l10n/app_localizations.dart';
import '../../settings/providers.dart';
import '../providers.dart';
import 'pages/choose_vault_page.dart';
import 'pages/confirm_recovery_page.dart';
import 'pages/create_password_page.dart';
import 'pages/done_page.dart';
import 'pages/first_sync_choice_page.dart';
import 'pages/first_sync_progress_page.dart';
import 'pages/recovery_key_page.dart';
import 'pages/sign_in_page.dart';
import 'pages/unlock_page.dart';

/// Shows the sync setup wizard as a dialog on desktop (>= 840 dp) or full-screen route on phone (< 840 dp).
Future<void> showSyncSetupWizard(
  BuildContext context, {
  required String vaultId,
  required String localVaultRootPath,
}) async {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= 840) {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: 560,
          child: SyncSetupWizardDialog(
            vaultId: vaultId,
            localVaultRootPath: localVaultRootPath,
          ),
        ),
      ),
    );
  } else {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => SyncSetupWizardScreen(
          vaultId: vaultId,
          localVaultRootPath: localVaultRootPath,
        ),
      ),
    );
  }
}

/// Full-screen sync setup wizard for mobile layout.
class SyncSetupWizardScreen extends ConsumerStatefulWidget {
  const SyncSetupWizardScreen({
    required this.vaultId,
    required this.localVaultRootPath,
    super.key,
  });

  final String vaultId;
  final String localVaultRootPath;

  @override
  ConsumerState<SyncSetupWizardScreen> createState() =>
      _SyncSetupWizardScreenState();
}

class _SyncSetupWizardScreenState extends ConsumerState<SyncSetupWizardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final service = ref.read(
        syncSetupServiceProvider((
          vaultId: widget.vaultId,
          localVaultRootPath: widget.localVaultRootPath,
        )),
      );
      final appSettings = ref.read(appSettingsProvider);
      final vaultName = p.basename(widget.localVaultRootPath);
      ref
          .read(syncSetupControllerProvider(widget.vaultId).notifier)
          .attachService(
            service,
            initialVaultName: vaultName,
            initialDeviceName: appSettings.deviceName,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(syncSetupControllerProvider(widget.vaultId));
    final controller = ref.read(
      syncSetupControllerProvider(widget.vaultId).notifier,
    );

    final showBack =
        state.step != SyncSetupStep.signIn &&
        state.step != SyncSetupStep.firstSyncProgress &&
        state.step != SyncSetupStep.done;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.syncSetupTitle),
        leading: showBack
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: controller.back,
              )
            : null,
        actions: [
          if (state.step != SyncSetupStep.firstSyncProgress &&
              state.step != SyncSetupStep.done)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
        ],
      ),
      body: SafeArea(child: _WizardBody(vaultId: widget.vaultId)),
    );
  }
}

/// Modal dialog sync setup wizard for desktop layout.
class SyncSetupWizardDialog extends ConsumerStatefulWidget {
  const SyncSetupWizardDialog({
    required this.vaultId,
    required this.localVaultRootPath,
    super.key,
  });

  final String vaultId;
  final String localVaultRootPath;

  @override
  ConsumerState<SyncSetupWizardDialog> createState() =>
      _SyncSetupWizardDialogState();
}

class _SyncSetupWizardDialogState extends ConsumerState<SyncSetupWizardDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final service = ref.read(
        syncSetupServiceProvider((
          vaultId: widget.vaultId,
          localVaultRootPath: widget.localVaultRootPath,
        )),
      );
      final appSettings = ref.read(appSettingsProvider);
      final vaultName = p.basename(widget.localVaultRootPath);
      ref
          .read(syncSetupControllerProvider(widget.vaultId).notifier)
          .attachService(
            service,
            initialVaultName: vaultName,
            initialDeviceName: appSettings.deviceName,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(syncSetupControllerProvider(widget.vaultId));
    final controller = ref.read(
      syncSetupControllerProvider(widget.vaultId).notifier,
    );

    final showBack =
        state.step != SyncSetupStep.signIn &&
        state.step != SyncSetupStep.firstSyncProgress &&
        state.step != SyncSetupStep.done;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (showBack)
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: controller.back,
                )
              else
                const SizedBox(width: 48),
              Text(
                l10n.syncSetupTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (state.step != SyncSetupStep.firstSyncProgress &&
                  state.step != SyncSetupStep.done)
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                )
              else
                const SizedBox(width: 48),
            ],
          ),
        ),
        const Divider(height: 1),
        Flexible(child: _WizardBody(vaultId: widget.vaultId)),
      ],
    );
  }
}

class _WizardBody extends ConsumerWidget {
  const _WizardBody({required this.vaultId});

  final String vaultId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(syncSetupControllerProvider(vaultId));

    switch (state.step) {
      case SyncSetupStep.signIn:
        return SignInPage(vaultId: vaultId);
      case SyncSetupStep.chooseVault:
        return ChooseVaultPage(vaultId: vaultId);
      case SyncSetupStep.createPassword:
        return CreatePasswordPage(vaultId: vaultId);
      case SyncSetupStep.recoveryKey:
        return RecoveryKeyPage(vaultId: vaultId);
      case SyncSetupStep.confirmRecovery:
        return ConfirmRecoveryPage(vaultId: vaultId);
      case SyncSetupStep.unlock:
        return UnlockPage(vaultId: vaultId);
      case SyncSetupStep.firstSyncChoice:
        return FirstSyncChoicePage(vaultId: vaultId);
      case SyncSetupStep.firstSyncProgress:
        return FirstSyncProgressPage(vaultId: vaultId);
      case SyncSetupStep.done:
        return DonePage(vaultId: vaultId);
    }
  }
}
