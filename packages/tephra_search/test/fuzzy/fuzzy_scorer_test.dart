// © 2026 Tephra. All rights reserved.

import 'package:tephra_search/tephra_search.dart';
import 'package:test/test.dart';

void main() {
  group('FuzzyScorer', () {
    test('exact match scores 1000', () {
      expect(FuzzyScorer.score('note', 'note'), 1000);
      expect(FuzzyScorer.score('Note', 'note'), 1000);
      expect(FuzzyScorer.score('note', 'NOTE'), 1000);
    });

    test('prefix match scores 900 - len diff', () {
      expect(FuzzyScorer.score('no', 'notes'), 897);
    });

    test('word start occurrence scores 700 - index', () {
      expect(FuzzyScorer.score('pl', 'project plan'), 692);
    });

    test('substring occurrence scores 500 - index', () {
      expect(FuzzyScorer.score('ject', 'project'), 497);
    });

    test(
      'subsequence scores 300 - 2*gaps - min(50, first) + 10*wordStarts',
      () {
        expect(FuzzyScorer.score('mtg', 'meeting'), 306);
      },
    );

    test('no match returns null', () {
      expect(FuzzyScorer.score('xyz', 'meeting'), isNull);
    });

    test('ranking order for query "al"', () {
      expect(FuzzyScorer.score('al', 'Alpha'), 897);
      expect(FuzzyScorer.score('al', 'Gallery'), 499);
      expect(FuzzyScorer.score('al', 'Total'), 497);
      expect(FuzzyScorer.score('al', 'A l'), 318);

      final scores = <String, int?>{
        'Alpha': FuzzyScorer.score('al', 'Alpha'),
        'Gallery': FuzzyScorer.score('al', 'Gallery'),
        'Total': FuzzyScorer.score('al', 'Total'),
        'A l': FuzzyScorer.score('al', 'A l'),
      };

      final sorted = scores.keys.toList()
        ..sort((a, b) => (scores[b] ?? 0).compareTo(scores[a] ?? 0));

      expect(sorted, ['Alpha', 'Gallery', 'Total', 'A l']);
    });

    test('empty query returns 0', () {
      expect(FuzzyScorer.score('', 'anything'), 0);
      expect(FuzzyScorer.score('   ', 'anything'), 0);
    });

    test(
      'matchRanges returns correct character ranges and merges adjacent',
      () {
        expect(FuzzyScorer.matchRanges('mtg', 'meeting'), [
          (0, 1),
          (3, 4),
          (6, 7),
        ]);
        expect(FuzzyScorer.matchRanges('no', 'notes'), [(0, 2)]);
      },
    );
  });
}
