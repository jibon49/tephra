// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_markdown/tephra_markdown.dart';
import 'package:tephra_search/tephra_search.dart';
import 'package:test/test.dart';

NoteDoc _makeDoc({required String path, required String text}) {
  final vp = VaultPath(path);
  final parsed = MarkdownParser.parse(text);
  return NoteDoc.create(path: vp, text: text, parsed: parsed);
}

void main() {
  group('SearchMatcher', () {
    test('meeting in "The meeting. Meeting!" -> 2 matches on line 0 with correct snippetStart/End', () {
      final doc = _makeDoc(path: 'Test.md', text: 'The meeting. Meeting!');
      final outcome = evaluate(
        SearchParser.parse('meeting'),
        doc,
        caseSensitive: false,
      );
      expect(outcome.matched, isTrue);
      expect(outcome.matches.length, equals(2));

      final m1 = outcome.matches[0];
      expect(m1.line, equals(0));
      expect(m1.start, equals(4));
      expect(m1.end, equals(11));
      expect(
        m1.snippet.substring(m1.snippetStart, m1.snippetEnd),
        equals('meeting'),
      );

      final m2 = outcome.matches[1];
      expect(m2.line, equals(0));
      expect(m2.start, equals(13));
      expect(m2.end, equals(20));
      expect(
        m2.snippet.substring(m2.snippetStart, m2.snippetEnd),
        equals('Meeting'),
      );
    });

    test('line:(a b) true for "a b", false for "a\\nb"', () {
      final expr = SearchParser.parse('line:(a b)');

      final doc1 = _makeDoc(path: 'Doc1.md', text: 'a b');
      expect(evaluate(expr, doc1, caseSensitive: false).matched, isTrue);

      final doc2 = _makeDoc(path: 'Doc2.md', text: 'a\nb');
      expect(evaluate(expr, doc2, caseSensitive: false).matched, isFalse);
    });

    test('section: boundaries with # and ## mixes', () {
      final text = '''
# Heading 1
Some intro about coffee.
## Sub 1
Coffee details here.
# Heading 2
Tea details here.
''';
      final doc = _makeDoc(path: 'Sections.md', text: text);

      // Same section under ## Sub 1
      final q1 = SearchParser.parse('section:(coffee details)');
      expect(evaluate(q1, doc, caseSensitive: false).matched, isTrue);

      // Cross sections between Sub 1 and Heading 2
      final q2 = SearchParser.parse('section:(coffee tea)');
      expect(evaluate(q2, doc, caseSensitive: false).matched, isFalse);
    });

    test('[p:] with p: [] is matched', () {
      final doc = _makeDoc(
        path: 'EmptyList.md',
        text: '''---
p: []
---
Body text
''',
      );
      final q = SearchParser.parse('[p:]');
      expect(evaluate(q, doc, caseSensitive: false).matched, isTrue);
    });

    test('regex with m flag matches across lines', () {
      final doc = _makeDoc(
        path: 'Multiline.md',
        text: 'first line\nsecond line',
      );
      final q = SearchParser.parse(r'/^second/m');
      expect(evaluate(q, doc, caseSensitive: false).matched, isTrue);
    });

    test('match-case vs ignore-case nesting: match-case:(A ignore-case:b)', () {
      final q = SearchParser.parse('match-case:(A ignore-case:b)');

      // Doc with uppercase 'A' and uppercase 'B'
      final doc1 = _makeDoc(path: 'Doc1.md', text: 'A B');
      expect(evaluate(q, doc1, caseSensitive: false).matched, isTrue);

      // Doc with lowercase 'a' and lowercase 'b' -> 'a' fails case-sensitive 'A'
      final doc2 = _makeDoc(path: 'Doc2.md', text: 'a b');
      expect(evaluate(q, doc2, caseSensitive: false).matched, isFalse);
    });
  });
}
