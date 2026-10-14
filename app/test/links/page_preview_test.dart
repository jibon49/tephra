// © 2026 Tephra. All rights reserved.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/core/providers.dart';
import 'package:tephra/l10n/app_localizations.dart';
import 'package:tephra/links/page_preview.dart';
import 'package:tephra/links/page_preview_controller.dart';
import 'package:tephra/reading/reading_view.dart';
import 'package:tephra/settings/app_settings.dart';
import 'package:tephra/settings/providers.dart';
import 'package:tephra/settings/vault_settings.dart';
import 'package:tephra/vault/providers.dart';
import 'package:tephra/vault/vault_session.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/tephra_index.dart';
import 'package:tephra_vault/tephra_vault.dart';

class _FakeNoteIndexNotifier extends NoteIndexNotifier {
  _FakeNoteIndexNotifier(this.index);
  final NoteIndex index;

  @override
  Future<NoteIndex> build() async => index;
}

class _FixedSessionNotifier extends VaultSessionNotifier {
  _FixedSessionNotifier(this.initialSession);
  final VaultSession initialSession;

  @override
  VaultSession? build() => initialSession;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PagePreview', () {
    late MemoryVaultFileSystem fs;
    late NoteIndex index;
    late VaultSession session;
    late AppSettings currentSettings;

    setUp(() async {
      fs = MemoryVaultFileSystem();
      await fs.writeText(
        VaultPath('Source.md'),
        const TextDocument(text: '[[Target]]'),
      );
      await fs.writeText(
        VaultPath('Target.md'),
        const TextDocument(text: '# Target Note\n\nContent in target note'),
      );

      await fs.writeText(
        VaultPath('Level1.md'),
        const TextDocument(text: 'Link to [[Level2]]'),
      );
      await fs.writeText(
        VaultPath('Level2.md'),
        const TextDocument(text: 'Link to [[Level3]]'),
      );
      await fs.writeText(
        VaultPath('Level3.md'),
        const TextDocument(text: 'Link to [[Level4]]'),
      );
      await fs.writeText(
        VaultPath('Level4.md'),
        const TextDocument(text: 'End note'),
      );

      index = await NoteIndex.open(':memory:', fs);
      await index.reconcile();

      session = VaultSession(
        vaultId: 'test-vault',
        rootDir: '/memory',
        name: 'Test',
        fs: fs,
        settings: const VaultSettings(),
      );

      currentSettings = const AppSettings(
        deviceId: 'test',
        pagePreviewReadingRequiresCtrl: false,
        pagePreviewEditorRequiresCtrl: true,
      );
    });

    tearDown(() async {
      await index.close();
    });

    Widget buildHarness({
      required Size size,
      required Widget child,
      AppSettings? settings,
    }) {
      return ProviderScope(
        overrides: [
          vaultSessionProvider.overrideWith(
            () => _FixedSessionNotifier(session),
          ),
          noteIndexProvider.overrideWith(() => _FakeNoteIndexNotifier(index)),
          initialAppSettingsProvider.overrideWithValue(
            settings ?? currentSettings,
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: MediaQueryData(size: size),
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: Scaffold(body: child),
            ),
          ),
        ),
      );
    }

    testWidgets('desktop width: hover 599 ms -> no popup; 601 ms -> popup', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildHarness(
          size: const Size(1200, 800),
          child: ReadingView(path: VaultPath('Source.md'), text: '[[Target]]'),
        ),
      );
      await tester.pumpAndSettle();

      final linkFinder = find.text('Target');
      expect(linkFinder, findsOneWidget);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(tester.getCenter(linkFinder));

      await tester.pump(const Duration(milliseconds: 599));
      expect(find.byType(PagePreviewPopup), findsNothing);

      await tester.pump(const Duration(milliseconds: 2));
      expect(find.byType(PagePreviewPopup), findsOneWidget);

      await gesture.removePointer();
    });

    testWidgets('with requires Ctrl: no popup unless Ctrl is held', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildHarness(
          size: const Size(1200, 800),
          settings: const AppSettings(
            deviceId: 'test',
            pagePreviewReadingRequiresCtrl: true,
          ),
          child: ReadingView(path: VaultPath('Source.md'), text: '[[Target]]'),
        ),
      );
      await tester.pumpAndSettle();

      final linkFinder = find.text('Target');
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(tester.getCenter(linkFinder));

      await tester.pump(const Duration(milliseconds: 601));
      expect(find.byType(PagePreviewPopup), findsNothing);

      // Now hold Ctrl and hover
      await simulateKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await gesture.moveTo(Offset.zero);
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveTo(tester.getCenter(linkFinder));

      await tester.pump(const Duration(milliseconds: 601));
      expect(find.byType(PagePreviewPopup), findsOneWidget);

      await simulateKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await gesture.removePointer();
    });

    testWidgets('phone width: long-press on link shows popup', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildHarness(
          size: const Size(400, 800),
          child: ReadingView(path: VaultPath('Source.md'), text: '[[Target]]'),
        ),
      );
      await tester.pumpAndSettle();

      final linkFinder = find.text('Target');
      expect(linkFinder, findsOneWidget);

      final linkPosition = tester.getTopLeft(linkFinder) + const Offset(10, 5);
      await tester.longPressAt(linkPosition);
      await tester.pumpAndSettle();

      expect(find.byType(PagePreviewPopup), findsOneWidget);
    });

    testWidgets('nested depth: opening a 4th popup is refused', (tester) async {
      late BuildContext testContext;

      await tester.pumpWidget(
        buildHarness(
          size: const Size(1200, 800),
          child: Builder(
            builder: (ctx) {
              testContext = ctx;
              return const Text('Test root');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(testContext);
      final controller = container.read(pagePreviewControllerProvider);

      // Popup 1 (depth 1)
      controller.showPreview(
        context: testContext,
        from: VaultPath('Source.md'),
        target: 'Level1',
        position: const Offset(100, 100),
        callerDepth: 0,
      );
      await tester.pumpAndSettle();
      expect(controller.stackDepth, equals(1));

      // Popup 2 (depth 2)
      controller.showPreview(
        context: testContext,
        from: VaultPath('Level1.md'),
        target: 'Level2',
        position: const Offset(150, 150),
        callerDepth: 1,
      );
      await tester.pumpAndSettle();
      expect(controller.stackDepth, equals(2));

      // Popup 3 (depth 3)
      controller.showPreview(
        context: testContext,
        from: VaultPath('Level2.md'),
        target: 'Level3',
        position: const Offset(200, 200),
        callerDepth: 2,
      );
      await tester.pumpAndSettle();
      expect(controller.stackDepth, equals(3));

      // Attempt popup 4 from depth 3: must be refused!
      controller.showPreview(
        context: testContext,
        from: VaultPath('Level3.md'),
        target: 'Level4',
        position: const Offset(250, 250),
        callerDepth: 3,
      );
      await tester.pumpAndSettle();
      expect(controller.stackDepth, equals(3)); // Still 3! Refused!
    });
  });
}
