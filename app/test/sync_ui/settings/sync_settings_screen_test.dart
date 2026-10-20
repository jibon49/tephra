// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/core/sync/google_auth_service.dart';
import 'package:tephra/core/sync/sync_worker_client.dart';
import 'package:tephra/l10n/app_localizations.dart';
import 'package:tephra/sync_ui/providers.dart';
import 'package:tephra/sync_ui/settings/sync_settings_screen.dart';

import '../fake_sync_worker_client.dart';
import '../setup/sync_setup_wizard_test.dart';

void main() {
  group('SyncSettingsScreen', () {
    testWidgets('renders sections and notifies settings changes', (
      tester,
    ) async {
      final fakeClient = FakeSyncWorkerClient();
      final fakeSetup = FakeSyncSetupService(
        account: const GoogleAccount(
          email: 'test@gmail.com',
          displayName: 'Test User',
        ),
      );

      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            syncWorkerClientProvider('test-vault')
                .overrideWithValue(fakeClient),
            syncSetupServiceForIdProvider('test-vault')
                .overrideWithValue(fakeSetup),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SyncSettingsScreen(vaultId: 'test-vault'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sync & backup'), findsOneWidget);
      expect(find.text('Signed in as test@gmail.com'), findsOneWidget);
      expect(find.text('Selective sync & exclusions'), findsOneWidget);
      expect(
        find.textContaining(
          'Excluded files stay on this device and in Google Drive',
        ),
        findsOneWidget,
      );

      // Add an excluded file extension
      final extField = find.byKey(const Key('sync_settings_ext_field'));
      expect(extField, findsOneWidget);
      await tester.enterText(extField, 'mkv');
      await tester.tap(find.widgetWithIcon(IconButton, Icons.add));
      await tester.pumpAndSettle();

      expect(find.text('mkv'), findsOneWidget);
      expect(fakeClient.lastSettings, isNotNull);
    });
  });
}
