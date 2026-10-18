// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/commands/quick_switcher_items.dart';
import 'package:tephra/editor/autocomplete/autocomplete_ranker.dart';
import 'package:tephra/editor/autocomplete/block_candidates.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/tephra_index.dart';

void main() {
  group('AutocompleteRanker', () {
    test('rankNotes calculates expected scores and order', () {
      final pPlan = VaultPath('Project Plan.md');
      final plan = VaultPath('Plan.md');
      final planet = VaultPath('Planet.md');
      final aPlan = VaultPath('Alpha Plan.md');

      final items = [
        SwitcherItem(path: pPlan, primary: 'Project Plan'),
        SwitcherItem(path: plan, primary: 'Plan'),
        SwitcherItem(path: planet, primary: 'Planet'),
        SwitcherItem(path: aPlan, primary: 'Alpha Plan'),
        SwitcherItem(
          path: pPlan,
          primary: 'Planner',
          secondary: '→ Project Plan',
          isAlias: true,
        ),
      ];

      final ranked = AutocompleteRanker.rankNotes('plan', items, const []);

      expect(ranked.map((e) => e.primary).toList(), [
        'Plan',
        'Planet',
        'Planner',
        'Alpha Plan',
        'Project Plan',
      ]);

      expect(ranked[0].score, equals(1000));
      expect(ranked[1].score, equals(898));
      expect(ranked[2].score, equals(897));
      expect(ranked[3].score, equals(694));
      expect(ranked[4].score, equals(692));

      // With recent list [Project Plan], Project Plan scores 742 (692 + 50)
      final withRecent = AutocompleteRanker.rankNotes('plan', items, [pPlan]);

      expect(withRecent.map((e) => e.primary).toList(), [
        'Plan',
        'Planet',
        'Planner',
        'Project Plan',
        'Alpha Plan',
      ]);
      expect(
        withRecent.firstWhere((e) => e.primary == 'Project Plan').score,
        equals(742),
      );
    });

    test('60 matching items returns exactly 50', () {
      final items = [
        for (var i = 0; i < 60; i++)
          SwitcherItem(path: VaultPath('Item $i.md'), primary: 'Item $i'),
      ];

      final ranked = AutocompleteRanker.rankNotes('item', items, const []);
      expect(ranked.length, equals(50));
    });

    test('empty query returns recents first', () {
      final p1 = VaultPath('Note1.md');
      final p2 = VaultPath('Note2.md');
      final p3 = VaultPath('Note3.md');

      final items = [
        SwitcherItem(path: p1, primary: 'Note1'),
        SwitcherItem(path: p2, primary: 'Note2'),
        SwitcherItem(path: p3, primary: 'Note3'),
      ];

      final ranked = AutocompleteRanker.rankNotes('', items, [p3, p1]);
      expect(ranked.map((e) => e.primary).toList(), [
        'Note3',
        'Note1',
        'Note2',
      ]);
    });

    test('rankHeadings empty query keeps document order', () {
      final path = VaultPath('Doc.md');
      final headings = [
        HeadingRecord(
          path: path,
          level: 1,
          text: 'Intro',
          start: 0,
          end: 7,
          line: 1,
          ordinal: 1,
        ),
        HeadingRecord(
          path: path,
          level: 2,
          text: 'Setup',
          start: 8,
          end: 16,
          line: 2,
          ordinal: 2,
        ),
        HeadingRecord(
          path: path,
          level: 1,
          text: 'Usage',
          start: 17,
          end: 25,
          line: 3,
          ordinal: 3,
        ),
      ];

      final rankedEmpty = AutocompleteRanker.rankHeadings('', headings);
      expect(rankedEmpty.map((e) => e.primary).toList(), [
        'Intro',
        'Setup',
        'Usage',
      ]);

      final rankedQuery = AutocompleteRanker.rankHeadings('set', headings);
      expect(rankedQuery.first.primary, equals('Setup'));
      expect(rankedQuery.first.secondary, equals('H2'));
    });

    test('rankBlocks finds block whose preview contains search word', () {
      final blocks = [
        const BlockCandidate(
          start: 0,
          end: 10,
          line: 1,
          kind: BlockKind.paragraph,
          preview: 'buy bread and butter',
        ),
        const BlockCandidate(
          start: 11,
          end: 25,
          line: 2,
          kind: BlockKind.paragraph,
          preview: 'fresh milk from farm',
        ),
      ];

      final ranked = AutocompleteRanker.rankBlocks('milk', blocks);
      expect(ranked.length, equals(1));
      expect(ranked.first.primary, equals('fresh milk from farm'));
    });

    test(
      'narrowing ranking "pla" then "plan" equals full ranking of "plan"',
      () {
        final pPlan = VaultPath('Project Plan.md');
        final plan = VaultPath('Plan.md');
        final planet = VaultPath('Planet.md');
        final aPlan = VaultPath('Alpha Plan.md');

        final items = [
          SwitcherItem(path: pPlan, primary: 'Project Plan'),
          SwitcherItem(path: plan, primary: 'Plan'),
          SwitcherItem(path: planet, primary: 'Planet'),
          SwitcherItem(path: aPlan, primary: 'Alpha Plan'),
          SwitcherItem(
            path: pPlan,
            primary: 'Planner',
            secondary: '→ Project Plan',
            isAlias: true,
          ),
        ];

        final plaResult = AutocompleteRanker.rankNotes('pla', items, const []);
        final planNarrow = AutocompleteRanker.rankNotes(
          'plan',
          items,
          const [],
          previousCandidates: plaResult,
        );
        final planFull = AutocompleteRanker.rankNotes('plan', items, const []);

        expect(
          planNarrow.map((e) => e.primary).toList(),
          equals(planFull.map((e) => e.primary).toList()),
        );
      },
    );

    test('timing: 10,000 items ranks in < 16 ms', () {
      final items = [
        for (var i = 0; i < 10000; i++)
          SwitcherItem(
            path: VaultPath('Folder/Alpha $i.md'),
            primary: 'Alpha $i',
            secondary: 'Folder',
          ),
      ];

      // Warm up JIT
      for (var i = 0; i < 10; i++) {
        AutocompleteRanker.rankNotes('a', items, const []);
      }

      var minElapsed = 999999;
      var resultLength = 0;
      for (var i = 0; i < 5; i++) {
        final sw = Stopwatch()..start();
        final r = AutocompleteRanker.rankNotes('a', items, const []);
        sw.stop();
        if (sw.elapsedMilliseconds < minElapsed) {
          minElapsed = sw.elapsedMilliseconds;
          resultLength = r.length;
        }
        if (minElapsed < 16) break;
      }

      // ignore: avoid_print
      print('perf rankNotes 10,000 items: $minElapsed ms');
      expect(resultLength, equals(50));
      expect(minElapsed, lessThan(16));
    });
  });
}
