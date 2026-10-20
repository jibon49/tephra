// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/core/sync/sync_worker_client.dart';
import 'package:tephra/l10n/app_localizations.dart';
import 'package:tephra/settings/vault_settings.dart';
import 'package:tephra/sync_ui/conflicts/conflict_detail_screen.dart';
import 'package:tephra/sync_ui/conflicts/conflicts_screen.dart';
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

  Widget wrapWithScope(Widget child) {
    return ProviderScope(
      overrides: [
        vaultSessionProvider.overrideWith(() => _FixedSessionNotifier(session)),
        syncWorkerClientProvider(vaultId).overrideWith((ref) => fakeClient),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );
  }

  group('ConflictsScreen', () {
    testWidgets('shows empty state when no conflicts exist', (tester) async {
      fakeClient.conflictsList = [];

      await tester.pumpWidget(
        wrapWithScope(const ConflictsScreen(vaultId: vaultId)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sync conflicts'), findsOneWidget);
      expect(
        find.text('No unresolved conflicts. All files are up to date.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('renders list of conflicts with paths and badges', (
      tester,
    ) async {
      fakeClient.conflictsList = [
        ConflictRecord(
          id: 1,
          time: DateTime.utc(2026, 10, 20, 10, 0).millisecondsSinceEpoch,
          path: 'Folder/Note.md',
          copyPath: 'Folder/Note (conflict Pixel 8).md',
          kind: 'content',
          otherDevice: 'Pixel 8',
        ),
        ConflictRecord(
          id: 2,
          time: DateTime.utc(2026, 10, 20, 11, 0).millisecondsSinceEpoch,
          path: 'image.png',
          copyPath: 'image (conflict laptop).png',
          kind: 'binary',
          otherDevice: 'Laptop',
        ),
      ];

      await tester.pumpWidget(
        wrapWithScope(const ConflictsScreen(vaultId: vaultId)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Folder/Note.md'), findsOneWidget);
      expect(find.text('Folder/Note (conflict Pixel 8).md'), findsOneWidget);
      expect(find.text('Text conflict'), findsOneWidget);

      expect(find.text('image.png'), findsOneWidget);
      expect(find.text('Binary conflict'), findsOneWidget);
    });

    testWidgets('tapping a conflict card navigates to ConflictDetailScreen', (
      tester,
    ) async {
      fakeClient.conflictsList = [
        ConflictRecord(
          id: 42,
          time: DateTime.utc(2026, 10, 20, 10, 0).millisecondsSinceEpoch,
          path: 'Ideas.md',
          copyPath: 'Ideas (conflict device).md',
          kind: 'content',
          otherDevice: 'Phone',
        ),
      ];

      await tester.pumpWidget(
        wrapWithScope(const ConflictsScreen(vaultId: vaultId)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ideas.md'));
      await tester.pumpAndSettle();

      expect(find.byType(ConflictDetailScreen), findsOneWidget);
    });
  });
}
