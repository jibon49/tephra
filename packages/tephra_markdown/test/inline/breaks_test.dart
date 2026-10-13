// © 2026 Tephra. All rights reserved.

import 'package:tephra_markdown/src/block/block_parser.dart';
import 'package:tephra_markdown/src/parser_options.dart';
import 'package:test/test.dart';

import '../helpers/dump.dart';

String _parse(String text, [ParserOptions options = const ParserOptions()]) {
  return dump(parseBlocks(text, options: options).root);
}

void main() {
  group('Line breaks', () {
    test('soft break', () {
      expect(_parse('a\nb'), 'doc(p(t"a",sb,t"b"))');
    });

    test('hard break with two trailing spaces', () {
      expect(_parse('a  \nb'), 'doc(p(t"a",br,t"b"))');
    });

    test('hard break with three trailing spaces', () {
      expect(_parse('a   \nb'), 'doc(p(t"a",br,t"b"))');
    });

    test(r'hard break with backslash escape', () {
      expect(_parse('a\\\nb'), 'doc(p(t"a",br,t"b"))');
    });

    test('single trailing space before newline is stripped as soft break', () {
      expect(_parse('a \nb'), 'doc(p(t"a",sb,t"b"))');
    });

    test('multiple lines with mixed breaks', () {
      expect(
        _parse('line1\nline2  \nline3'),
        'doc(p(t"line1",sb,t"line2",br,t"line3"))',
      );
    });
  });
}
