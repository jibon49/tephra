// © 2026 Tephra. All rights reserved.

import 'package:tephra_markdown/src/block/block_parser.dart';
import 'package:tephra_markdown/src/inline/code_spans.dart';
import 'package:tephra_markdown/src/parser_options.dart';
import 'package:tephra_markdown/src/util/offset_map.dart';
import 'package:test/test.dart';

import '../helpers/dump.dart';

String _parse(String text, [ParserOptions options = const ParserOptions()]) {
  return dump(parseBlocks(text, options: options).root);
}

void main() {
  group('Code spans', () {
    test('1, 2, 3 backticks', () {
      expect(_parse('`a`'), 'doc(p(c"a"))');
      expect(_parse('``a`b``'), 'doc(p(c"a`b"))');
      expect(_parse('```a```'), 'doc(p(c"a"))');
    });

    test('unmatched run literal', () {
      expect(_parse('`unclosed'), 'doc(p(t"`unclosed"))');
    });

    test('space stripping', () {
      expect(_parse('` a `'), 'doc(p(c"a"))');
      expect(_parse('``  foo  ``'), 'doc(p(c" foo "))');
    });

    test('all-space content kept', () {
      expect(_parse('`  `'), 'doc(p(c"  "))');
      expect(_parse('` `'), 'doc(p(c" "))');
    });

    test('newline to space', () {
      expect(_parse('`a\nb`'), 'doc(p(c"a b"))');
    });

    test('code span beats emphasis', () {
      expect(_parse('*a`*`'), 'doc(p(t"*a",c"*"))');
    });

    test(r'table-cell \| replacement', () {
      final map = OffsetMap()..addSegment(0, 4);
      final res = parseCodeSpan(
        text: r'`\|`',
        index: 0,
        map: map,
        inTableCell: true,
      );
      expect(res, isNotNull);
      expect(res!.node.code, '|');

      // Inside table
      expect(
        _parse('|a|\n|-|\n|`\\|`|'),
        'doc(table{aligns=n}(trh(td(t"a")),tr(td(c"|"))))',
      );
    });
  });
}
