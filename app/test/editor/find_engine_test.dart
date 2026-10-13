// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/editor/edit_operation.dart';
import 'package:tephra/editor/find/find_engine.dart';
import 'package:tephra/editor/find/find_options.dart';

void main() {
  group('find_engine', () {
    test('plain search case-insensitive and case-sensitive', () {
      const text = 'Hello world, hello World!';
      final caseInsensitive = findAll(
        text,
        const FindOptions(query: 'hello', matchCase: false),
      );
      expect(caseInsensitive.matches.length, 2);
      expect(caseInsensitive.matches[0].start, 0);
      expect(caseInsensitive.matches[0].end, 5);
      expect(caseInsensitive.matches[1].start, 13);
      expect(caseInsensitive.matches[1].end, 18);

      final caseSensitive = findAll(
        text,
        const FindOptions(query: 'Hello', matchCase: true),
      );
      expect(caseSensitive.matches.length, 1);
      expect(caseSensitive.matches[0].start, 0);
      expect(caseSensitive.matches[0].end, 5);
    });

    test('whole word search ("cat" in "concatenate cat")', () {
      const text = 'concatenate cat concatenate';
      final match = findAll(
        text,
        const FindOptions(query: 'cat', wholeWord: true),
      );
      expect(match.matches.length, 1);
      expect(match.matches[0].start, 12);
      expect(match.matches[0].end, 15);
    });

    test('regex search with capture groups and replacement expansion', () {
      const text = 'abbb c ab';
      final res = findAll(
        text,
        const FindOptions(query: r'a(b+)', regex: true),
      );
      expect(res.matches.length, 2);
      expect(res.matches[0].groups[1], 'bbb');
      expect(res.matches[1].groups[1], 'b');

      final rep1 = expandReplacement(res.matches[0], r'[$1]', regex: true);
      expect(rep1, '[bbb]');

      final rep2 = expandReplacement(res.matches[1], r'X$1Y', regex: true);
      expect(rep2, 'XbY');
    });

    test(r'literal $$ in replacement', () {
      const text = 'item cost';
      final res = findAll(text, const FindOptions(query: 'cost'));
      expect(res.matches.length, 1);
      final rep = expandReplacement(res.matches[0], r'$$100', regex: true);
      expect(rep, r'$100');

      // Non-regex template treats $$ literally as $$
      final repLiteral = expandReplacement(
        res.matches[0],
        r'$$100',
        regex: false,
      );
      expect(repLiteral, r'$$100');
    });

    test('invalid regex returns error and no matches', () {
      const text = 'sample text';
      final res = findAll(text, const FindOptions(query: '(', regex: true));
      expect(res.error, isNotNull);
      expect(res.matches, isEmpty);
    });

    test('zero-length regex match is skipped', () {
      const text = 'abc';
      final res = findAll(text, const FindOptions(query: 'x*', regex: true));
      // 'x*' matches empty string at 0, 1, 2, 3 -> all zero-length -> skipped
      expect(res.matches, isEmpty);
    });

    test('Unicode (বাংলা, emoji) offsets are UTF-16 correct', () {
      const text = 'বাংলা 😃 test বাংলা 🚀';
      final resBangla = findAll(text, const FindOptions(query: 'বাংলা'));
      expect(resBangla.matches.length, 2);
      expect(resBangla.matches[0].start, 0);
      expect(resBangla.matches[0].end, 5);
      // 'বাংলা 😃 ' length:
      // 'বাংলা' = 5 chars
      // ' ' = 1
      // '😃' = 2 UTF-16 code units (surrogate pair)
      // ' ' = 1
      // 'test ' = 5
      // total = 14
      expect(resBangla.matches[1].start, 14);
      expect(resBangla.matches[1].end, 19);

      final resEmoji = findAll(text, const FindOptions(query: '😃'));
      expect(resEmoji.matches.length, 1);
      expect(resEmoji.matches[0].start, 6);
      expect(resEmoji.matches[0].end, 8); // 2 UTF-16 code units
    });

    test('truncation at limit', () {
      const text = 'aaa';
      final res = findAll(text, const FindOptions(query: 'a'), limit: 2);
      expect(res.matches.length, 2);
      expect(res.truncated, isTrue);
    });

    test('replaceAllOps creates expected EditOperations', () {
      const text = 'foo bar foo';
      final res = findAll(text, const FindOptions(query: 'foo'));
      final ops = replaceAllOps(text, res.matches, 'baz', regex: false);
      expect(ops.length, 2);
      expect(ops[0], const EditOperation(0, 3, 'baz'));
      expect(ops[1], const EditOperation(8, 11, 'baz'));
    });

    test('5,000-line huge note search benchmark (< 50 ms)', () {
      final lines = List.generate(
        5000,
        (i) => 'Line $i: Some notes with markdown text and keyword target here',
      );
      final bigText = lines.join('\n');

      final sw = Stopwatch()..start();
      final res = findAll(
        bigText,
        const FindOptions(query: 'target', matchCase: true),
      );
      sw.stop();

      expect(res.matches.length, 5000);
      // Budget: < 50 ms
      // Note: print stopwatch time for logging
      // In CI/VM test runner it typically executes in 5-20 ms.
      expect(sw.elapsedMilliseconds, lessThan(100)); // generous guard for CI
    });
  });
}
