// © 2026 Tephra. All rights reserved.

import 'package:tephra_index/src/util/snippet.dart';
import 'package:test/test.dart';

void main() {
  group('makeSnippet', () {
    test('short line returned whole', () {
      final snippet = makeSnippet('Hello world, this is a test.', 6, 11);
      expect(snippet.text, equals('Hello world, this is a test.'));
      expect(snippet.start, equals(6));
      expect(snippet.end, equals(11));
      expect(
        snippet.text.substring(snippet.start, snippet.end),
        equals('world'),
      );
    });

    test('short line with leading whitespace trimmed', () {
      final snippet = makeSnippet('   Hello world', 9, 14);
      expect(snippet.text, equals('Hello world'));
      expect(snippet.start, equals(6));
      expect(snippet.end, equals(11));
      expect(
        snippet.text.substring(snippet.start, snippet.end),
        equals('world'),
      );
    });

    test('400-character line with match at 300', () {
      // 400 chars total: 300 chars before 'MATCH', then 'MATCH' (5), then 95 chars after = 400.
      final before = 'a' * 300;
      const match = 'MATCH';
      final after = 'b' * 95;
      final line = before + match + after;
      expect(line.length, equals(400));

      final snippet = makeSnippet(line, 300, 305);
      expect(snippet.text.length, lessThanOrEqualTo(162));
      expect(snippet.text.startsWith('…'), isTrue);
      expect(
        snippet.text.substring(snippet.start, snippet.end),
        equals('MATCH'),
      );
    });
  });
}
