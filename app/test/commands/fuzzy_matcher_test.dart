// © 2026 Tephra. All rights reserved.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/commands/fuzzy_matcher.dart';

void main() {
  group('FuzzyMatcher', () {
    test('exact 7 required values from spec', () {
      expect(FuzzyMatcher.score('abc', 'abc'), 161);
      expect(FuzzyMatcher.score('abc', 'a-b-c'), 75);
      expect(FuzzyMatcher.score('abc', 'xabc'), 45);
      expect(FuzzyMatcher.score('xyz', 'abc'), isNull);
      expect(FuzzyMatcher.score('', 'abc'), 0);
      expect(FuzzyMatcher.matchRanges('mtg', 'meeting'), [
        (0, 1),
        (3, 4),
        (6, 7),
      ]);
      expect(FuzzyMatcher.matchRanges('no', 'notes'), [(0, 2)]);
    });

    test('ordering requirements', () {
      final s1 = FuzzyMatcher.score('note', 'note')!;
      final s2 = FuzzyMatcher.score('note', 'notes')!;
      final s3 = FuzzyMatcher.score('note', 'a note')!;
      final s4 = FuzzyMatcher.score('note', 'n-o-t-e')!;

      expect(s1, greaterThan(s2));
      expect(s2, greaterThan(s4));
      expect(s4, greaterThan(s3));
    });

    test('case insensitivity', () {
      expect(
        FuzzyMatcher.score('ABC', 'abc'),
        FuzzyMatcher.score('abc', 'ABC'),
      );
      expect(FuzzyMatcher.score('nOtE', 'NoTeS'), isNotNull);
    });

    test('query longer than candidate returns null', () {
      expect(FuzzyMatcher.score('longerquery', 'short'), isNull);
    });

    test('Bangla support', () {
      final score = FuzzyMatcher.score('বাং', 'বাংলা');
      expect(score, isNotNull);
    });

    test('scoring 10,000 random 20-char strings takes < 50 ms', () {
      final rand = Random(42);
      const chars = 'abcdefghijklmnopqrstuvwxyz';
      final strings = List.generate(10000, (_) {
        return List.generate(
          20,
          (_) => chars[rand.nextInt(chars.length)],
        ).join();
      });

      final sw = Stopwatch()..start();
      for (final s in strings) {
        FuzzyMatcher.score('abc', s);
      }
      sw.stop();

      // ignore: avoid_print
      print('FuzzyMatcher 10k items elapsed: ${sw.elapsedMilliseconds} ms');
      expect(sw.elapsedMilliseconds, lessThan(50));
    });
  });
}
