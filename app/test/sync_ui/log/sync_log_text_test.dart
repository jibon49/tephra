// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/core/sync/sync_worker_client.dart';
import 'package:tephra/l10n/app_localizations.dart';
import 'package:tephra/sync_ui/log/sync_log_screen.dart';
import 'package:tephra/sync_ui/log/sync_log_text.dart';
import 'package:tephra_sync/tephra_sync.dart';

import '../fake_sync_worker_client.dart';

void main() {
  group('SyncLogText', () {
    testWidgets('all 16 kinds produce localized sentences', (tester) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(SyncLogText.allKinds.length, equals(16));

      for (final kind in SyncLogText.allKinds) {
        final entry = SyncLogEntry(
          time: DateTime.utc(2026, 10, 20, 10, 30).millisecondsSinceEpoch,
          level: kind == 'error' ? 'error' : 'info',
          kind: kind,
          path: 'notes/meeting.md',
          otherPath: 'notes/meeting_renamed.md',
          deviceName: 'Pixel 8',
          detail: 'Something went wrong',
        );

        final sentence = SyncLogText.describe(entry, l10n);
        expect(sentence, isNotEmpty, reason: 'Failed for kind: $kind');
        expect(
          sentence.contains('meeting.md') ||
              sentence.contains('Pixel 8') ||
              sentence.contains('Something') ||
              sentence.contains('Device') ||
              sentence.contains('Held'),
          isTrue,
          reason: 'Kind $kind produced unexpected: $sentence',
        );
      }
    });

    test('isChange and isProblem correctly classify log kinds', () {
      final upload = const SyncLogEntry(
        time: 1000,
        level: 'info',
        kind: 'uploaded',
        path: 'note.md',
      );
      final download = const SyncLogEntry(
        time: 1000,
        level: 'info',
        kind: 'downloaded',
        path: 'note.md',
      );
      final merge = const SyncLogEntry(
        time: 1000,
        level: 'info',
        kind: 'merged',
        path: 'note.md',
      );
      final error = const SyncLogEntry(
        time: 1000,
        level: 'error',
        kind: 'error',
        detail: 'fail',
      );
      final caseConflict = const SyncLogEntry(
        time: 1000,
        level: 'warning',
        kind: 'caseConflictRenamed',
        path: 'a.md',
        otherPath: 'b.md',
      );

      expect(SyncLogText.isChange(upload), isTrue);
      expect(SyncLogText.isChange(download), isTrue);
      expect(SyncLogText.isChange(merge), isTrue);
      expect(SyncLogText.isChange(error), isFalse);

      expect(SyncLogText.isProblem(error), isTrue);
      expect(SyncLogText.isProblem(caseConflict), isTrue);
      expect(SyncLogText.isProblem(upload), isFalse);
    });
  });

  group('SyncLogScreen widget', () {
    testWidgets('renders logs, filter chips, and copy action', (tester) async {
      final fakeLogs = [
        SyncLogEntry(
          id: 1,
          time: DateTime.utc(2026, 10, 20, 12, 0).millisecondsSinceEpoch,
          level: 'info',
          kind: 'uploaded',
          path: 'Folder/Note1.md',
        ),
        SyncLogEntry(
          id: 2,
          time: DateTime.utc(2026, 10, 20, 11, 0).millisecondsSinceEpoch,
          level: 'error',
          kind: 'error',
          detail: 'Auth token revoked',
        ),
      ];

      final fakeClient = FakeSyncWorkerClient(initialLogs: fakeLogs);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            syncWorkerClientProvider('test-vault')
                .overrideWithValue(fakeClient),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SyncLogScreen(vaultId: 'test-vault'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check entries are displayed
      expect(find.textContaining('Uploaded Folder/Note1.md'), findsOneWidget);
      expect(
        find.textContaining('Sync error: Auth token revoked'),
        findsOneWidget,
      );

      // Filter by Changes
      await tester.tap(find.byKey(const Key('sync_log_filter_changes')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Uploaded Folder/Note1.md'), findsOneWidget);
      expect(
        find.textContaining('Sync error: Auth token revoked'),
        findsNothing,
      );

      // Filter by Problems
      await tester.tap(find.byKey(const Key('sync_log_filter_problems')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Uploaded Folder/Note1.md'), findsNothing);
      expect(
        find.textContaining('Sync error: Auth token revoked'),
        findsOneWidget,
      );

      // Copy log
      expect(find.byKey(const Key('sync_log_copy_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('sync_log_copy_button')));
      await tester.pump();
      expect(find.text('Log copied to clipboard'), findsOneWidget);
    });
  });
}
