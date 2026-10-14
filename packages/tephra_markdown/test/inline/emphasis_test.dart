// © 2026 Tephra. All rights reserved.

import 'package:tephra_markdown/src/block/block_parser.dart';
import 'package:tephra_markdown/src/parser_options.dart';
import 'package:test/test.dart';

import '../helpers/dump.dart';

String _parse(String text, [ParserOptions options = const ParserOptions()]) {
  return dump(parseBlocks(text, options: options).root);
}

void main() {
  group('Emphasis and strong', () {
    test('*a*', () {
      expect(_parse('*a*'), 'doc(p(em(t"a")))');
    });

    test('_a_', () {
      expect(_parse('_a_'), 'doc(p(em(t"a")))');
    });

    test('**a**', () {
      expect(_parse('**a**'), 'doc(p(strong(t"a")))');
    });

    test('__a__', () {
      expect(_parse('__a__'), 'doc(p(strong(t"a")))');
    });

    test('***a***', () {
      expect(_parse('***a***'), 'doc(p(em(strong(t"a"))))');
    });

    test('snake_case_word stays text', () {
      expect(_parse('snake_case_word'), 'doc(p(t"snake_case_word"))');
    });

    test('a*b*c', () {
      expect(_parse('a*b*c'), 'doc(p(t"a",em(t"b"),t"c"))');
    });

    test('2 * 3 * 4', () {
      expect(_parse('2 * 3 * 4'), 'doc(p(t"2 * 3 * 4"))');
    });

    test('nested **a *b* c**', () {
      expect(_parse('**a *b* c**'), 'doc(p(strong(t"a ",em(t"b"),t" c")))');
    });

    test('*a **b** c*', () {
      expect(_parse('*a **b** c*'), 'doc(p(em(t"a ",strong(t"b"),t" c")))');
    });

    test('rule of 3 (*foo**bar**baz*)', () {
      expect(
        _parse('*foo**bar**baz*'),
        'doc(p(em(t"foo",strong(t"bar"),t"baz")))',
      );
    });

    test('**foo* stays * + em', () {
      expect(_parse('**foo*'), 'doc(p(t"*",em(t"foo")))');
    });

    test(r'\*esc\* -> text *esc*', () {
      expect(_parse(r'\*esc\*'), 'doc(p(t"*esc*"))');
    });

    test('unmatched **not closed', () {
      expect(_parse('**not closed'), 'doc(p(t"**not closed"))');
    });
  });

  group('Highlight and strikethrough extensions', () {
    test('==x==', () {
      expect(_parse('==x=='), 'doc(p(mark(t"x")))');
    });

    test('a==b==c', () {
      expect(_parse('a==b==c'), 'doc(p(t"a",mark(t"b"),t"c"))');
    });

    test('==== is text', () {
      expect(_parse('===='), 'doc(p(t"===="))');
    });

    test('~~x~~', () {
      expect(_parse('~~x~~'), 'doc(p(del(t"x")))');
    });

    test('~x~ is text', () {
      expect(_parse('~x~'), 'doc(p(t"~x~"))');
    });

    test('==a **b** c==', () {
      expect(_parse('==a **b** c=='), 'doc(p(mark(t"a ",strong(t"b"),t" c")))');
    });

    test('==mark with ~~del~~==', () {
      expect(
        _parse('==mark with ~~del~~=='),
        'doc(p(mark(t"mark with ",del(t"del"))))',
      );
    });
  });
}
