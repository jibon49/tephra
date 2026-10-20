// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_sync/tephra_sync.dart';

import '../../core/sync/google_auth_service.dart';
import 'sync_setup_service.dart';

/// Steps in the sync setup wizard state machine.
enum SyncSetupStep {
  signIn,
  chooseVault,
  createPassword,
  recoveryKey,
  confirmRecovery,
  unlock,
  firstSyncChoice,
  firstSyncProgress,
  done,
}

/// State of the sync setup wizard.
class SyncSetupState {
  const SyncSetupState({
    this.step = SyncSetupStep.signIn,
    this.isLoading = false,
    this.errorMessage,
    this.account,
    this.remoteVaults = const [],
    this.selectedRemoteVault,
    this.isCreatingNew = true,
    this.vaultName = '',
    this.encrypt = true,
    this.password = '',
    this.passwordConfirm = '',
    this.deviceName = 'Device',
    this.recoveryKeyDisplay,
    this.recoveryKeySaved = false,
    this.recoveryGroup2 = '',
    this.recoveryGroup7 = '',
    this.recoveryError,
    this.unlockPassword = '',
    this.unlockRecoveryKey = '',
    this.useRecoveryKey = false,
    this.localStats = const LocalVaultStats(fileCount: 0, totalBytes: 0),
    this.firstSyncChoice = FirstSyncChoice.merge,
    this.backgroundSync = true,
    this.wifiOnly = true,
    this.mobileMode = true,
    this.progressMessage = '',
    this.progressFraction = 0.0,
    this.createdResult,
    this.report,
    this.dailyBackup = true,
  });

  final SyncSetupStep step;
  final bool isLoading;
  final String? errorMessage;
  final GoogleAccount? account;
  final List<RemoteVaultInfo> remoteVaults;
  final RemoteVaultInfo? selectedRemoteVault;
  final bool isCreatingNew;
  final String vaultName;
  final bool encrypt;
  final String password;
  final String passwordConfirm;
  final String deviceName;
  final String? recoveryKeyDisplay;
  final bool recoveryKeySaved;
  final String recoveryGroup2;
  final String recoveryGroup7;
  final String? recoveryError;
  final String unlockPassword;
  final String unlockRecoveryKey;
  final bool useRecoveryKey;
  final LocalVaultStats localStats;
  final FirstSyncChoice firstSyncChoice;
  final bool backgroundSync;
  final bool wifiOnly;
  final bool mobileMode;
  final String progressMessage;
  final double progressFraction;
  final CreatedVaultResult? createdResult;
  final SyncReport? report;
  final bool dailyBackup;

  SyncSetupState copyWith({
    SyncSetupStep? step,
    bool? isLoading,
    String? Function()? errorMessage,
    GoogleAccount? Function()? account,
    List<RemoteVaultInfo>? remoteVaults,
    RemoteVaultInfo? Function()? selectedRemoteVault,
    bool? isCreatingNew,
    String? vaultName,
    bool? encrypt,
    String? password,
    String? passwordConfirm,
    String? deviceName,
    String? Function()? recoveryKeyDisplay,
    bool? recoveryKeySaved,
    String? recoveryGroup2,
    String? recoveryGroup7,
    String? Function()? recoveryError,
    String? unlockPassword,
    String? unlockRecoveryKey,
    bool? useRecoveryKey,
    LocalVaultStats? localStats,
    FirstSyncChoice? firstSyncChoice,
    bool? backgroundSync,
    bool? wifiOnly,
    bool? mobileMode,
    String? progressMessage,
    double? progressFraction,
    CreatedVaultResult? Function()? createdResult,
    SyncReport? Function()? report,
    bool? dailyBackup,
  }) {
    return SyncSetupState(
      step: step ?? this.step,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      account: account != null ? account() : this.account,
      remoteVaults: remoteVaults ?? this.remoteVaults,
      selectedRemoteVault: selectedRemoteVault != null
          ? selectedRemoteVault()
          : this.selectedRemoteVault,
      isCreatingNew: isCreatingNew ?? this.isCreatingNew,
      vaultName: vaultName ?? this.vaultName,
      encrypt: encrypt ?? this.encrypt,
      password: password ?? this.password,
      passwordConfirm: passwordConfirm ?? this.passwordConfirm,
      deviceName: deviceName ?? this.deviceName,
      recoveryKeyDisplay: recoveryKeyDisplay != null
          ? recoveryKeyDisplay()
          : this.recoveryKeyDisplay,
      recoveryKeySaved: recoveryKeySaved ?? this.recoveryKeySaved,
      recoveryGroup2: recoveryGroup2 ?? this.recoveryGroup2,
      recoveryGroup7: recoveryGroup7 ?? this.recoveryGroup7,
      recoveryError: recoveryError != null
          ? recoveryError()
          : this.recoveryError,
      unlockPassword: unlockPassword ?? this.unlockPassword,
      unlockRecoveryKey: unlockRecoveryKey ?? this.unlockRecoveryKey,
      useRecoveryKey: useRecoveryKey ?? this.useRecoveryKey,
      localStats: localStats ?? this.localStats,
      firstSyncChoice: firstSyncChoice ?? this.firstSyncChoice,
      backgroundSync: backgroundSync ?? this.backgroundSync,
      wifiOnly: wifiOnly ?? this.wifiOnly,
      mobileMode: mobileMode ?? this.mobileMode,
      progressMessage: progressMessage ?? this.progressMessage,
      progressFraction: progressFraction ?? this.progressFraction,
      createdResult: createdResult != null
          ? createdResult()
          : this.createdResult,
      report: report != null ? report() : this.report,
      dailyBackup: dailyBackup ?? this.dailyBackup,
    );
  }
}

