// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/core/sync/sync_worker_client.dart';
import 'package:tephra/l10n/app_localizations.dart';
import 'package:tephra/settings/vault_settings.dart';
import 'package:tephra/sync_ui/backups/restore_screen.dart';
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
  late BackupManifest sampleManifest;

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

    sampleManifest = BackupManifest(
      vaultId: vaultId,
      createdAt: DateTime.utc(2026, 10, 20, 14, 0, 0),
      deviceId: 'dev-1',
      deviceName: 'Desktop PC',
      kind: BackupKind.manual,
      fileCount: 2,
      totalBytes: 2048,
      files: const [
        BackupManifestFile(
          path: 'notes/first.md',
          hash: 'hash1',
          size: 1024,
          mtime: 1000,
          blobKeys: [
            'blobs/1111111111111111111111111111111111111111111111111111111111111111',
          ],
        ),
        BackupManifestFile(
          path: 'notes/second.md',
          hash: 'hash2',
          size: 1024,
          mtime: 1000,
          blobKeys: [
            'blobs/2222222222222222222222222222222222222222222222222222222222222222',
          ],
        ),
      ],
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

  group('RestoreScreen', () {
    testWidgets('renders manifest summary and selectable file checklist', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithScope(
          RestoreScreen(
            vaultId: vaultId,
            manifest: sampleManifest,
            workerClient: fakeClient,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Restore backup'), findsOneWidget);
      expect(find.text('notes/first.md'), findsOneWidget);
      expect(find.text('notes/second.md'), findsOneWidget);
      expect(find.text('Desktop PC · 2 files · 2.0 KiB'), findsOneWidget);

      // By default both files are selected
      expect(find.text('Restore 2 files'), findsOneWidget);

      // Deselect one file
      await tester.tap(find.text('notes/first.md'));
      await tester.pumpAndSettle();

      expect(find.text('Restore 1 file'), findsOneWidget);
    });

    testWidgets('executes restore into current vault on confirmation', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        wrapWithScope(
          RestoreScreen(
            vaultId: vaultId,
            manifest: sampleManifest,
            workerClient: fakeClient,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the Restore FilledButton and scroll to it if needed
      final restoreBtn = find.byType(FilledButton);
      expect(restoreBtn, findsOneWidget);
      await tester.ensureVisible(restoreBtn);
      await tester.tap(restoreBtn);
      await tester.pumpAndSettle();

      // Confirm dialog appears
      expect(find.text('Restore 2 selected files?'), findsOneWidget);
      await tester.tap(find.text('Restore this version'));
      await tester.pumpAndSettle();

      // Verify worker client received restore request
      expect(fakeClient.lastRestoreRequest, isNotNull);
      expect(fakeClient.lastRestoreRequest!['stamp'], sampleManifest.stamp);
      expect(fakeClient.lastRestoreRequest!['targetMode'], 'intoVault');

      // Verify report card is displayed
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });
  });
}
