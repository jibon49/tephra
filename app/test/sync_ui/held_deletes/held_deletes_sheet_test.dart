// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/core/sync/sync_worker_client.dart';
import 'package:tephra/l10n/app_localizations.dart';
import 'package:tephra/sync_ui/held_deletes/held_deletes_sheet.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_sync/tephra_sync.dart';

import '../fake_sync_worker_client.dart';

void main() {
  group('HeldDeletesSheet', () {
    testWidgets('Delete them approves all held files', (tester) async {
      final fakeClient = FakeSyncWorkerClient();
      final paths = [VaultPath('notes/a.md'), VaultPath('notes/b.md')];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            syncWorkerClientProvider('test-vault')
                .overrideWithValue(fakeClient),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: HeldDeletesSheet(vaultId: 'test-vault', heldDeletes: paths),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Review held deletions'), findsOneWidget);
      expect(
        find.textContaining('Sync wants to delete 2 files'),
        findsOneWidget,
      );
      expect(find.text('a.md'), findsOneWidget);
      expect(find.text('b.md'), findsOneWidget);

      await tester.tap(find.byKey(const Key('held_deletes_delete_all')));
      await tester.pumpAndSettle();

      expect(fakeClient.lastHeldDeletes, isNotNull);
      expect(
        fakeClient.lastHeldDeletes!['notes/a.md'],
        equals(DeleteDecision.approve),
      );
      expect(
        fakeClient.lastHeldDeletes!['notes/b.md'],
        equals(DeleteDecision.approve),
      );
    });

    testWidgets('Keep them preserves all held files', (tester) async {
      final fakeClient = FakeSyncWorkerClient();
      final paths = [VaultPath('notes/c.md')];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            syncWorkerClientProvider('test-vault')
                .overrideWithValue(fakeClient),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: HeldDeletesSheet(vaultId: 'test-vault', heldDeletes: paths),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('held_deletes_keep_all')));
      await tester.pumpAndSettle();

      expect(fakeClient.lastHeldDeletes, isNotNull);
      expect(
        fakeClient.lastHeldDeletes!['notes/c.md'],
        equals(DeleteDecision.keep),
      );
    });

    testWidgets('Apply choices supports per-file decisions', (tester) async {
      final fakeClient = FakeSyncWorkerClient();
      final paths = [VaultPath('file1.md'), VaultPath('file2.md')];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            syncWorkerClientProvider('test-vault')
                .overrideWithValue(fakeClient),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: HeldDeletesSheet(vaultId: 'test-vault', heldDeletes: paths),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Toggle first switch to false (keep)
      final switches = find.byType(Switch);
      expect(switches, findsNWidgets(2));
      await tester.tap(switches.first);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('held_deletes_apply_choices')));
      await tester.pumpAndSettle();

      expect(fakeClient.lastHeldDeletes, isNotNull);
      expect(
        fakeClient.lastHeldDeletes!['file1.md'],
        equals(DeleteDecision.keep),
      );
      expect(
        fakeClient.lastHeldDeletes!['file2.md'],
        equals(DeleteDecision.approve),
      );
    });
  });
}
