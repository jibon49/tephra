// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/core/sync/sync_messages.dart';
import 'package:tephra/core/sync/sync_worker_client.dart';
import 'package:tephra/l10n/app_localizations.dart';
import 'package:tephra/sync_ui/status/sync_panel.dart';
import 'package:tephra/sync_ui/status/sync_status_indicator.dart';

import '../fake_sync_worker_client.dart';

void main() {
  group('SyncStatusIndicator', () {
    testWidgets('renders all 8 SyncUiStates correctly', (tester) async {
      final states = [
        (SyncUiState.notConfigured, Icons.cloud_outlined, 'Not configured'),
        (SyncUiState.idle, Icons.cloud_done_outlined, 'Up to date'),
        (SyncUiState.syncing, Icons.sync, 'Syncing (…/…)'),
        (SyncUiState.pending, Icons.cloud_upload_outlined, '3 pending'),
        (SyncUiState.offline, Icons.cloud_off_outlined, 'Offline'),
        (SyncUiState.paused, Icons.pause_circle_outline, 'Sync paused'),
        (
          SyncUiState.needsAttention,
          Icons.warning_amber_rounded,
          'Needs attention',
        ),
        (SyncUiState.error, Icons.error_outline, 'Sync error'),
      ];

      for (final (state, expectedIcon, expectedText) in states) {
        final client = FakeSyncWorkerClient(
          initialStatus: SyncStatusSnapshot(
            state: state,
            pendingLocalChanges: 3,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            key: ValueKey(state),
            overrides: [
              syncWorkerClientProvider('test-vault').overrideWithValue(client),
              syncStatusProvider('test-vault')
                  .overrideWith((ref) => Stream.value(client.currentStatus)),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: SyncStatusIndicator(vaultId: 'test-vault')),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.byIcon(expectedIcon), findsOneWidget);
        expect(find.text(expectedText), findsOneWidget);
      }
    });

    testWidgets(
      'responsive rendering: full text at 1200dp, compact icon at 400dp',
      (tester) async {
        final client = FakeSyncWorkerClient(
          initialStatus: const SyncStatusSnapshot(state: SyncUiState.idle),
        );

        // Desktop width (1200 dp)
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              syncWorkerClientProvider('test-vault').overrideWithValue(client),
              syncStatusProvider('test-vault')
                  .overrideWith((ref) => Stream.value(client.currentStatus)),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: SyncStatusIndicator(
                  vaultId: 'test-vault',
                  compact: false,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget);
        expect(find.text('Up to date'), findsOneWidget);

        // Phone width (400 dp) with compact: true
        tester.view.physicalSize = const Size(400, 800);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              syncWorkerClientProvider('test-vault').overrideWithValue(client),
              syncStatusProvider('test-vault')
                  .overrideWith((ref) => Stream.value(client.currentStatus)),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: SyncStatusIndicator(vaultId: 'test-vault', compact: true),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget);
        // In compact mode, the short text is omitted from the row
        expect(find.text('Up to date'), findsNothing);
      },
    );

    testWidgets(
      'tap opens dialog on desktop (>=840dp) and bottom sheet on phone (<840dp)',
      (tester) async {
        final client = FakeSyncWorkerClient(
          initialStatus: const SyncStatusSnapshot(state: SyncUiState.idle),
        );

        // 1. Desktop width
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              syncWorkerClientProvider('test-vault').overrideWithValue(client),
              syncStatusProvider('test-vault')
                  .overrideWith((ref) => Stream.value(client.currentStatus)),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: SyncStatusIndicator(vaultId: 'test-vault')),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        await tester.tap(find.byType(SyncStatusIndicator));
        await tester.pumpAndSettle();

        // On desktop, shows Dialog
        expect(find.byType(Dialog), findsOneWidget);
        expect(find.byType(SyncPanel), findsOneWidget);

        // Close dialog
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsNothing);

        // 2. Phone width
        tester.view.physicalSize = const Size(400, 800);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              syncWorkerClientProvider('test-vault').overrideWithValue(client),
              syncStatusProvider('test-vault')
                  .overrideWith((ref) => Stream.value(client.currentStatus)),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: SyncStatusIndicator(vaultId: 'test-vault')),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(SyncStatusIndicator));
        await tester.pumpAndSettle();

        // On phone, shows ModalBottomSheet
        expect(find.byType(BottomSheet), findsOneWidget);
        expect(find.byType(SyncPanel), findsOneWidget);
      },
    );
  });
}
