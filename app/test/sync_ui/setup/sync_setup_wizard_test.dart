// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/core/sync/google_auth_service.dart';
import 'package:tephra/l10n/app_localizations.dart';
import 'package:tephra/settings/settings_screen.dart';
import 'package:tephra/sync_ui/providers.dart';
import 'package:tephra/sync_ui/setup/pages/choose_vault_page.dart';
import 'package:tephra/sync_ui/setup/pages/confirm_recovery_page.dart';
import 'package:tephra/sync_ui/setup/pages/create_password_page.dart';
import 'package:tephra/sync_ui/setup/pages/done_page.dart';
import 'package:tephra/sync_ui/setup/pages/first_sync_choice_page.dart';
import 'package:tephra/sync_ui/setup/pages/recovery_key_page.dart';
import 'package:tephra/sync_ui/setup/pages/sign_in_page.dart';
import 'package:tephra/sync_ui/setup/pages/unlock_page.dart';
import 'package:tephra/sync_ui/setup/sync_setup_wizard.dart';
import 'package:tephra_sync/tephra_sync.dart';

import '../../helpers/test_app.dart';

class FakeSyncSetupService implements SyncSetupService {
  FakeSyncSetupService({
    this.account,
    this.remoteVaults = const [],
    this.localStats = const LocalVaultStats(fileCount: 5, totalBytes: 1024),
    this.shouldFailUnlock = false,
  });

  GoogleAccount? account;
  int signInCount = 0;
  List<RemoteVaultInfo> remoteVaults;
  LocalVaultStats localStats;
  bool shouldFailUnlock;
  bool isFinalized = false;
  bool isDisconnected = false;
  FirstSyncChoice? lastChoice;
  String? createdPassword;
  String? createdVaultName;

  @override
  Future<GoogleAccount?> currentAccount() async => account;

  @override
  Future<GoogleAccount> signInInteractive() async {
    signInCount++;
    account = const GoogleAccount(
      email: 'test@example.com',
      displayName: 'Test User',
    );
    return account!;
  }

  @override
  Future<void> signOut() async {
    account = null;
  }

  @override
  Future<List<RemoteVaultInfo>> listRemoteVaults() async => remoteVaults;

  @override
  Future<CreatedVaultResult> createRemoteVault({
    required String vaultName,
    required bool encrypted,
    String? password,
    required DeviceIdentity device,
  }) async {
    createdVaultName = vaultName;
    createdPassword = password;
    return CreatedVaultResult(
      remoteVaultId: 'test-remote-vault-id',
      vaultName: vaultName,
      encrypted: encrypted,
      recoveryKeyDisplay: 'ABCD-EFGH-IJKL-MNOP-QRST-UVWX-YZ23-4567',
    );
  }

  @override
  Future<void> unlockRemoteVault({
    required String remoteVaultId,
    required String vaultName,
    required bool encrypted,
    String? password,
    String? recoveryKey,
    required DeviceIdentity device,
  }) async {
    if (shouldFailUnlock) {
      throw const WrongPasswordException();
    }
  }

  @override
  Future<LocalVaultStats> getLocalVaultStats() async => localStats;

  @override
  Future<void> finalizeSetup({
    required String remoteVaultId,
    required String vaultName,
    required bool encrypted,
    required bool backgroundSync,
    required bool wifiOnly,
    required bool mobileMode,
    required DeviceIdentity device,
    required FirstSyncChoice choice,
    String? newFolderPath,
  }) async {
    isFinalized = true;
    lastChoice = choice;
  }

  @override
  Future<void> disconnect({required bool signOutGoogle}) async {
    isDisconnected = true;
    if (signOutGoogle) account = null;
  }

  @override
  Future<bool> isConfigured() async => isFinalized;
}

