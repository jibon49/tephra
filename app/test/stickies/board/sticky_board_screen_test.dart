// © 2026 Tephra. All rights reserved.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/core/providers.dart';
import 'package:tephra/l10n/app_localizations.dart';
import 'package:tephra/stickies/board/board_controller.dart';
import 'package:tephra/stickies/board/board_layout.dart';
import 'package:tephra/stickies/board/sticky_board_screen.dart';
import 'package:tephra/stickies/data/sticky_repository.dart';
import 'package:tephra/stickies/model/sticky_color.dart';
import 'package:tephra/stickies/providers.dart';
import 'package:tephra/vault/providers.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../fakes.dart';

void main() {
  late MemoryVaultFileSystem fs;
  late FakeSearchEngine search;
  late FakeOpenNoteBridge openNotes;
  late ManualClock clock;
  late StickyRepository repository;

  setUp(() async {
    fs = MemoryVaultFileSystem();
    search = FakeSearchEngine(fs);
    openNotes = FakeOpenNoteBridge();
    clock = ManualClock(DateTime(2026, 10, 11, 9, 30, 5));

    repository = StickyRepository(
      fs: fs,
      search: search,
      settings: const StickySettingsView(),
      openNotes: openNotes,
      clock: clock,
    );
    await repository.start();
  });

  tearDown(() async {
    await repository.dispose();
  });

  Widget buildScreen({BoardController? controller}) {
    return ProviderScope(
      overrides: [
        vaultFsProvider.overrideWithValue(fs),
        stickyRepositoryProvider.overrideWithValue(repository),
        clockProvider.overrideWithValue(clock),
        if (controller != null)
          boardControllerProvider.overrideWith(() => controller),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: StickyBoardScreen(),
      ),
    );
  }

  group('StickyBoardScreen', () {
    testWidgets('double tap on empty space creates sticky', (tester) async {
      final controller = BoardController(random: Random(42));

      await tester.pumpWidget(buildScreen(controller: controller));
      await tester.pumpAndSettle();

      expect(repository.all, isEmpty);

      // Double tap on the board area
      await tester.tap(find.byType(InteractiveViewer));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byType(InteractiveViewer));
      await tester.pumpAndSettle();

      expect(repository.all, hasLength(1));
      expect(find.byType(TextField), findsOneWidget); // Quick editor opened
    });

    testWidgets('layout by colour then undo restores positions', (
      tester,
    ) async {
      await repository.create(
        body: 'Yellow content',
        color: NamedStickyColor.yellow,
      );
      await repository.create(
        body: 'Pink content',
        color: NamedStickyColor.pink,
      );

      final controller = BoardController(random: Random(42));
      await tester.pumpWidget(buildScreen(controller: controller));
      await tester.pumpAndSettle();

      final initialDoc = controller.state.doc;
      final initialPositions = {
        for (final n in initialDoc.nodes)
          n.id: Offset(n.x.toDouble(), n.y.toDouble()),
      };

      // Open layout menu
      await tester.tap(find.byType(PopupMenuButton<BoardLayoutMode>));
      await tester.pumpAndSettle();

      // Choose "By colour"
      final byColorItem = find.text('By colour');
      expect(byColorItem, findsOneWidget);
      await tester.tap(byColorItem);
      await tester.pumpAndSettle();

      // Check snackbar with undo is shown
      expect(find.text('Layout applied'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);

      // Tap Undo
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      final restoredDoc = controller.state.doc;
      for (final n in restoredDoc.nodes) {
        expect(Offset(n.x.toDouble(), n.y.toDouble()), initialPositions[n.id]);
      }
    });

    testWidgets('checkbox toggle writes note', (tester) async {
      final sticky = await repository.create(
        body: '# Tasks\n- [ ] Milk\n',
        color: NamedStickyColor.yellow,
      );

      final controller = BoardController(random: Random(42));
      await tester.pumpWidget(buildScreen(controller: controller));
      await tester.pumpAndSettle();

      final checkbox = find.byType(Checkbox);
      expect(checkbox, findsOneWidget);

      await tester.tap(checkbox);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      final updatedSticky = repository.byPath(sticky.path);
      expect(updatedSticky?.text, contains('- [x] Milk'));
    });
  });
}
