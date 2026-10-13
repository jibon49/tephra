// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/explorer/move_to_dialog.dart';
import 'package:tephra/l10n/app_localizations.dart';
import 'package:tephra/settings/app_settings.dart';
import 'package:tephra/settings/providers.dart';
import 'package:tephra/settings/vault_settings.dart';
import 'package:tephra/theme/app_theme.dart';
import 'package:tephra/vault/providers.dart';
import 'package:tephra/vault/vault_session.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

class TestVaultSessionNotifier extends VaultSessionNotifier {
  TestVaultSessionNotifier(this.initialSession);
  final VaultSession initialSession;

  @override
  VaultSession? build() => initialSession;
}

void main() {
  group('move_to_dialog_test', () {
    late MemoryVaultFileSystem fs;
    late VaultSession session;

    setUp(() {
      fs = MemoryVaultFileSystem(caseInsensitive: true);
      session = VaultSession(
        vaultId: 'v1',
        rootDir: '/vault',
        name: 'test-vault',
        fs: fs,
        settings: const VaultSettings(),
      );
    });

    Widget buildHarness({required Widget child}) {
      return ProviderScope(
        overrides: [
          initialAppSettingsProvider.overrideWithValue(
            const AppSettings(deviceId: 'test-device-id'),
          ),
          vaultSessionProvider.overrideWith(
            () => TestVaultSessionNotifier(session),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: Center(child: child)),
        ),
      );
    }

    testWidgets(
      'lists folders only, disables invalid targets, and returns selected target path',
      (tester) async {
        await fs.createFolder(VaultPath('FolderA'));
        await fs.createFolder(VaultPath('FolderA/SubA'));
        await fs.createFolder(VaultPath('FolderB'));
        await fs.writeText(
          VaultPath('Note.md'),
          const TextDocument(text: 'text'),
        );
        await fs.writeText(
          VaultPath('FolderA/FileInA.md'),
          const TextDocument(text: 'in A'),
        );

        VaultPath? chosenTarget;

        await tester.pumpWidget(
          buildHarness(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  // Moving FolderA
                  chosenTarget = await showMoveToDialog(
                    context,
                    sourcePath: VaultPath('FolderA'),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        expect(find.byType(MoveToDialog), findsOneWidget);
        expect(find.text('/'), findsOneWidget);

        // Files Note.md and FileInA.md should not be listed
        expect(find.text('Note'), findsNothing);
        expect(find.text('FileInA'), findsNothing);

        // Expand '/' to show top-level folders
        // Find chevron or expand
        expect(find.text('FolderA'), findsOneWidget);
        expect(find.text('FolderB'), findsOneWidget);

        // "Move here" button should initially be disabled
        final moveBtnFinder = find.widgetWithText(FilledButton, 'Move here');
        expect(tester.widget<FilledButton>(moveBtnFinder).onPressed, isNull);

        // Tapping FolderA should not enable Move here because it is widget.sourcePath
        await tester.tap(find.text('FolderA'));
        await tester.pumpAndSettle();
        expect(tester.widget<FilledButton>(moveBtnFinder).onPressed, isNull);

        // Tapping FolderB (valid target) enables Move here
        await tester.tap(find.text('FolderB'));
        await tester.pumpAndSettle();
        expect(tester.widget<FilledButton>(moveBtnFinder).onPressed, isNotNull);

        // Tap Move here
        await tester.tap(moveBtnFinder);
        await tester.pumpAndSettle();

        expect(chosenTarget, equals(VaultPath('FolderB')));
      },
    );
  });
}
