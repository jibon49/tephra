// © 2026 Tephra. All rights reserved.

import 'package:tephra_markdown/src/block/block_parser.dart';
import 'package:tephra_markdown/src/block/table_rules.dart';
import 'package:tephra_markdown/src/parser_options.dart';
import 'package:test/test.dart';

import '../helpers/dump.dart';

void main() {
  group('splitTableRow helper', () {
    test('splits unescaped pipes and trims cell ranges', () {
      final input = r'| a \| b | c |';
      final cells = splitTableRow(input);
      expect(cells.length, 2);
      expect(input.substring(cells[0].$1, cells[0].$2), r'a \| b');
      expect(input.substring(cells[1].$1, cells[1].$2), 'c');
      expect(cells[0].$1, 2);
      expect(cells[0].$2, 8);
      expect(cells[1].$1, 11);
      expect(cells[1].$2, 12);
    });
  });

  group('GFM table parsing', () {
    test('standard table with outer pipes', () {
      final res = parseBlocks('|a|b|\n|-|-|\n|1|2|');
      expect(
        dump(res.root),
        'doc(table{aligns=n,n}(trh(td(t"a"),td(t"b")),tr(td(t"1"),td(t"2"))))',
      );
    });

    test('table without outer pipes', () {
      final res = parseBlocks('a|b\n-|-\n1|2');
      expect(
        dump(res.root),
        'doc(table{aligns=n,n}(trh(td(t"a"),td(t"b")),tr(td(t"1"),td(t"2"))))',
      );
    });

    test('alignments left and right', () {
      final res = parseBlocks('|a|b|\n|:-|-:|');
      expect(dump(res.root), 'doc(table{aligns=l,r}(trh(td(t"a"),td(t"b"))))');
    });

    test('alignments center and none', () {
      final res = parseBlocks('|a|b|\n|:-:|---|');
      expect(dump(res.root), 'doc(table{aligns=c,n}(trh(td(t"a"),td(t"b"))))');
    });

    test('escaped pipe in cell', () {
      final res = parseBlocks('|a|\n|-|\n|x \\| y|');
      expect(
        dump(res.root),
        'doc(table{aligns=n}(trh(td(t"a")),tr(td(t"x | y"))))',
      );
    });

    test('header/delimiter count mismatch stays paragraph', () {
      final res = parseBlocks('|a|b|\n|-|\n|1|2|');
      expect(dump(res.root), 'doc(p(t"|a|b|",sb,t"|-|",sb,t"|1|2|"))');
    });

    test('paragraph splitting before table header', () {
      final res = parseBlocks('para\n|a|b|\n|-|-|\n|1|2|');
      expect(
        dump(res.root),
        'doc(p(t"para"),table{aligns=n,n}(trh(td(t"a"),td(t"b")),tr(td(t"1"),td(t"2"))))',
      );
    });

    test('missing cells are padded with empty cells', () {
      final res = parseBlocks('|a|b|\n|-|-|\n|1|');
      expect(
        dump(res.root),
        'doc(table{aligns=n,n}(trh(td(t"a"),td(t"b")),tr(td(t"1"),td)))',
      );
    });

    test('extra cells beyond header count are dropped', () {
      final res = parseBlocks('|a|b|\n|-|-|\n|1|2|3|4|');
      expect(
        dump(res.root),
        'doc(table{aligns=n,n}(trh(td(t"a"),td(t"b")),tr(td(t"1"),td(t"2"))))',
      );
    });

    test('tables disabled when gfm is false', () {
      final res = parseBlocks(
        '|a|b|\n|-|-|\n|1|2|',
        options: ParserOptions.commonMark,
      );
      expect(dump(res.root), 'doc(p(t"|a|b|",sb,t"|-|-|",sb,t"|1|2|"))');
    });
  });
}
