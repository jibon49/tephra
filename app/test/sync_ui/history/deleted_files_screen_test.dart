// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/core/sync/sync_worker_client.dart';
import 'package:tephra/l10n/app_localizations.dart';
import 'package:tephra/settings/vault_settings.dart';
import 'package:tephra/sync_ui/history/deleted_files_screen.dart';
import 'package:tephra/sync_ui/history/history_screen.dart';
import 'package:tephra/vault/providers.dart';
import 'package:tephra/vault/vault_session.dart';
import 'package:tephra_core/tephra_core.dart';
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

  group('DeletedFilesScreen', () {
    testWidgets('shows empty state when no deleted files exist', (
      tester,
    ) async {
      fakeClient.deletedList = [];

      await tester.pumpWidget(
        wrapWithScope(
          DeletedFilesScreen(vaultId: vaultId, workerClient: fakeClient),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No recently deleted files.'), findsOneWidget);
    });

    testWidgets('renders list of deleted files at 1200dp', (tester) async {
      final file1 = RecentlyDeletedFile(
        path: VaultPath('Notes/Deleted1.md'),
        deletedTime: DateTime.utc(2026, 10, 20, 10, 30, 0),
        deletingDevice: 'Pixel 8',
        source: RecentlyDeletedSource.remote,
      );
      final file2 = RecentlyDeletedFile(
        path: VaultPath('Notes/Deleted2.md'),
        deletedTime: DateTime.utc(2026, 10, 20, 11, 0, 0),
        deletingDevice: 'This device',
        source: RecentlyDeletedSource.vaultTrash,
      );

      fakeClient.deletedList = [file1, file2];

      await tester.binding.setSurfaceSize(const Size(1200, 800));
      await tester.pumpWidget(
        wrapWithScope(
          DeletedFilesScreen(vaultId: vaultId, workerClient: fakeClient),
          size: const Size(1200, 800),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Notes/Deleted1.md'), findsOneWidget);
      expect(find.text('Notes/Deleted2.md'), findsOneWidget);
      expect(find.text('Restore'), findsNWidgets(2));
      expect(find.text('History'), findsNWidgets(2));
    });

    testWidgets('renders list of deleted files at 400dp', (tester) async {
      final file1 = RecentlyDeletedFile(
        path: VaultPath('Notes/Deleted1.md'),
        deletedTime: DateTime.utc(2026, 10, 20, 10, 30, 0),
        deletingDevice: 'Pixel 8',
        source: RecentlyDeletedSource.remote,
      );

      fakeClient.deletedList = [file1];

      await tester.binding.setSurfaceSize(const Size(400, 700));
      await tester.pumpWidget(
        wrapWithScope(
          DeletedFilesScreen(vaultId: vaultId, workerClient: fakeClient),
          size: const Size(400, 700),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Notes/Deleted1.md'), findsOneWidget);
      expect(find.text('Restore'), findsOneWidget);
    });

    testWidgets('restore file triggers worker restore and shows snackbar', (
      tester,
    ) async {
      final file1 = RecentlyDeletedFile(
        path: VaultPath('Notes/Deleted1.md'),
        deletedTime: DateTime.utc(2026, 10, 20, 10, 30, 0),
        deletingDevice: 'Pixel 8',
        source: RecentlyDeletedSource.remote,
      );

      fakeClient.deletedList = [file1];

      await tester.pumpWidget(
        wrapWithScope(
          DeletedFilesScreen(vaultId: vaultId, workerClient: fakeClient),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();

      expect(fakeClient.lastRestoredDeletedFile, equals(file1));
      expect(find.text('Restored as Notes/Deleted1.md'), findsOneWidget);
    });

    testWidgets('history button navigates to HistoryScreen', (tester) async {
      final file1 = RecentlyDeletedFile(
        path: VaultPath('Notes/Deleted1.md'),
        deletedTime: DateTime.utc(2026, 10, 20, 10, 30, 0),
        deletingDevice: 'Pixel 8',
        source: RecentlyDeletedSource.remote,
      );

      fakeClient.deletedList = [file1];

      await tester.pumpWidget(
        wrapWithScope(
          DeletedFilesScreen(vaultId: vaultId, workerClient: fakeClient),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();

      expect(find.byType(HistoryScreen), findsOneWidget);
    });
  });
}
