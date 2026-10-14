// © 2026 Tephra. All rights reserved.

import 'package:tephra_search/tephra_search.dart';
import 'package:test/test.dart';

void main() {
  group('SearchParser (44 obsidian query tests)', () {
    test('1: meeting', () {
      expect(printExpr(SearchParser.parse('meeting')), equals('term(meeting)'));
    });

    test('2: meeting bob', () {
      expect(
        printExpr(SearchParser.parse('meeting bob')),
        equals('and(term(meeting), term(bob))'),
      );
    });

    test('3: a OR b c', () {
      expect(
        printExpr(SearchParser.parse('a OR b c')),
        equals('or(term(a), and(term(b), term(c)))'),
      );
    });

    test('4: a b OR c', () {
      expect(
        printExpr(SearchParser.parse('a b OR c')),
        equals('or(and(term(a), term(b)), term(c))'),
      );
    });

    test('5: -a b', () {
      expect(
        printExpr(SearchParser.parse('-a b')),
        equals('and(not(term(a)), term(b))'),
      );
    });

    test('6: (a OR b) c', () {
      expect(
        printExpr(SearchParser.parse('(a OR b) c')),
        equals('and(or(term(a), term(b)), term(c))'),
      );
    });

    test('7: "meeting notes"', () {
      expect(
        printExpr(SearchParser.parse('"meeting notes"')),
        equals('phrase(meeting notes)'),
      );
    });

    test('8: "say \\"hi\\""', () {
      expect(
        printExpr(SearchParser.parse(r'"say \"hi\""')),
        equals('phrase(say "hi")'),
      );
    });

    test('9: /55\\d/', () {
      expect(printExpr(SearchParser.parse(r'/55\d/')), equals(r'regex(55\d/)'));
    });

    test('10: /a/i', () {
      expect(printExpr(SearchParser.parse('/a/i')), equals('regex(a/i)'));
    });

    test('11: /usr/bin', () {
      expect(
        printExpr(SearchParser.parse('/usr/bin')),
        equals('term(/usr/bin)'),
      );
    });

    test('12: file:alpha', () {
      expect(
        printExpr(SearchParser.parse('file:alpha')),
        equals('file(term(alpha))'),
      );
    });

    test('13: file:"Epsilon Notes"', () {
      expect(
        printExpr(SearchParser.parse('file:"Epsilon Notes"')),
        equals('file(phrase(Epsilon Notes))'),
      );
    });

    test('14: path:(a OR b)', () {
      expect(
        printExpr(SearchParser.parse('path:(a OR b)')),
        equals('path(or(term(a), term(b)))'),
      );
    });

    test('15: tag:#work', () {
      expect(
        printExpr(SearchParser.parse('tag:#work')),
        equals('tag(term(work))'),
      );
    });

    test('16: line:(meeting bob)', () {
      expect(
        printExpr(SearchParser.parse('line:(meeting bob)')),
        equals('line(and(term(meeting), term(bob)))'),
      );
    });

    test('17: section:(a -b)', () {
      expect(
        printExpr(SearchParser.parse('section:(a -b)')),
        equals('section(and(term(a), not(term(b))))'),
      );
    });

    test('18: task-todo:report', () {
      expect(
        printExpr(SearchParser.parse('task-todo:report')),
        equals('task-todo(term(report))'),
      );
    });

    test('19: task-done:""', () {
      expect(
        printExpr(SearchParser.parse('task-done:""')),
        equals('task-done(phrase())'),
      );
    });

    test('20: match-case:Meeting', () {
      expect(
        printExpr(SearchParser.parse('match-case:Meeting')),
        equals('match-case(term(Meeting))'),
      );
    });

    test('21: [status]', () {
      expect(printExpr(SearchParser.parse('[status]')), equals('prop(status)'));
    });

    test('22: [status:draft]', () {
      expect(
        printExpr(SearchParser.parse('[status:draft]')),
        equals('prop(status:term(draft))'),
      );
    });

    test('23: [status:draft OR done]', () {
      expect(
        printExpr(SearchParser.parse('[status:draft OR done]')),
        equals('prop(status:or(term(draft), term(done)))'),
      );
    });

    test('24: [status:] and [status:null]', () {
      expect(
        printExpr(SearchParser.parse('[status:]')),
        equals('prop(status:empty)'),
      );
      expect(
        printExpr(SearchParser.parse('[status:null]')),
        equals('prop(status:empty)'),
      );
    });

    test('25: http://x.y', () {
      expect(
        printExpr(SearchParser.parse('http://x.y')),
        equals('term(http://x.y)'),
      );
    });

    test('26: foo-bar', () {
      expect(printExpr(SearchParser.parse('foo-bar')), equals('term(foo-bar)'));
    });

    test('27: -', () {
      expect(printExpr(SearchParser.parse('-')), equals('term(-)'));
    });

    test('28: OR a', () {
      expect(
        printExpr(SearchParser.parse('OR a')),
        equals('and(term(OR), term(a))'),
      );
    });

    test('29: a OR', () {
      expect(
        printExpr(SearchParser.parse('a OR')),
        equals('and(term(a), term(OR))'),
      );
    });

    test('30: "" and "   "', () {
      expect(printExpr(SearchParser.parse('')), equals('empty'));
      expect(printExpr(SearchParser.parse('   ')), equals('empty'));
    });

    test('31: a)', () {
      expect(
        () => SearchParser.parse('a)'),
        throwsA(
          isA<SearchSyntaxException>().having((e) => e.offset, 'offset', 1),
        ),
      );
    });

    test('32: (a', () {
      expect(
        () => SearchParser.parse('(a'),
        throwsA(
          isA<SearchSyntaxException>().having((e) => e.offset, 'offset', 0),
        ),
      );
    });

    test('33: ()', () {
      expect(
        () => SearchParser.parse('()'),
        throwsA(
          isA<SearchSyntaxException>().having((e) => e.offset, 'offset', 0),
        ),
      );
    });

    test('34: /(/', () {
      expect(
        () => SearchParser.parse('/(/'),
        throwsA(
          isA<SearchSyntaxException>().having((e) => e.offset, 'offset', 0),
        ),
      );
    });

    test('35: "unterminated', () {
      expect(
        printExpr(SearchParser.parse('"unterminated')),
        equals('phrase(unterminated)'),
      );
    });

    test('36: FILE:x', () {
      expect(printExpr(SearchParser.parse('FILE:x')), equals('file(term(x))'));
    });

    test('37: unknown:x', () {
      expect(
        printExpr(SearchParser.parse('unknown:x')),
        equals('term(unknown:x)'),
      );
    });

    test('38: [a b', () {
      expect(
        printExpr(SearchParser.parse('[a b')),
        equals('and(term([a), term(b))'),
      );
    });

    test('39: -(a OR b)', () {
      expect(
        printExpr(SearchParser.parse('-(a OR b)')),
        equals('not(or(term(a), term(b)))'),
      );
    });

    test('40: বাংলায়', () {
      expect(printExpr(SearchParser.parse('বাংলায়')), equals('term(বাংলায়)'));
    });

    test('41: task:', () {
      expect(printExpr(SearchParser.parse('task:')), equals('task(empty)'));
    });

    test('42: match-case:file:X', () {
      expect(
        printExpr(SearchParser.parse('match-case:file:X')),
        equals('match-case(file(term(X)))'),
      );
    });

    test('43: a OR b OR c', () {
      expect(
        printExpr(SearchParser.parse('a OR b OR c')),
        equals('or(term(a), term(b), term(c))'),
      );
    });

    test('44: [due:(2026 OR 2027)]', () {
      expect(
        printExpr(SearchParser.parse('[due:(2026 OR 2027)]')),
        equals('prop(due:or(term(2026), term(2027)))'),
      );
    });
  });
}
