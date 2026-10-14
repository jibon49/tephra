// © 2026 Tephra. All rights reserved.

import 'package:tephra_search/tephra_search.dart';
import 'package:test/test.dart';

void main() {
  group('SqlCompiler', () {
    test('ftsPhrase escapes quotes and wraps in double quotes', () {
      expect(ftsPhrase('say "hi" AND x'), equals(r'"say ""hi"" AND x"'));
    });

    test('exact flag check on individual expressions', () {
      // meeting (>= 3 chars, case-insensitive, fileScope): exact = true
      final qMeeting = SqlCompiler.compile(
        SearchParser.parse('meeting'),
        caseSensitive: false,
      );
      expect(qMeeting.exact, isTrue);

      // ox (< 3 chars): exact = false
      final qOx = SqlCompiler.compile(
        SearchParser.parse('ox'),
        caseSensitive: false,
      );
      expect(qOx.exact, isFalse);

      // match-case:meeting: exact = false
      final qMatchCase = SqlCompiler.compile(
        SearchParser.parse('match-case:meeting'),
        caseSensitive: false,
      );
      expect(qMatchCase.exact, isFalse);

      // -meeting: exact = true
      final qNotMeeting = SqlCompiler.compile(
        SearchParser.parse('-meeting'),
        caseSensitive: false,
      );
      expect(qNotMeeting.exact, isTrue);

      // line:(-a): exact = false
      final qLineNotA = SqlCompiler.compile(
        SearchParser.parse('line:(-a)'),
        caseSensitive: false,
      );
      expect(qLineNotA.exact, isFalse);

      // tag:x: exact = true
      final qTag = SqlCompiler.compile(
        SearchParser.parse('tag:x'),
        caseSensitive: false,
      );
      expect(qTag.exact, isTrue);

      // /x/: exact = false
      final qRegex = SqlCompiler.compile(
        SearchParser.parse('/x/'),
        caseSensitive: false,
      );
      expect(qRegex.exact, isFalse);
    });

    test('generated SQL for a -b contains EXCEPT', () {
      final q = SqlCompiler.compile(
        SearchParser.parse('alpha -beta'),
        caseSensitive: false,
      );
      expect(q.sql, contains('EXCEPT'));
    });

    test('a 60-deep nested group compiles to ALL', () {
      // Construct a deeply nested expression tree directly
      SearchExpr deep = const TermExpr('meeting');
      for (var i = 0; i < 60; i++) {
        deep = OperatorExpr(SearchOperator.line, deep);
      }
      final compiled = SqlCompiler.compile(deep, caseSensitive: false);
      expect(compiled.sql, equals('SELECT id FROM notes'));
      expect(compiled.args, isEmpty);
      expect(compiled.exact, isFalse);
    });
  });
}
