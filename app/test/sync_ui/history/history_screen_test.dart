// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/core/sync/sync_worker_client.dart';
import 'package:tephra/l10n/app_localizations.dart';
import 'package:tephra/settings/vault_settings.dart';
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
  final notePath = VaultPath('Notes/Work.md');

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

  group('HistoryScreen', () {
    testWidgets('shows empty state when no history exists', (tester) async {
      fakeClient.historyList = [];

      await tester.pumpWidget(
        wrapWithScope(
          HistoryScreen(
            vaultId: vaultId,
            path: notePath,
            workerClient: fakeClient,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('No version history available for this file.'),
        findsOneWidget,
      );
    });

    testWidgets('renders desktop layout (1200dp) with timeline and diff', (
      tester,
    ) async {
      final currentBytes = utf8.encode('# Current Title\n\nCurrent body');
      await fs.writeBytes(notePath, currentBytes);

      const oldText = '# Old Title\n\nOld body';
      const versionRef = LocalVersionRef(
        '.tephra/history/hash/20261020T100000000Z.md.gz',
      );
      fakeClient.versionPayloads[versionRef] = utf8.encode(oldText);

      final version1 = VersionInfo(
        ref: versionRef,
        time: DateTime.utc(2026, 10, 20, 10, 0, 0),
        source: 'Local snapshot',
        size: oldText.length,
        hash: 'hash1',
        origin: VersionOrigin.local,
      );

      fakeClient.historyList = [version1];

      await tester.binding.setSurfaceSize(const Size(1200, 800));
      await tester.pumpWidget(
        wrapWithScope(
          HistoryScreen(
            vaultId: vaultId,
            path: notePath,
            workerClient: fakeClient,
          ),
          size: const Size(1200, 800),
        ),
      );
      await tester.pumpAndSettle();

      // Timeline has item
      expect(find.text('Local snapshot'), findsOneWidget);

      // Diff displays header and buttons
      expect(find.text('Copy text'), findsOneWidget);
      expect(find.text('Restore this version'), findsOneWidget);
    });

    testWidgets('renders mobile layout (400dp) in inline diff mode', (
      tester,
    ) async {
      final currentBytes = utf8.encode('Line A\nLine B');
      await fs.writeBytes(notePath, currentBytes);

      const oldText = 'Line A\nLine B modified';
      const versionRef = RemoteVersionRef(
        entryId: 'dev_phone:1',
        blobKeys: ['blobs/b1'],
        hash: 'h1',
      );
      fakeClient.versionPayloads[versionRef] = utf8.encode(oldText);

      final version1 = VersionInfo(
        ref: versionRef,
        time: DateTime.utc(2026, 10, 20, 10, 0, 0),
        source: 'Pixel 8',
        size: oldText.length,
        hash: 'h1',
        origin: VersionOrigin.remote,
      );

      fakeClient.historyList = [version1];

      await tester.binding.setSurfaceSize(const Size(400, 700));
      await tester.pumpWidget(
        wrapWithScope(
          HistoryScreen(
            vaultId: vaultId,
            path: notePath,
            workerClient: fakeClient,
          ),
          size: const Size(400, 700),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pixel 8'), findsOneWidget);
      expect(find.byKey(const Key('history_restore_button')), findsOneWidget);
    });

    testWidgets(
      'restore version prompts confirmation and triggers worker restore',
      (tester) async {
        const oldText = 'Restored text';
        const versionRef = LocalVersionRef('snapshot_path.gz');
        fakeClient.versionPayloads[versionRef] = utf8.encode(oldText);

        final version1 = VersionInfo(
          ref: versionRef,
          time: DateTime.utc(2026, 10, 20, 10, 0, 0),
          source: 'Local snapshot',
          size: oldText.length,
          hash: 'h1',
          origin: VersionOrigin.local,
        );

        fakeClient.historyList = [version1];

        await tester.binding.setSurfaceSize(const Size(1200, 800));
        await tester.pumpWidget(
          wrapWithScope(
            HistoryScreen(
              vaultId: vaultId,
              path: notePath,
              workerClient: fakeClient,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap restore button
        await tester.tap(find.byKey(const Key('history_restore_button')));
        await tester.pumpAndSettle();

        // Confirmation dialog is shown
        expect(find.byType(AlertDialog), findsOneWidget);

        // Confirm restore
        final restoreDialogButton = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(FilledButton),
        );
        await tester.tap(restoreDialogButton);
        await tester.pumpAndSettle();

        expect(fakeClient.lastRestoredVersionRef, equals(versionRef));
        expect(fakeClient.lastRestoredPath, equals(notePath));
        expect(find.text('Version restored'), findsOneWidget);
      },
    );

    testWidgets('shows unavailable state when blob was garbage collected', (
      tester,
    ) async {
      final versionUnavailable = VersionInfo(
        ref: const RemoteVersionRef(entryId: 'dev:1', blobKeys: ['b1']),
        time: DateTime.utc(2026, 10, 20, 10, 0, 0),
        source: 'Pixel 8',
        origin: VersionOrigin.remote,
        isAvailable: false,
      );

      fakeClient.historyList = [versionUnavailable];

      await tester.binding.setSurfaceSize(const Size(1200, 800));
      await tester.pumpWidget(
        wrapWithScope(
          HistoryScreen(
            vaultId: vaultId,
            path: notePath,
            workerClient: fakeClient,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No longer available'), findsAtLeastNWidgets(1));
    });
  });
}
