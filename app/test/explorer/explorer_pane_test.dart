// © 2026 Tephra. All rights reserved.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/editor/edit_operation.dart';
import 'package:tephra/explorer/explorer_pane.dart';
import 'package:tephra/l10n/app_localizations.dart';
import 'package:tephra/settings/app_settings.dart';
import 'package:tephra/settings/providers.dart';
import 'package:tephra/settings/vault_settings.dart';
import 'package:tephra/theme/app_theme.dart';
import 'package:tephra/vault/providers.dart';
import 'package:tephra/vault/vault_session.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

extension on VaultFileSystem {
  Future<bool> exists(VaultPath path) async => (await stat(path)) != null;
}

class TestVaultSessionNotifier extends VaultSessionNotifier {
  TestVaultSessionNotifier(this.initialSession);
  final VaultSession initialSession;

  @override
  VaultSession? build() => initialSession;
}

void main() {
  group('explorer_pane_test', () {
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

    Widget buildHarness({
      required Size size,
      bool? isWindows,
      List<Override> overrides = const [],
    }) {
      return ProviderScope(
        overrides: [
          initialAppSettingsProvider.overrideWithValue(
            const AppSettings(deviceId: 'test-device-id'),
          ),
          vaultSessionProvider.overrideWith(
            () => TestVaultSessionNotifier(session),
          ),
          ...overrides,
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(size: size),
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: ExplorerPane(isWindows: isWindows),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('toolbar buttons exist at 1200 dp and 400 dp', (tester) async {
      await tester.pumpWidget(buildHarness(size: const Size(1200, 800)));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('explorer.toolbar')), findsOneWidget);
      expect(find.byKey(const ValueKey('explorer.newNote')), findsOneWidget);
      expect(find.byKey(const ValueKey('explorer.newFolder')), findsOneWidget);
      expect(find.byKey(const ValueKey('explorer.sort')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('explorer.collapseAll')),
        findsOneWidget,
      );

      await tester.pumpWidget(buildHarness(size: const Size(400, 800)));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('explorer.toolbar')), findsOneWidget);
    });

    testWidgets('tap folder expands and collapses children', (tester) async {
      await fs.createFolder(VaultPath('MyFolder'));
      await fs.writeText(
        VaultPath('MyFolder/Child.md'),
        const TextDocument(text: 'child text'),
      );

      await tester.pumpWidget(buildHarness(size: const Size(1200, 800)));
      await tester.pumpAndSettle();

      expect(find.text('MyFolder'), findsOneWidget);
      expect(find.text('Child'), findsNothing);

      // Tap folder to expand
      await tester.tap(find.text('MyFolder'));
      await tester.pumpAndSettle();

      expect(find.text('Child'), findsOneWidget);

      // Tap folder again to collapse
      await tester.tap(find.text('MyFolder'));
      await tester.pumpAndSettle();

      expect(find.text('Child'), findsNothing);
    });

    testWidgets(
      'tap note opens it in workspace and active note row is highlighted',
      (tester) async {
        await fs.writeText(
          VaultPath('NoteA.md'),
          const TextDocument(text: 'text A'),
        );

        await tester.pumpWidget(buildHarness(size: const Size(1200, 800)));
        await tester.pumpAndSettle();

        await tester.tap(find.text('NoteA'));
        await tester.pumpAndSettle();

        // Find the row container for NoteA
        final containerFinder = find.byKey(const ValueKey('row:NoteA.md'));
        expect(containerFinder, findsOneWidget);
      },
    );

    testWidgets(
      'right click on note shows 8 entries on Windows and 7 on non-Windows',
      (tester) async {
        await fs.writeText(
          VaultPath('NoteA.md'),
          const TextDocument(text: 'text A'),
        );

        // Windows = true
        await tester.pumpWidget(
          buildHarness(size: const Size(1200, 800), isWindows: true),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('NoteA'), buttons: kSecondaryMouseButton);
        await tester.pumpAndSettle();

        expect(find.text('Open in new tab'), findsOneWidget);
        expect(find.text('New note'), findsOneWidget);
        expect(find.text('New folder'), findsOneWidget);
        expect(find.text('Rename'), findsOneWidget);
        expect(find.text('Duplicate'), findsOneWidget);
        expect(find.text('Move to…'), findsOneWidget);
        expect(find.text('Reveal in system explorer'), findsOneWidget);
        expect(find.text('Delete'), findsOneWidget);

        // Close menu
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        // Windows = false
        await tester.pumpWidget(
          buildHarness(size: const Size(1200, 800), isWindows: false),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('NoteA'), buttons: kSecondaryMouseButton);
        await tester.pumpAndSettle();

        expect(find.text('Reveal in system explorer'), findsNothing);
        expect(find.text('Delete'), findsOneWidget);
      },
    );

    testWidgets('long press on phone (400 dp) opens bottom sheet', (
      tester,
    ) async {
      await fs.writeText(
        VaultPath('NoteA.md'),
        const TextDocument(text: 'text A'),
      );

      await tester.pumpWidget(buildHarness(size: const Size(400, 800)));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('NoteA'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets(
      'delete flow shows correct body text and warning for unsaved dirty notes',
      (tester) async {
        await fs.writeText(
          VaultPath('NoteA.md'),
          const TextDocument(text: 'original'),
        );

        final container = ProviderContainer(
          overrides: [
            initialAppSettingsProvider.overrideWithValue(
              const AppSettings(deviceId: 'test-device-id'),
            ),
            vaultSessionProvider.overrideWith(
              () => TestVaultSessionNotifier(session),
            ),
          ],
        );
        addTearDown(container.dispose);

        // Acquire doc and make it dirty
        final doc = container
            .read(noteDocumentStoreProvider)
            .acquire(VaultPath('NoteA.md'));
        await doc.load();
        doc.edit(const EditOperation(0, 8, 'dirty content'));
        expect(doc.isDirty, isTrue);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.light(),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: MediaQuery(
                  data: const MediaQueryData(size: Size(1200, 800)),
                  child: const SizedBox(
                    width: 1200,
                    height: 800,
                    child: ExplorerPane(isWindows: true),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Open context menu and tap Delete
        await tester.tap(find.text('NoteA'), buttons: kSecondaryMouseButton);
        await tester.pumpAndSettle();
        doc.edit(const EditOperation(0, 0, 'dirty '));
        expect(doc.isDirty, isTrue);
        await tester.tap(find.text('Delete'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          find.text('It will be moved to the vault\'s .trash folder.'),
          findsOneWidget,
        );
        expect(
          find.text('Unsaved changes in open notes will be lost.'),
          findsOneWidget,
        );

        // Confirm delete
        await tester.tap(find.text('Delete').last);
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 600));

        expect(await fs.exists(VaultPath('NoteA.md')), isFalse);
      },
    );

    testWidgets('inline rename Enter commits and Escape cancels', (
      tester,
    ) async {
      await fs.writeText(
        VaultPath('NoteA.md'),
        const TextDocument(text: 'text A'),
      );

      await tester.pumpWidget(buildHarness(size: const Size(1200, 800)));
      await tester.pumpAndSettle();

      // Open context menu and tap Rename
      await tester.tap(find.text('NoteA'), buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();

      final renameField = find.byKey(const ValueKey('explorer.renameField'));
      expect(renameField, findsOneWidget);

      // Cancel with Escape
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('explorer.renameField')), findsNothing);

      // Trigger Rename again and commit new name
      await tester.tap(find.text('NoteA'), buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('explorer.renameField')),
        'NewNote',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('NewNote'), findsOneWidget);
      expect(await fs.exists(VaultPath('NewNote.md')), isTrue);
    });

    testWidgets(
      'drag note onto folder moves it and hovering 600 ms expands folder',
      (tester) async {
        await fs.createFolder(VaultPath('Folder'));
        await fs.writeText(
          VaultPath('Folder/Sub.md'),
          const TextDocument(text: 'sub'),
        );
        await fs.writeText(
          VaultPath('NoteA.md'),
          const TextDocument(text: 'text A'),
        );

        await tester.pumpWidget(buildHarness(size: const Size(1200, 800)));
        await tester.pumpAndSettle();

        // Start drag from NoteA
        final gesture = await tester.startGesture(
          tester.getCenter(find.text('NoteA')),
        );
        await tester.pump();

        // Move hover over Folder
        await gesture.moveTo(tester.getCenter(find.text('Folder')));
        await tester.pump();

        // Hover for 650 ms to trigger expand
        await tester.pump(const Duration(milliseconds: 650));
        expect(find.text('Sub'), findsOneWidget);

        // Drop on folder
        await gesture.up();
        await tester.pumpAndSettle();

        expect(await fs.exists(VaultPath('Folder/NoteA.md')), isTrue);
        expect(await fs.exists(VaultPath('NoteA.md')), isFalse);
      },
    );

    testWidgets('keyboard navigation Up, Down, Enter, F2, Delete', (
      tester,
    ) async {
      await fs.writeText(VaultPath('Note1.md'), const TextDocument(text: '1'));
      await fs.writeText(VaultPath('Note2.md'), const TextDocument(text: '2'));

      await tester.pumpWidget(buildHarness(size: const Size(1200, 800)));
      await tester.pumpAndSettle();

      // Select Note1
      await tester.tap(find.text('Note1'));
      await tester.pumpAndSettle();

      // Down arrow selects Note2
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      // Press F2 to trigger inline rename on Note2
      await tester.sendKeyEvent(LogicalKeyboardKey.f2);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('explorer.renameField')),
        findsOneWidget,
      );
    });
  });
}