/// Controller managing the state transitions and actions in the setup wizard.
class SyncSetupController extends Notifier<SyncSetupState> {
  SyncSetupController(this.vaultId);

  final String vaultId;
  late SyncSetupService _service;

  @override
  SyncSetupState build() {
    return const SyncSetupState();
  }

  /// Sets the backing [SyncSetupService] and checks for active sign-in.
  Future<void> attachService(
    SyncSetupService service, {
    String? initialVaultName,
    String? initialDeviceName,
  }) async {
    _service = service;
    if (initialVaultName != null && initialVaultName.isNotEmpty) {
      state = state.copyWith(vaultName: initialVaultName);
    }
    if (initialDeviceName != null && initialDeviceName.isNotEmpty) {
      state = state.copyWith(deviceName: initialDeviceName);
    }

    state = state.copyWith(isLoading: true);
    try {
      final account = await _service.currentAccount();
      if (account != null) {
        state = state.copyWith(
          account: () => account,
          step: SyncSetupStep.chooseVault,
        );
        await loadRemoteVaults();
      }
    } catch (_) {
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Initiates interactive Google OAuth sign in.
  Future<void> signIn() async {
    state = state.copyWith(isLoading: true, errorMessage: () => null);
    try {
      final account = await _service.signInInteractive();
      state = state.copyWith(
        account: () => account,
        step: SyncSetupStep.chooseVault,
      );
      await loadRemoteVaults();
    } catch (e) {
      state = state.copyWith(errorMessage: () => e.toString());
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Signs out of the active Google account.
  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    try {
      await _service.signOut();
      state = state.copyWith(
        account: () => null,
        step: SyncSetupStep.signIn,
        remoteVaults: const [],
      );
    } catch (e) {
      state = state.copyWith(errorMessage: () => e.toString());
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Refreshes the list of remote vaults from Google Drive.
  Future<void> loadRemoteVaults() async {
    state = state.copyWith(isLoading: true, errorMessage: () => null);
    try {
      final vaults = await _service.listRemoteVaults();
      state = state.copyWith(remoteVaults: vaults);
    } catch (e) {
      state = state.copyWith(errorMessage: () => e.toString());
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Chooses to create a new remote vault.
  void selectCreateNew() {
    state = state.copyWith(
      isCreatingNew: true,
      selectedRemoteVault: () => null,
      step: SyncSetupStep.createPassword,
      errorMessage: () => null,
    );
  }

  /// Chooses an existing remote vault to connect to.
  Future<void> selectExistingVault(RemoteVaultInfo vault) async {
    state = state.copyWith(
      isCreatingNew: false,
      selectedRemoteVault: () => vault,
      vaultName: vault.vaultName,
      encrypt: vault.encrypted,
      errorMessage: () => null,
    );

    if (vault.encrypted) {
      state = state.copyWith(step: SyncSetupStep.unlock);
    } else {
      await _prepareFirstSyncChoice();
    }
  }

  Future<void> _prepareFirstSyncChoice() async {
    state = state.copyWith(isLoading: true);
    try {
      final stats = await _service.getLocalVaultStats();
      final defaultChoice = state.isCreatingNew
          ? FirstSyncChoice.upload
          : (stats.fileCount == 0
                ? FirstSyncChoice.download
                : FirstSyncChoice.merge);

      state = state.copyWith(
        localStats: stats,
        firstSyncChoice: defaultChoice,
        step: SyncSetupStep.firstSyncChoice,
      );
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  void setVaultName(String name) => state = state.copyWith(vaultName: name);
  void setEncrypt(bool encrypt) => state = state.copyWith(encrypt: encrypt);
  void setPassword(String p) => state = state.copyWith(password: p);
  void setPasswordConfirm(String c) =>
      state = state.copyWith(passwordConfirm: c);
  void setDeviceName(String d) => state = state.copyWith(deviceName: d);
  void setRecoverySaved(bool saved) =>
      state = state.copyWith(recoveryKeySaved: saved);
  void setRecoveryGroup2(String g2) =>
      state = state.copyWith(recoveryGroup2: g2);
  void setRecoveryGroup7(String g7) =>
      state = state.copyWith(recoveryGroup7: g7);
  void setUnlockPassword(String p) => state = state.copyWith(unlockPassword: p);
  void setUnlockRecoveryKey(String r) =>
      state = state.copyWith(unlockRecoveryKey: r);
  void setUseRecoveryKey(bool use) =>
      state = state.copyWith(useRecoveryKey: use);
  void setFirstSyncChoice(FirstSyncChoice c) =>
      state = state.copyWith(firstSyncChoice: c);
  void setBackgroundSync(bool b) => state = state.copyWith(backgroundSync: b);
  void setWifiOnly(bool w) => state = state.copyWith(wifiOnly: w);
  void setMobileMode(bool m) => state = state.copyWith(mobileMode: m);
  void setDailyBackup(bool d) => state = state.copyWith(dailyBackup: d);

  /// Submits creation of a new remote vault.
  Future<void> submitCreatePassword() async {
    if (state.encrypt) {
      if (state.password.length < 10) {
        state = state.copyWith(
          errorMessage: () => 'Password must be at least 10 characters',
        );
        return;
      }
      if (state.password != state.passwordConfirm) {
        state = state.copyWith(errorMessage: () => 'Passwords do not match');
        return;
      }
    }

    state = state.copyWith(isLoading: true, errorMessage: () => null);
    try {
      final device = DeviceIdentity(
        deviceId: generateUuidV4(),
        deviceName: state.deviceName.isNotEmpty ? state.deviceName : 'Device',
        platform: 'windows',
      );

      final result = await _service.createRemoteVault(
        vaultName: state.vaultName.isNotEmpty ? state.vaultName : 'Vault',
        encrypted: state.encrypt,
        password: state.encrypt ? state.password : null,
        device: device,
      );

      state = state.copyWith(createdResult: () => result);

      if (state.encrypt && result.recoveryKeyDisplay != null) {
        state = state.copyWith(
          recoveryKeyDisplay: () => result.recoveryKeyDisplay,
          step: SyncSetupStep.recoveryKey,
        );
      } else {
        await _prepareFirstSyncChoice();
      }
    } catch (e) {
      state = state.copyWith(errorMessage: () => e.toString());
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Advances from recovery key view to confirmation.
  void advanceToConfirmRecovery() {
    state = state.copyWith(
      step: SyncSetupStep.confirmRecovery,
      recoveryError: () => null,
      recoveryGroup2: '',
      recoveryGroup7: '',
    );
  }

  /// Verifies recovery groups 2 and 7.
  Future<void> submitConfirmRecovery() async {
    final key = state.recoveryKeyDisplay;
    if (key == null) return;

    final groups = key.split('-');
    if (groups.length >= 7) {
      final expectedG2 = groups[1].toUpperCase();
      final expectedG7 = groups[6].toUpperCase();

      if (state.recoveryGroup2.trim().toUpperCase() != expectedG2 ||
          state.recoveryGroup7.trim().toUpperCase() != expectedG7) {
        state = state.copyWith(
          recoveryError: () =>
              'The entered groups do not match your recovery key.',
        );
        return;
      }
    }

    await _prepareFirstSyncChoice();
  }

  /// Unlocks an existing remote vault with password or recovery key.
  Future<void> submitUnlock() async {
    final vault = state.selectedRemoteVault;
    if (vault == null) return;

    state = state.copyWith(isLoading: true, errorMessage: () => null);
    try {
      final device = DeviceIdentity(
        deviceId: generateUuidV4(),
        deviceName: state.deviceName.isNotEmpty ? state.deviceName : 'Device',
        platform: 'windows',
      );

      await _service.unlockRemoteVault(
        remoteVaultId: vault.vaultId,
        vaultName: vault.vaultName,
        encrypted: vault.encrypted,
        password: state.useRecoveryKey ? null : state.unlockPassword,
        recoveryKey: state.useRecoveryKey ? state.unlockRecoveryKey : null,
        device: device,
      );

      await _prepareFirstSyncChoice();
    } catch (e) {
      state = state.copyWith(
        errorMessage: () => 'Incorrect password or recovery key',
      );
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Finalizes setup and kicks off the initial sync cycle.
  Future<void> startFirstSync({String? newFolderPath}) async {
    state = state.copyWith(
      step: SyncSetupStep.firstSyncProgress,
      isLoading: true,
      errorMessage: () => null,
      progressMessage: 'Initializing first sync…',
      progressFraction: 0.1,
    );

    try {
      final remoteVaultId = state.isCreatingNew
          ? state.createdResult!.remoteVaultId
          : state.selectedRemoteVault!.vaultId;
      final vaultName = state.vaultName;
      final encrypted = state.encrypt;

      final device = DeviceIdentity(
        deviceId: generateUuidV4(),
        deviceName: state.deviceName,
        platform: 'windows',
      );

      await _service.finalizeSetup(
        remoteVaultId: remoteVaultId,
        vaultName: vaultName,
        encrypted: encrypted,
        backgroundSync: state.backgroundSync,
        wifiOnly: state.wifiOnly,
        mobileMode: state.mobileMode,
        device: device,
        choice: state.firstSyncChoice,
        newFolderPath: newFolderPath,
      );

      state = state.copyWith(
        progressMessage: 'Syncing files…',
        progressFraction: 0.8,
      );

      // Transition to done
      state = state.copyWith(
        step: SyncSetupStep.done,
        isLoading: false,
        report: () => const SyncReport(duration: Duration(seconds: 1)),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: () => e.toString(),
      );
    }
  }

  /// Navigates to the logical previous step.
  void back() {
    switch (state.step) {
      case SyncSetupStep.signIn:
        break;
      case SyncSetupStep.chooseVault:
        state = state.copyWith(step: SyncSetupStep.signIn);
      case SyncSetupStep.createPassword:
        state = state.copyWith(step: SyncSetupStep.chooseVault);
      case SyncSetupStep.recoveryKey:
        state = state.copyWith(step: SyncSetupStep.createPassword);
      case SyncSetupStep.confirmRecovery:
        state = state.copyWith(step: SyncSetupStep.recoveryKey);
      case SyncSetupStep.unlock:
        state = state.copyWith(step: SyncSetupStep.chooseVault);
      case SyncSetupStep.firstSyncChoice:
        if (state.isCreatingNew) {
          state = state.copyWith(
            step: state.encrypt
                ? SyncSetupStep.confirmRecovery
                : SyncSetupStep.createPassword,
          );
        } else {
          state = state.copyWith(
            step: state.encrypt
                ? SyncSetupStep.unlock
                : SyncSetupStep.chooseVault,
          );
        }
      case SyncSetupStep.firstSyncProgress:
        break;
      case SyncSetupStep.done:
        break;
    }
  }

  /// Disconnects sync for this vault and optionally signs out of Google.
  Future<void> disconnect({required bool signOutGoogle}) async {
    state = state.copyWith(isLoading: true);
    try {
      await _service.disconnect(signOutGoogle: signOutGoogle);
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }
}
