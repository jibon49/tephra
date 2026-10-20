// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/core/sync/sync_worker_client.dart';
import 'package:tephra/l10n/app_localizations.dart';
import 'package:tephra/settings/vault_settings.dart';
import 'package:tephra/sync_ui/conflicts/conflict_detail_screen.dart';
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

  group('ConflictDetailScreen', () {
    testWidgets('renders text conflict diff and resolution action buttons', (
      tester,
    ) async {
      final conflict = ConflictRecord(
        id: 1,
        time: DateTime.utc(2026, 10, 20, 10, 0).millisecondsSinceEpoch,
        path: 'Notes/Ideas.md',
        copyPath: 'Notes/Ideas (conflict Phone).md',
        kind: 'content',
        otherDevice: 'Phone',
      );

      await fs.writeText(
        VaultPath('Notes/Ideas.md'),
        const TextDocument(text: 'Their idea\n'),
      );
      await fs.writeText(
        VaultPath('Notes/Ideas (conflict Phone).md'),
        const TextDocument(text: 'My idea\n'),
      );

      await tester.pumpWidget(
        wrapWithScope(
          ConflictDetailScreen(conflict: conflict, vaultId: vaultId),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Notes/Ideas.md'), findsWidgets);
      expect(find.text('Keep mine'), findsOneWidget);
      expect(find.text('Keep theirs'), findsOneWidget);
      expect(find.text('Keep both'), findsOneWidget);
      expect(find.text('Edit merge'), findsOneWidget);
    });

    testWidgets('Keep mine triggers resolveConflict with keepMine', (
      tester,
    ) async {
      final conflict = ConflictRecord(
        id: 7,
        time: DateTime.utc(2026, 10, 20, 10, 0).millisecondsSinceEpoch,
        path: 'Note.md',
        copyPath: 'Note (conflict).md',
        kind: 'content',
        otherDevice: 'Laptop',
      );

      await fs.writeText(
        VaultPath('Note.md'),
        const TextDocument(text: 'Old\n'),
      );
      await fs.writeText(
        VaultPath('Note (conflict).md'),
        const TextDocument(text: 'New\n'),
      );

      await tester.pumpWidget(
        wrapWithScope(
          ConflictDetailScreen(conflict: conflict, vaultId: vaultId),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Keep mine'));
      await tester.pumpAndSettle();

      expect(fakeClient.lastResolvedConflictId, 7);
      expect(fakeClient.lastResolution, ConflictResolution.keepMine);
    });

    testWidgets('Keep theirs triggers resolveConflict with keepTheirs', (
      tester,
    ) async {
      final conflict = ConflictRecord(
        id: 8,
        time: DateTime.utc(2026, 10, 20, 10, 0).millisecondsSinceEpoch,
        path: 'Note.md',
        copyPath: 'Note (conflict).md',
        kind: 'content',
        otherDevice: 'Laptop',
      );

      await fs.writeText(
        VaultPath('Note.md'),
        const TextDocument(text: 'Old\n'),
      );
      await fs.writeText(
        VaultPath('Note (conflict).md'),
        const TextDocument(text: 'New\n'),
      );

      await tester.pumpWidget(
        wrapWithScope(
          ConflictDetailScreen(conflict: conflict, vaultId: vaultId),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Keep theirs'));
      await tester.pumpAndSettle();

      expect(fakeClient.lastResolvedConflictId, 8);
      expect(fakeClient.lastResolution, ConflictResolution.keepTheirs);
    });

    testWidgets('Keep both triggers resolveConflict with keepBoth', (
      tester,
    ) async {
      final conflict = ConflictRecord(
        id: 9,
        time: DateTime.utc(2026, 10, 20, 10, 0).millisecondsSinceEpoch,
        path: 'Note.md',
        copyPath: 'Note (conflict).md',
        kind: 'content',
        otherDevice: 'Laptop',
      );

      await fs.writeText(
        VaultPath('Note.md'),
        const TextDocument(text: 'Old\n'),
      );
      await fs.writeText(
        VaultPath('Note (conflict).md'),
        const TextDocument(text: 'New\n'),
      );

      await tester.pumpWidget(
        wrapWithScope(
          ConflictDetailScreen(conflict: conflict, vaultId: vaultId),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Keep both'));
      await tester.pumpAndSettle();

      expect(fakeClient.lastResolvedConflictId, 9);
      expect(fakeClient.lastResolution, ConflictResolution.keepBoth);
    });

    testWidgets('Edit merge reveals editor and saves custom merged text', (
      tester,
    ) async {
      final conflict = ConflictRecord(
        id: 10,
        time: DateTime.utc(2026, 10, 20, 10, 0).millisecondsSinceEpoch,
        path: 'Note.md',
        copyPath: 'Note (conflict).md',
        kind: 'content',
        otherDevice: 'Phone',
      );

      await fs.writeText(
        VaultPath('Note.md'),
        const TextDocument(text: 'Original remote\n'),
      );
      await fs.writeText(
        VaultPath('Note (conflict).md'),
        const TextDocument(text: 'Original local\n'),
      );

      await tester.pumpWidget(
        wrapWithScope(
          ConflictDetailScreen(conflict: conflict, vaultId: vaultId),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Edit merge button
      await tester.tap(find.text('Edit merge'));
      await tester.pumpAndSettle();

      // Editor should now be visible with TextField
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Save merge'), findsOneWidget);

      // Enter merged text
      await tester.enterText(find.byType(TextField), 'Manually merged content');
      await tester.pumpAndSettle();

      // Tap Save merge
      await tester.tap(find.text('Save merge'));
      await tester.pumpAndSettle();

      expect(fakeClient.lastResolvedConflictId, 10);
      expect(fakeClient.lastResolution, ConflictResolution.editMerge);
      expect(fakeClient.lastMergedText, 'Manually merged content');
    });

    testWidgets('binary conflict displays binary explain banner and cards', (
      tester,
    ) async {
      final conflict = ConflictRecord(
        id: 11,
        time: DateTime.utc(2026, 10, 20, 10, 0).millisecondsSinceEpoch,
        path: 'Doc.pdf',
        copyPath: 'Doc (conflict).pdf',
        kind: 'binary',
        otherDevice: 'Server',
      );

      await fs.writeBytes(VaultPath('Doc.pdf'), utf8.encode('PDF1'));
      await fs.writeBytes(VaultPath('Doc (conflict).pdf'), utf8.encode('PDF2'));

      await tester.pumpWidget(
        wrapWithScope(
          ConflictDetailScreen(conflict: conflict, vaultId: vaultId),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Binary files cannot be merged. Choose which version to keep.',
        ),
        findsOneWidget,
      );
      expect(find.text('Open their version'), findsOneWidget);
      expect(find.text('Open your version'), findsOneWidget);
      // In binary mode, Edit merge button is not shown
      expect(find.text('Edit merge'), findsNothing);
    });
  });
}
