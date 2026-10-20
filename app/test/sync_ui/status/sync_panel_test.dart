// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/core/sync/sync_messages.dart';
import 'package:tephra/core/sync/sync_worker_client.dart';
import 'package:tephra/l10n/app_localizations.dart';
import 'package:tephra/sync_ui/providers.dart';
import 'package:tephra/sync_ui/status/sync_panel.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_sync/tephra_sync.dart';

import '../fake_sync_worker_client.dart';
import '../setup/sync_setup_wizard_test.dart';

void main() {
  group('SyncPanel widget', () {
    testWidgets('triggers Sync now and Pause/Resume commands', (tester) async {
      final fakeClient = FakeSyncWorkerClient(
        initialStatus: const SyncStatusSnapshot(
          state: SyncUiState.idle,
          accountEmail: 'user@example.com',
          quota: Quota(
            usedBytes: 500 * 1024 * 1024,
            limitBytes: 15 * 1024 * 1024 * 1024,
          ),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            syncWorkerClientProvider('test-vault')
                .overrideWithValue(fakeClient),
            syncStatusProvider('test-vault')
                .overrideWith((ref) => fakeClient.statusStream),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: SyncPanel(vaultId: 'test-vault')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('user@example.com'), findsOneWidget);
      expect(find.textContaining('used in Google Drive'), findsOneWidget);

      // Tap Sync now
      expect(
        find.byKey(const Key('sync_panel_sync_now_button')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('sync_panel_sync_now_button')));
      await tester.pump();
      expect(fakeClient.syncNowCallCount, equals(1));

      // Tap Pause sync
      expect(
        find.byKey(const Key('sync_panel_pause_resume_button')),
        findsOneWidget,
      );
      expect(find.text('Pause sync'), findsOneWidget);
      await tester.tap(find.byKey(const Key('sync_panel_pause_resume_button')));
      await tester.pumpAndSettle();
      expect(fakeClient.lastPaused, isTrue);

      // Check button switched to Resume sync
      expect(find.text('Resume sync'), findsOneWidget);
      await tester.tap(find.byKey(const Key('sync_panel_pause_resume_button')));
      await tester.pumpAndSettle();
      expect(fakeClient.lastPaused, isFalse);
    });

    testWidgets('renders reconnect banner on authRevoked error', (
      tester,
    ) async {
      final fakeClient = FakeSyncWorkerClient(
        initialStatus: const SyncStatusSnapshot(
          state: SyncUiState.needsAttention,
          errorKind: 'authRevoked',
        ),
      );
      final fakeSetup = FakeSyncSetupService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            syncWorkerClientProvider('test-vault')
                .overrideWithValue(fakeClient),
            syncStatusProvider('test-vault')
                .overrideWith((ref) => fakeClient.statusStream),
            syncSetupServiceForIdProvider('test-vault')
                .overrideWithValue(fakeSetup),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: SyncPanel(vaultId: 'test-vault')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Google Drive access expired. Reconnect to keep syncing.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('sync_panel_reconnect_button')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('sync_panel_reconnect_button')));
      await tester.pumpAndSettle();

      expect(fakeSetup.signInCount, equals(1));
    });

    testWidgets('shows conflicts and held deletions badges and links', (
      tester,
    ) async {
      final fakeClient = FakeSyncWorkerClient(
        initialStatus: SyncStatusSnapshot(
          state: SyncUiState.idle,
          unresolvedConflicts: 2,
          heldDeletes: [VaultPath('file1.md')],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            syncWorkerClientProvider('test-vault')
                .overrideWithValue(fakeClient),
            syncStatusProvider('test-vault')
                .overrideWith((ref) => fakeClient.statusStream),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: SyncPanel(vaultId: 'test-vault')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Conflicts (2)'), findsOneWidget);
      expect(find.text('Held deletions (1)'), findsOneWidget);
      expect(find.text('Sync log'), findsOneWidget);
      expect(find.text('Sync settings'), findsOneWidget);
    });
  });
}
