// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/core/platform/platform_providers.dart';
import 'package:tephra/core/platform/storage_permission_service.dart';
import 'package:tephra/settings/app_settings.dart';
import 'package:tephra/vault/create_vault_dialog.dart';
import 'package:tephra/vault/vault_picker_screen.dart';

import '../helpers/test_app.dart';

final class FakeStoragePermissionService implements StoragePermissionService {
  FakeStoragePermissionService({this.statusValue = StorageAccess.denied});

  StorageAccess statusValue;

  @override
  Future<StorageAccess> status() async => statusValue;

  @override
  Future<StorageAccess> request() async => statusValue;

  @override
  Future<void> openSystemSettings() async {}
}

void main() {
  testWidgets('shows open and create buttons, and displays recents', (
    tester,
  ) async {
    final recent = RecentVault(
      path: '/non/existent/vault',
      name: 'Old Vault',
      lastOpened: DateTime(2026, 10, 10),
    );
    final appSettings = AppSettings(
      deviceId: 'device-1',
      recentVaults: [recent],
    );

    await tester.pumpWidget(
      testApp(
        const VaultPickerScreen(isAndroid: false),
        appSettings: appSettings,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('vaultPicker.open')), findsOneWidget);
    expect(find.byKey(const Key('vaultPicker.create')), findsOneWidget);
    expect(find.byKey(const Key('vaultPicker.recent.0')), findsOneWidget);
    expect(find.text('Old Vault'), findsOneWidget);
    // Path does not exist, so shows missing warning
    expect(find.text('Vault folder no longer exists'), findsOneWidget);

    // Tapping missing vault does nothing (no exception or session change)
    await tester.tap(find.byKey(const Key('vaultPicker.recent.0')));
    await tester.pumpAndSettle();

    // Remove from list via popup menu
    await tester.tap(find.byKey(const Key('recentVault.menu.0')));
    await tester.pumpAndSettle();
    expect(find.text('Remove from list'), findsOneWidget);
    await tester.tap(find.text('Remove from list'));
    await tester.pumpAndSettle();

    // Now recent is gone
    expect(find.byKey(const Key('vaultPicker.recent.0')), findsNothing);
  });

  testWidgets(
    'Android-only createPrivate button appears when storage access is denied',
    (tester) async {
      final fakeService = FakeStoragePermissionService(
        statusValue: StorageAccess.denied,
      );

      await tester.pumpWidget(
        testApp(
          const VaultPickerScreen(isAndroid: true),
          overrides: [
            storagePermissionServiceProvider.overrideWithValue(fakeService),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('vaultPicker.createPrivate')),
        findsOneWidget,
      );
    },
  );

  testWidgets('CreateVaultDialog validates names', (tester) async {
    await tester.pumpWidget(
      testApp(const CreateVaultDialog(isAppPrivate: true)),
    );
    await tester.pumpAndSettle();

    // Tapping Create with empty name shows error
    await tester.tap(find.byKey(const Key('createVault.create')));
    await tester.pumpAndSettle();
    expect(find.text('Vault name cannot be empty.'), findsOneWidget);

    // Entering invalid name shows invalid error
    await tester.enterText(
      find.byKey(const Key('createVault.name')),
      'bad:name',
    );
    await tester.tap(find.byKey(const Key('createVault.create')));
    await tester.pumpAndSettle();
    expect(
      find.text('Vault name contains invalid characters.'),
      findsOneWidget,
    );
  });
}
