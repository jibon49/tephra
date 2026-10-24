// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/commands/command_registry.dart';
import 'package:tephra/l10n/app_localizations.dart';
import 'package:tephra/stickies/commands/sticky_commands.dart';
import 'package:tephra/stickies/data/sticky_repository.dart';
import 'package:tephra/stickies/model/sticky_color.dart';
import 'package:tephra/stickies/providers.dart';
import 'package:tephra/workspace/providers.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../fakes.dart';

void main() {
  group('StickyCommands', () {
    late MemoryVaultFileSystem fs;
    late FakeSearchEngine search;
    late FakeOpenNoteBridge openNotes;
    late StickyRepository repo;

    setUp(() {
      fs = MemoryVaultFileSystem();
      search = FakeSearchEngine(fs);
      openNotes = FakeOpenNoteBridge();
      repo = StickyRepository(
        fs: fs,
        search: search,
        settings: const StickySettingsView(
          stickyFolder: 'Stickies',
          defaultColor: NamedStickyColor.yellow,
        ),
        openNotes: openNotes,
        clock: ManualClock(DateTime(2026, 10, 11, 9, 30, 5)),
      );
    });

    tearDown(() async {
      await repo.dispose();
      openNotes.dispose();
    });

    test('all twelve ids registered', () {
      final registry = CommandRegistry();
      registerStickyCommands(registry);

      final registeredIds = registry.all.map((c) => c.id).toSet();
      const expected = {
        'sticky.new',
        'sticky.pin-note',
        'sticky.unpin',
        'sticky.set-color',
        'sticky.lock',
        'sticky.set-reminder',
        'sticky.set-expiry',
        'sticky.open-window',
        'sticky.show-all',
        'sticky.hide-all',
        'sticky.board',
        'capture.quick-note',
      };

      for (final id in expected) {
        expect(
          registeredIds.contains(id),
          isTrue,
          reason: 'Missing command $id',
        );
      }
    });

    testWidgets(
      'pin-note unavailable on a sticky and available on normal note',
      (tester) async {
        final registry = CommandRegistry();
        registerStickyCommands(registry);
        final pinCmd = registry.byId('sticky.pin-note')!;

        final stickyPath = VaultPath('Stickies/Note1.md');
        await fs.writeText(
          stickyPath,
          TextDocument(text: '---\ntephra-sticky: true\n---\nHello'),
        );
        await repo.start();

        final normalPath = VaultPath('Normal.md');
        await fs.writeText(normalPath, TextDocument(text: 'Just plain text'));

        // Test with active note as sticky
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              stickyRepositoryProvider.overrideWithValue(repo),
              activeNotePathProvider.overrideWithValue(stickyPath),
            ],
            child: Consumer(
              builder: (context, ref, _) {
                expect(pinCmd.isAvailable!(ref), isFalse);
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        // Test with active note as normal note
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              stickyRepositoryProvider.overrideWithValue(repo),
              activeNotePathProvider.overrideWithValue(normalPath),
            ],
            child: Consumer(
              builder: (context, ref, _) {
                expect(pinCmd.isAvailable!(ref), isTrue);
                return const SizedBox.shrink();
              },
            ),
          ),
        );
      },
    );

    testWidgets('unpin available on a sticky and unavailable on normal note', (
      tester,
    ) async {
      final registry = CommandRegistry();
      registerStickyCommands(registry);
      final unpinCmd = registry.byId('sticky.unpin')!;

      final stickyPath = VaultPath('Stickies/Note1.md');
      await fs.writeText(
        stickyPath,
        TextDocument(text: '---\ntephra-sticky: true\n---\nHello'),
      );
      await repo.start();

      final normalPath = VaultPath('Normal.md');
      await fs.writeText(normalPath, TextDocument(text: 'Just plain text'));

      // Test with active note as sticky
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            stickyRepositoryProvider.overrideWithValue(repo),
            activeNotePathProvider.overrideWithValue(stickyPath),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              expect(unpinCmd.isAvailable!(ref), isTrue);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      // Test with active note as normal note
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            stickyRepositoryProvider.overrideWithValue(repo),
            activeNotePathProvider.overrideWithValue(normalPath),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              expect(unpinCmd.isAvailable!(ref), isFalse);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('lock toggles meta.locked', (tester) async {
      final registry = CommandRegistry();
      registerStickyCommands(registry);
      final lockCmd = registry.byId('sticky.lock')!;

      final stickyPath = VaultPath('Stickies/Note1.md');
      await fs.writeText(
        stickyPath,
        TextDocument(text: '---\ntephra-sticky: true\n---\nHello'),
      );
      await repo.start();

      late WidgetRef capturedRef;
      late BuildContext capturedContext;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            stickyRepositoryProvider.overrideWithValue(repo),
            activeNotePathProvider.overrideWithValue(stickyPath),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  capturedRef = ref;
                  capturedContext = context;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );

      expect(repo.byPath(stickyPath)?.meta.locked, isFalse);

      // Run lock toggle: false -> true
      lockCmd.run(capturedRef, capturedContext);
      await tester.pumpAndSettle();

      expect(repo.byPath(stickyPath)?.meta.locked, isTrue);

      // Run lock toggle: true -> false
      lockCmd.run(capturedRef, capturedContext);
      await tester.pumpAndSettle();

      expect(repo.byPath(stickyPath)?.meta.locked, isFalse);
    });

    testWidgets('set-color applies picked colour', (tester) async {
      final registry = CommandRegistry();
      registerStickyCommands(registry);
      final colorCmd = registry.byId('sticky.set-color')!;

      final stickyPath = VaultPath('Stickies/Note1.md');
      await fs.writeText(
        stickyPath,
        TextDocument(
          text: '---\ntephra-sticky: true\nsticky-color: yellow\n---\nHello',
        ),
      );
      await repo.start();

      late WidgetRef capturedRef;
      late BuildContext capturedContext;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            stickyRepositoryProvider.overrideWithValue(repo),
            activeNotePathProvider.overrideWithValue(stickyPath),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  capturedRef = ref;
                  capturedContext = context;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );

      expect(repo.byPath(stickyPath)?.meta.color, NamedStickyColor.yellow);

      // Run color command -> opens StickyColorPicker dialog
      colorCmd.run(capturedRef, capturedContext);
      await tester.pumpAndSettle();

      // Tap the Pink swatch
      await tester.tap(find.bySemanticsLabel('Pink'));
      await tester.pumpAndSettle();

      // Color has been updated to pink
      expect(repo.byPath(stickyPath)?.meta.color, NamedStickyColor.pink);
    });
  });
}
