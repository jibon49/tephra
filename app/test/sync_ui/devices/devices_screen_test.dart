// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/core/sync/google_auth_service.dart';
import 'package:tephra/core/sync/sync_worker_client.dart';
import 'package:tephra/l10n/app_localizations.dart';
import 'package:tephra/sync_ui/devices/devices_screen.dart';
import 'package:tephra/sync_ui/providers.dart';
import 'package:tephra_sync/tephra_sync.dart';

import '../fake_sync_worker_client.dart';
import '../setup/sync_setup_wizard_test.dart';

void main() {
  group('DevicesScreen', () {
    testWidgets('renders device list, badges, and remove flow', (tester) async {
      final now = DateTime.now();
      final devices = [
        RemoteDevice(
          deviceId: 'dev-1',
          deviceName: 'Pixel 8',
          platform: 'android',
          registeredAt: now.subtract(const Duration(days: 2)),
          updatedAt: now.subtract(const Duration(minutes: 5)),
        ),
        RemoteDevice(
          deviceId: 'dev-2',
          deviceName: 'Windows PC',
          platform: 'windows',
          registeredAt: now.subtract(const Duration(days: 10)),
          updatedAt: now.subtract(const Duration(hours: 3)),
          revoked: true,
        ),
        RemoteDevice(
          deviceId: 'dev-3',
          deviceName: 'Work Laptop',
          platform: 'windows',
          registeredAt: now.subtract(const Duration(days: 1)),
          updatedAt: now.subtract(const Duration(minutes: 30)),
        ),
      ];

      final fakeClient = FakeSyncWorkerClient(initialDevices: devices);
      final fakeSetup = FakeSyncSetupService(
        account: const GoogleAccount(
          email: 'dev-1', // Matches dev-1 for "This device"
          displayName: 'Test User',
        ),
      );

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
            home: DevicesScreen(vaultId: 'test-vault'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pixel 8'), findsOneWidget);
      expect(find.text('This device'), findsOneWidget);

      expect(find.text('Windows PC'), findsOneWidget);
      expect(find.text('Removed'), findsOneWidget);

      expect(find.text('Work Laptop'), findsOneWidget);
      expect(find.byKey(const Key('remove_device_dev-3')), findsOneWidget);

      // Tap remove on Work Laptop
      await tester.tap(find.byKey(const Key('remove_device_dev-3')));
      await tester.pumpAndSettle();

      // Check confirmation dialog
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Remove device'),
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Work Laptop will stop syncing. Changes it makes after now are ignored.',
        ),
        findsOneWidget,
      );

      // Confirm remove
      await tester.tap(find.byKey(const Key('confirm_remove_device_button')));
      await tester.pumpAndSettle();

      expect(fakeClient.lastRevokedDeviceId, equals('dev-3'));
    });
  });
}