void main() {
  const vaultPath = '/memory/vault';

  group('SyncSetupWizard', () {
    testWidgets(
      'full create path: sign in -> password -> recovery -> confirm -> first sync -> done',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1200, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final fake = FakeSyncSetupService();

        await tester.pumpWidget(
          testApp(
            const SyncSetupWizardScreen(
              vaultId: 'vault-create',
              localVaultRootPath: vaultPath,
            ),
            overrides: [
              syncSetupServiceProvider.overrideWith((ref, arg) => fake),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // 1. Sign In Page
        expect(find.byType(SignInPage), findsOneWidget);
        expect(find.text('Sign in with Google'), findsOneWidget);

        await tester.tap(find.text('Sign in with Google'));
        await tester.pumpAndSettle();

        // 2. Choose Vault Page
        expect(find.byType(ChooseVaultPage), findsOneWidget);
        expect(find.text('Create a new remote vault'), findsOneWidget);

        await tester.tap(find.text('Create a new remote vault'));
        await tester.pumpAndSettle();

        // 3. Create Password Page
        expect(find.byType(CreatePasswordPage), findsOneWidget);
        final l10n = lookupAppLocalizations(const Locale('en'));

        // Test short password validation
        final passwordField = find.widgetWithText(
          TextField,
          l10n.syncSetupPassword,
        );
        final confirmField = find.widgetWithText(
          TextField,
          l10n.syncSetupPasswordConfirm,
        );
        final createButton = find.text(l10n.syncSetupCreateAndContinue);

        await tester.enterText(passwordField, 'short');
        await tester.enterText(confirmField, 'short');
        await tester.ensureVisible(createButton);
        await tester.tap(createButton);
        await tester.pumpAndSettle();
        expect(find.text(l10n.syncSetupPasswordTooShort), findsOneWidget);

        // Test password mismatch
        await tester.enterText(passwordField, 'validpassword123');
        await tester.enterText(confirmField, 'mismatchpassword123');
        await tester.ensureVisible(createButton);
        await tester.tap(createButton);
        await tester.pumpAndSettle();
        expect(find.text(l10n.syncSetupPasswordMismatch), findsOneWidget);

        // Enter matching valid password
        await tester.enterText(confirmField, 'validpassword123');
        await tester.ensureVisible(createButton);
        await tester.tap(createButton);
        await tester.pumpAndSettle();

        // 4. Recovery Key Page
        expect(find.byType(RecoveryKeyPage), findsOneWidget);
        expect(
          find.text('ABCD-EFGH-IJKL-MNOP-QRST-UVWX-YZ23-4567'),
          findsOneWidget,
        );

        // Continue button should be disabled until checkbox is checked
        final continueBtnFinder = find.widgetWithText(
          FilledButton,
          l10n.syncSetupContinue,
        );
        final continueBtn = tester.widget<FilledButton>(continueBtnFinder);
        expect(continueBtn.onPressed, isNull);

        // Check the recovery saved checkbox
        final checkboxFinder = find.byType(CheckboxListTile);
        await tester.ensureVisible(checkboxFinder);
        await tester.tap(checkboxFinder);
        await tester.pumpAndSettle();

        final continueBtnEnabled = tester.widget<FilledButton>(
          continueBtnFinder,
        );
        expect(continueBtnEnabled.onPressed, isNotNull);

        await tester.ensureVisible(continueBtnFinder);
        await tester.tap(continueBtnFinder);
        await tester.pumpAndSettle();

        // 5. Confirm Recovery Page
        expect(find.byType(ConfirmRecoveryPage), findsOneWidget);

        final group2Field = find.widgetWithText(
          TextField,
          l10n.syncSetupConfirmRecoveryGroup(2),
        );
        final group7Field = find.widgetWithText(
          TextField,
          l10n.syncSetupConfirmRecoveryGroup(7),
        );
        final verifyBtnFinder = find.widgetWithText(
          FilledButton,
          l10n.syncSetupVerifyAndContinue,
        );

        // Enter wrong confirmation
        await tester.enterText(group2Field, 'WRON');
        await tester.enterText(group7Field, 'XXXX');
        await tester.pump();
        await tester.ensureVisible(verifyBtnFinder);
        await tester.tap(verifyBtnFinder);
        await tester.pumpAndSettle();
        expect(find.text(l10n.syncSetupConfirmRecoveryWrong), findsOneWidget);

        // Enter correct groups (2 = EFGH, 7 = YZ23)
        await tester.enterText(group2Field, 'efgh');
        await tester.enterText(group7Field, 'yz23');
        await tester.pump();
        await tester.ensureVisible(verifyBtnFinder);
        await tester.tap(verifyBtnFinder);
        await tester.pumpAndSettle();

        // 6. First Sync Choice Page (new remote -> upload option)
        expect(find.byType(FirstSyncChoicePage), findsOneWidget);
        expect(
          find.text(l10n.syncSetupUploadOption(5, '1.0 KB')),
          findsOneWidget,
        );

        final startSyncBtn = find.widgetWithText(
          FilledButton,
          l10n.syncSetupStartSync,
        );
        await tester.ensureVisible(startSyncBtn);
        await tester.tap(startSyncBtn);
        await tester.pumpAndSettle();

        // 7. Done Page
        expect(find.byType(DonePage), findsOneWidget);
        expect(fake.isFinalized, isTrue);
        expect(find.text(l10n.syncSetupDoneTitle), findsOneWidget);
      },
    );

    testWidgets(
      'connect path: unlock with wrong password then correct password',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1200, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final fake = FakeSyncSetupService(
          account: const GoogleAccount(
            email: 'test@example.com',
            displayName: 'Test',
          ),
          remoteVaults: [
            RemoteVaultInfo(
              vaultId: 'remote-1',
              vaultName: 'Existing Vault',
              createdAt: DateTime(2026, 1, 1),
              createdByDeviceName: 'Pixel',
              encrypted: true,
              folderId: 'folder-1',
            ),
          ],
          shouldFailUnlock: true,
        );

        await tester.pumpWidget(
          testApp(
            const SyncSetupWizardScreen(
              vaultId: 'vault-connect',
              localVaultRootPath: vaultPath,
            ),
            overrides: [
              syncSetupServiceProvider.overrideWith((ref, arg) => fake),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Already signed in -> starts at ChooseVaultPage
        expect(find.byType(ChooseVaultPage), findsOneWidget);
        expect(find.text('Existing Vault'), findsOneWidget);

        await tester.tap(find.text('Existing Vault'));
        await tester.pumpAndSettle();

        // Unlock Page
        expect(find.byType(UnlockPage), findsOneWidget);
        final l10n = lookupAppLocalizations(const Locale('en'));

        final unlockPassword = find.widgetWithText(
          TextField,
          l10n.syncSetupPassword,
        );
        final unlockBtn = find.widgetWithText(
          FilledButton,
          l10n.syncSetupUnlockButton,
        );

        await tester.enterText(unlockPassword, 'wrongpassword');
        await tester.ensureVisible(unlockBtn);
        await tester.tap(unlockBtn);
        await tester.pumpAndSettle();

        // Should show wrong password error and remain on UnlockPage
        expect(find.text(l10n.syncErrorWrongPassword), findsOneWidget);
        expect(find.byType(UnlockPage), findsOneWidget);

        // Now set shouldFailUnlock to false and retry
        fake.shouldFailUnlock = false;
        await tester.enterText(unlockPassword, 'correctpassword');
        await tester.ensureVisible(unlockBtn);
        await tester.tap(unlockBtn);
        await tester.pumpAndSettle();

        // Advances to FirstSyncChoicePage
        expect(find.byType(FirstSyncChoicePage), findsOneWidget);
      },
    );

    testWidgets('first sync options: empty local shows download only', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final l10n = lookupAppLocalizations(const Locale('en'));

      final fakeEmpty = FakeSyncSetupService(
        account: const GoogleAccount(email: 'test@example.com'),
        remoteVaults: [
          RemoteVaultInfo(
            vaultId: 'remote-empty',
            vaultName: 'Existing Vault',
            createdAt: DateTime(2026, 1, 1),
            createdByDeviceName: 'Pixel',
            encrypted: false,
            folderId: 'folder-1',
          ),
        ],
        localStats: const LocalVaultStats(fileCount: 0, totalBytes: 0),
      );

      await tester.pumpWidget(
        testApp(
          const SyncSetupWizardScreen(
            vaultId: 'vault-empty',
            localVaultRootPath: vaultPath,
          ),
          overrides: [
            syncSetupServiceProvider.overrideWith((ref, arg) => fakeEmpty),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Existing Vault'), findsOneWidget);
      await tester.tap(find.text('Existing Vault'));
      await tester.pumpAndSettle();

      // Empty local -> download option only
      expect(find.byType(FirstSyncChoicePage), findsOneWidget);
      expect(find.text(l10n.syncSetupDownloadOption), findsOneWidget);
      expect(find.text(l10n.syncSetupMergeOption), findsNothing);
    });

    testWidgets(
      'first sync options: non-empty shows merge + new folder; no destructive option',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1200, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final l10n = lookupAppLocalizations(const Locale('en'));

        final fakeNonEmpty = FakeSyncSetupService(
          account: const GoogleAccount(email: 'test@example.com'),
          remoteVaults: [
            RemoteVaultInfo(
              vaultId: 'remote-non-empty',
              vaultName: 'Existing Vault',
              createdAt: DateTime(2026, 1, 1),
              createdByDeviceName: 'Pixel',
              encrypted: false,
              folderId: 'folder-1',
            ),
          ],
          localStats: const LocalVaultStats(fileCount: 10, totalBytes: 2048),
        );

        await tester.pumpWidget(
          testApp(
            const SyncSetupWizardScreen(
              vaultId: 'vault-non-empty',
              localVaultRootPath: vaultPath,
            ),
            overrides: [
              syncSetupServiceProvider.overrideWith((ref, arg) => fakeNonEmpty),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Existing Vault'), findsOneWidget);
        await tester.tap(find.text('Existing Vault'));
        await tester.pumpAndSettle();

        expect(find.text(l10n.syncSetupMergeOption), findsOneWidget);
        expect(find.text(l10n.syncSetupNewFolderOption), findsOneWidget);

        // Verify NO destructive option exists
        expect(find.textContaining('Replace local'), findsNothing);
        expect(find.textContaining('Delete local'), findsNothing);
        expect(find.textContaining('Overwrite'), findsNothing);
      },
    );

    testWidgets(
      'responsive rendering: dialog on desktop (>=840dp) and screen on phone (<840dp)',
      (tester) async {
        final fake = FakeSyncSetupService();

        // Phone width: 400 dp
        await tester.binding.setSurfaceSize(const Size(400, 800));
        await tester.pumpWidget(
          testApp(
            Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => showSyncSetupWizard(
                  ctx,
                  vaultId: 'vault-phone',
                  localVaultRootPath: vaultPath,
                ),
                child: const Text('Open'),
              ),
            ),
            size: const Size(400, 800),
            overrides: [
              syncSetupServiceProvider.overrideWith((ref, arg) => fake),
            ],
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.byType(SyncSetupWizardScreen), findsOneWidget);
        expect(find.byType(SyncSetupWizardDialog), findsNothing);

        // Dismiss
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        // Desktop width: 1200 dp
        await tester.binding.setSurfaceSize(const Size(1200, 800));
        await tester.pumpWidget(
          testApp(
            Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => showSyncSetupWizard(
                  ctx,
                  vaultId: 'vault-desktop',
                  localVaultRootPath: vaultPath,
                ),
                child: const Text('Open'),
              ),
            ),
            size: const Size(1200, 800),
            overrides: [
              syncSetupServiceProvider.overrideWith((ref, arg) => fake),
            ],
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.byType(SyncSetupWizardDialog), findsOneWidget);
        addTearDown(() => tester.binding.setSurfaceSize(null));
      },
    );

    testWidgets('settings screen: unconfigured shows set up sync card', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final l10n = lookupAppLocalizations(const Locale('en'));
      final fake = FakeSyncSetupService();

      await tester.pumpWidget(
        testApp(
          const SettingsScreen(),
          overrides: [
            syncSetupServiceProvider.overrideWith((ref, arg) => fake),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Drag list down to reveal Sync & backup section
      for (var i = 0; i < 6; i++) {
        if (find.text(l10n.syncSettingsTitle).evaluate().isNotEmpty) break;
        await tester.drag(find.byType(ListView), const Offset(0, -500));
        await tester.pumpAndSettle();
      }

      // Sync & backup section shows Set up sync button when unconfigured
      expect(find.text(l10n.syncSettingsTitle), findsAtLeastNWidgets(1));
      expect(find.text(l10n.syncSetupAction), findsOneWidget);
    });

    testWidgets(
      'settings screen: configured shows syncing status and disconnect action',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1200, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final l10n = lookupAppLocalizations(const Locale('en'));
        final fake = FakeSyncSetupService()..isFinalized = true;

        await tester.pumpWidget(
          testApp(
            const SettingsScreen(),
            overrides: [
              syncSetupServiceProvider.overrideWith((ref, arg) => fake),
            ],
          ),
        );
        await tester.pumpAndSettle();

        for (var i = 0; i < 6; i++) {
          if (find
              .text(l10n.syncSettingsConfiguredStatus)
              .evaluate()
              .isNotEmpty) {
            break;
          }
          await tester.drag(find.byType(ListView), const Offset(0, -500));
          await tester.pumpAndSettle();
        }
        await tester.drag(find.byType(ListView), const Offset(0, -300));
        await tester.pumpAndSettle();

        expect(find.text(l10n.syncSettingsConfiguredStatus), findsOneWidget);
        final disconnectBtn = find.widgetWithText(
          OutlinedButton,
          l10n.syncDisconnect,
        );
        expect(disconnectBtn, findsOneWidget);

        await tester.ensureVisible(disconnectBtn);
        await tester.tap(disconnectBtn);
        await tester.pumpAndSettle();

        // Disconnect confirmation dialog
        expect(find.text(l10n.syncDisconnectConfirm), findsOneWidget);
        expect(find.text(l10n.syncDisconnectAlsoSignOut), findsOneWidget);

        // Confirm disconnect
        final confirmBtn = find.widgetWithText(
          FilledButton,
          l10n.syncDisconnect,
        );
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();

        expect(fake.isDisconnected, isTrue);
      },
    );
  });
}
