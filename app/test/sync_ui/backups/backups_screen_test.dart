// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/core/sync/sync_worker_client.dart';
import 'package:tephra/l10n/app_localizations.dart';
import 'package:tephra/settings/vault_settings.dart';
import 'package:tephra/sync_ui/backups/backups_screen.dart';
import 'package:tephra/vault/providers.dart';
import 'package:tephra/vault/vault_session.dart';
import 'package:tephra_sync/tephra_sync.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../fake_sync_worker_client.dart';

class _FixedSessionNotifier extends VaultSessionNotifier {
  _FixedSessionNotifier(this._session);
  final VaultSession? _session;
  @override
  VaultSession? build() => _session;
}

void main() {
  const vaultId = 'test-vault-id';
  late FakeSyncWorkerClient fakeClient;
  late MemoryVaultFileSystem fs;
  late VaultSession session;

  setUp(() {
    fakeClient = FakeSyncWorkerClient();
    fs = MemoryVaultFileSystem();
    session = VaultSession(
      vaultId: vaultId,
      name: 'Test Vault',
      rootDir: 'C:/vault',
      fs: fs,
      settings: const VaultSettings(),
    );
  });

  Widget wrapWithScope(Widget child, {Size size = const Size(1200, 800)}) {
    return ProviderScope(
      overrides: [
        vaultSessionProvider.overrideWith(() => _FixedSessionNotifier(session)),
        syncWorkerClientProvider(vaultId).overrideWith((ref) => fakeClient),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: child,
        ),
      ),
    );
  }

  group('BackupsScreen', () {
    testWidgets('shows empty state when no backups exist', (tester) async {
      fakeClient.backupsList = [];

      await tester.pumpWidget(
        wrapWithScope(const BackupsScreen(vaultId: vaultId)),
      );
      await tester.pumpAndSettle();

      expect(find.text('No backups created yet'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
      expect(find.text('Back up now'), findsOneWidget);
      expect(find.text('Backup Schedule'), findsOneWidget);
    });

    testWidgets('renders list of backups with date, device, and file count', (
      tester,
    ) async {
      final now = DateTime.utc(2026, 10, 20, 14, 30, 0);
      final manifest1 = BackupManifest(
        vaultId: vaultId,
        createdAt: now,
        deviceId: 'dev-1',
        deviceName: 'Workstation',
        kind: BackupKind.scheduled,
        fileCount: 42,
        totalBytes: 1024 * 50,
        files: const [],
      );

      final manifest2 = BackupManifest(
        vaultId: vaultId,
        createdAt: now.subtract(const Duration(days: 1)),
        deviceId: 'dev-2',
        deviceName: 'Mobile Phone',
        kind: BackupKind.manual,
        fileCount: 15,
        totalBytes: 1024 * 10,
        files: const [],
      );

      fakeClient.backupsList = [manifest1, manifest2];

      await tester.pumpWidget(
        wrapWithScope(const BackupsScreen(vaultId: vaultId)),
      );
      await tester.pumpAndSettle();

      expect(find.text('No backups created yet'), findsNothing);
      expect(find.textContaining('Workstation'), findsOneWidget);
      expect(find.textContaining('42 files'), findsOneWidget);
      expect(find.textContaining('Mobile Phone'), findsOneWidget);
      expect(find.textContaining('15 files'), findsOneWidget);
      expect(find.text('Restore...'), findsNWidgets(2));
    });

    testWidgets('schedule selector switches frequency', (tester) async {
      await tester.pumpWidget(
        wrapWithScope(const BackupsScreen(vaultId: vaultId)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hourly'), findsOneWidget);
      expect(find.text('Weekly'), findsOneWidget);

      await tester.tap(find.text('Weekly'));
      await tester.pumpAndSettle();

      final segmentedBtn = tester
          .widget<SegmentedButton<BackupScheduleFrequency>>(
            find.byType(typeOf<SegmentedButton<BackupScheduleFrequency>>()),
          );
      expect(segmentedBtn.selected, equals({BackupScheduleFrequency.weekly}));
    });

    testWidgets('tap Back up now triggers worker and displays snackbar', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithScope(const BackupsScreen(vaultId: vaultId)),
      );
      await tester.pumpAndSettle();

      expect(fakeClient.backupNowTriggered, isFalse);

      await tester.tap(find.text('Back up now'));
      await tester.pump(); // Start backing up
      await tester.pumpAndSettle();

      expect(fakeClient.backupNowTriggered, isTrue);
      expect(find.text('Backup completed successfully'), findsOneWidget);
    });

    testWidgets('tap Restore button opens RestoreScreen', (tester) async {
      final now = DateTime.utc(2026, 10, 20, 14, 30, 0);
      final manifest = BackupManifest(
        vaultId: vaultId,
        createdAt: now,
        deviceId: 'dev-1',
        deviceName: 'Workstation',
        kind: BackupKind.manual,
        fileCount: 5,
        totalBytes: 500,
        files: const [],
      );

      fakeClient.backupsList = [manifest];

      await tester.pumpWidget(
        wrapWithScope(const BackupsScreen(vaultId: vaultId)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Restore...'));
      await tester.pumpAndSettle();

      expect(find.text('Restore backup'), findsOneWidget);
    });

    testWidgets('tap Verify now triggers verification and updates UI', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithScope(const BackupsScreen(vaultId: vaultId)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Verify now'));
      await tester.pumpAndSettle();

      expect(fakeClient.runVerificationTriggered, isTrue);
      expect(
        find.textContaining('Verification passed: 20 blobs verified'),
        findsOneWidget,
      );
    });
  });
}

Type typeOf<T>() => T;
