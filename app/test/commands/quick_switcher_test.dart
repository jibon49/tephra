// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/commands/quick_switcher.dart';
import 'package:tephra/commands/quick_switcher_items.dart';
import 'package:tephra/core/providers.dart';
import 'package:tephra/settings/app_settings.dart';
import 'package:tephra/workspace/providers.dart';
import 'package:tephra/workspace/tab_content.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_search/tephra_search.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../helpers/test_app.dart';

void main() {
  group('QuickSwitcher', () {
    late MemoryVaultFileSystem fs;

    setUp(() async {
      fs = MemoryVaultFileSystem();
      await fs.writeText(VaultPath('Alpha.md'), const TextDocument(text: 'A'));
      await fs.writeText(VaultPath('Beta.md'), const TextDocument(text: 'B'));
      await fs.writeText(VaultPath('Gamma.md'), const TextDocument(text: 'G'));
      await fs.writeText(
        VaultPath('Projects/Plan.md'),
        const TextDocument(text: 'P'),
      );
      await fs.writeText(VaultPath('Notes.md'), const TextDocument(text: 'N'));
      await fs.writeBytes(VaultPath('Cover.png'), [1, 2, 3]);
    });

    testWidgets('empty query lists recents and image is not listed', (
      tester,
    ) async {
      late WidgetRef capturedRef;

      await tester.pumpWidget(
        testApp(
          Consumer(
            builder: (context, ref, _) {
              capturedRef = ref;
              return ElevatedButton(
                onPressed: () => showQuickSwitcher(context),
                child: const Text('Open'),
              );
            },
          ),
          fs: fs,
        ),
      );

      await tester.pumpAndSettle();

      capturedRef.read(recentFilesProvider.notifier).set([
        VaultPath('Alpha.md'),
      ]);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('switcher.query')), findsOneWidget);
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Cover.png'), findsNothing);
      expect(find.text('Cover'), findsNothing);
    });

    testWidgets('typing narrows results and path query matches Projects/Plan', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showQuickSwitcher(context),
              child: const Text('Open'),
            ),
          ),
          fs: fs,
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('switcher.query')),
        'proj/pl',
      );
      await tester.pumpAndSettle();

      expect(find.text('Plan'), findsOneWidget);
      expect(find.text('Projects'), findsOneWidget);
    });

    testWidgets('Enter opens selected note', (tester) async {
      late WidgetRef capturedRef;

      await tester.pumpWidget(
        testApp(
          Consumer(
            builder: (context, ref, _) {
              capturedRef = ref;
              return ElevatedButton(
                onPressed: () => showQuickSwitcher(context),
                child: const Text('Open'),
              );
            },
          ),
          fs: fs,
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('switcher.query')), 'beta');
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('switcher.query')), findsNothing);
      final activePath = capturedRef.read(activeNotePathProvider);
      expect(activePath?.value, 'Beta.md');
    });

    testWidgets('Ctrl+Enter opens in a new tab', (tester) async {
      late WidgetRef capturedRef;

      await tester.pumpWidget(
        testApp(
          Consumer(
            builder: (context, ref, _) {
              capturedRef = ref;
              return ElevatedButton(
                onPressed: () => showQuickSwitcher(context),
                child: const Text('Open'),
              );
            },
          ),
          fs: fs,
        ),
      );

      await tester.pumpAndSettle();

      // Open a tab first
      capturedRef
          .read(workspaceProvider.notifier)
          .openPath(VaultPath('Alpha.md'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('switcher.query')), 'gamma');
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('switcher.query')), findsNothing);
      final tabs = capturedRef.read(workspaceProvider).panes[0].tabs;
      expect(tabs.length, 2);
    });

    testWidgets('no results + Enter creates Query.md and opens it', (
      tester,
    ) async {
      late WidgetRef capturedRef;

      await tester.pumpWidget(
        testApp(
          Consumer(
            builder: (context, ref, _) {
              capturedRef = ref;
              return ElevatedButton(
                onPressed: () => showQuickSwitcher(context),
                child: const Text('Open'),
              );
            },
          ),
          fs: fs,
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('switcher.query')),
        'BrandNewNote',
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('switcher.query')), findsNothing);
      final activePath = capturedRef.read(activeNotePathProvider);
      expect(activePath?.value, 'BrandNewNote.md');
      final stat = await fs.stat(VaultPath('BrandNewNote.md'));
      expect(stat, isNotNull);
    });

    testWidgets('Shift+Enter with results creates query name note', (
      tester,
    ) async {
      late WidgetRef capturedRef;

      await tester.pumpWidget(
        testApp(
          Consumer(
            builder: (context, ref, _) {
              capturedRef = ref;
              return ElevatedButton(
                onPressed: () => showQuickSwitcher(context),
                child: const Text('Open'),
              );
            },
          ),
          fs: fs,
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('switcher.query')), 'Al');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('switcher.row.Alpha.md')), findsOneWidget);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('switcher.query')), findsNothing);
      final activePath = capturedRef.read(activeNotePathProvider);
      expect(activePath?.value, 'Al.md');
      final stat = await fs.stat(VaultPath('Al.md'));
      expect(stat, isNotNull);
    });

    testWidgets('phone width displays switcher.create row', (tester) async {
      await tester.pumpWidget(
        testApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showQuickSwitcher(context),
              child: const Text('Open'),
            ),
          ),
          fs: fs,
          size: const Size(400, 800),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('switcher.query')),
        'CustomIdea',
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('switcher.create')), findsOneWidget);
    });

    testWidgets('alias row selects its note', (tester) async {
      await fs.writeText(
        VaultPath('Config.md'),
        const TextDocument(text: '---\naliases: [MyConfigAlias]\n---\nBody'),
      );
      late WidgetRef capturedRef;

      await tester.pumpWidget(
        testApp(
          Consumer(
            builder: (context, ref, _) {
              capturedRef = ref;
              return ElevatedButton(
                onPressed: () => showQuickSwitcher(context),
                child: const Text('Open'),
              );
            },
          ),
          fs: fs,
        ),
      );
      await tester.pumpAndSettle();

      final index = await capturedRef.read(noteIndexProvider.future);
      await index.reconcile();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('switcher.query')),
        'MyConfig',
      );
      await tester.pumpAndSettle();

      expect(find.text('MyConfigAlias'), findsOneWidget);
      expect(find.text('→ Config'), findsOneWidget);

      await tester.tap(find.text('MyConfigAlias'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('switcher.query')), findsNothing);
      final activePath = capturedRef.read(activeNotePathProvider);
      expect(activePath?.value, 'Config.md');
    });

    testWidgets('#Set lists headings and selecting opens note at heading', (
      tester,
    ) async {
      await fs.writeText(
        VaultPath('Settings.md'),
        const TextDocument(text: '# Set Preferences\nBody text here'),
      );
      late WidgetRef capturedRef;

      await tester.pumpWidget(
        testApp(
          Consumer(
            builder: (context, ref, _) {
              capturedRef = ref;
              return ElevatedButton(
                onPressed: () => showQuickSwitcher(context),
                child: const Text('Open'),
              );
            },
          ),
          fs: fs,
        ),
      );
      await tester.pumpAndSettle();

      final index = await capturedRef.read(noteIndexProvider.future);
      await index.reconcile();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('switcher.query')), '#Set');
      await tester.pumpAndSettle();

      expect(find.text('Set Preferences'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);

      await tester.tap(find.text('Set Preferences'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('switcher.query')), findsNothing);
      final activePath = capturedRef.read(activeNotePathProvider);
      expect(activePath?.value, 'Settings.md');
      final content = capturedRef.read(workspaceProvider).focusedTab?.content;
      expect(content, isA<FileTabContent>());
      expect((content as FileTabContent).subpath, '#Set Preferences');
    });

    testWidgets('recent note ranks above an equally scored non-recent one', (
      tester,
    ) async {
      await fs.writeText(
        VaultPath('NoteA.md'),
        const TextDocument(text: 'Note A content'),
      );
      await fs.writeText(
        VaultPath('NoteB.md'),
        const TextDocument(text: 'Note B content'),
      );
      late WidgetRef capturedRef;

      await tester.pumpWidget(
        testApp(
          Consumer(
            builder: (context, ref, _) {
              capturedRef = ref;
              return ElevatedButton(
                onPressed: () => showQuickSwitcher(context),
                child: const Text('Open'),
              );
            },
          ),
          fs: fs,
        ),
      );
      await tester.pumpAndSettle();

      final index = await capturedRef.read(noteIndexProvider.future);
      await index.reconcile();
      await tester.pumpAndSettle();

      capturedRef.read(recentFilesProvider.notifier).set([
        VaultPath('NoteB.md'),
      ]);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('switcher.query')), 'Note');
      await tester.pumpAndSettle();

      final noteAPos = tester.getTopLeft(find.text('NoteA'));
      final noteBPos = tester.getTopLeft(find.text('NoteB'));

      // NoteB has recent boost so it must appear above NoteA (smaller Y)
      expect(noteBPos.dy, lessThan(noteAPos.dy));
    });

    testWidgets('switcherShowAttachments setting includes attachments', (
      tester,
    ) async {
      late WidgetRef capturedRef;

      await tester.pumpWidget(
        testApp(
          Consumer(
            builder: (context, ref, _) {
              capturedRef = ref;
              return ElevatedButton(
                onPressed: () => showQuickSwitcher(context),
                child: const Text('Open'),
              );
            },
          ),
          fs: fs,
          appSettings: const AppSettings(
            deviceId: 'test',
            switcherShowAttachments: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final index = await capturedRef.read(noteIndexProvider.future);
      await index.reconcile();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('switcher.query')), 'Cover');
      await tester.pumpAndSettle();

      expect(find.text('Cover.png'), findsOneWidget);
    });

    test('10,000-item rank completes in < 50 ms', () {
      final items = List.generate(10000, (i) {
        final path = VaultPath('folder$i/Note$i.md');
        return SwitcherItem(
          path: path,
          primary: 'Note$i',
          secondary: 'folder$i',
          primaryLower: 'note$i',
          pathLower: 'folder$i/note$i.md',
        );
      });

      final recents = [
        VaultPath('folder1/Note1.md'),
        VaultPath('folder2/Note2.md'),
      ];

      const q = 'note55';
      final sw = Stopwatch()..start();

      final scored = <(SwitcherItem, int)>[];
      for (final item in items) {
        final primaryScore = FuzzyScorer.score(q, item.primary);
        if (primaryScore != null) {
          final recentRank = recents.indexOf(item.path);
          final recentBoost = (recentRank >= 0 && recentRank < 10)
              ? (50 - 5 * recentRank)
              : 0;
          scored.add((item, primaryScore + recentBoost));
        }
      }
      scored.sort((a, b) => b.$2.compareTo(a.$2));
      final top50 = scored.take(50).toList();
      sw.stop();

      // ignore: avoid_print
      print(
        'QuickSwitcher 10,000 items rank time: ${sw.elapsedMilliseconds} ms (${top50.length} items)',
      );
      expect(sw.elapsedMilliseconds, lessThan(50));
    });
  });
}
