// © 2026 Tephra. All rights reserved.

import 'package:tephra_markdown/tephra_markdown.dart';
import 'package:test/test.dart';

import 'helpers/dump.dart';

void main() {
  group('31 Offset Contract Cases', () {
    final cases = <(String input, String expected)>[
      ('Hello **world**', 'p@0-15 t@0-6 strong@6-15 t@8-13'),
      ('[[Note|Alias]]', 'wiki@0-14'),
      ('# Title', 'h1@0-7 t@2-7'),
      ('- [ ] task', 'ul@0-10 li@0-10 p@6-10 t@6-10'),
      ('> quote', 'bq@0-7 p@2-7'),
      ('a\nb', 'p@0-3 t@0-1 sb@1-2 t@2-3'),
      ('```\nx\n```', 'code@0-9'),
      ('- a\n  - b', 'ul@0-9 li@0-9 p@2-3 ul@6-9 li@6-9 p@8-9'),
      ('> [!note] T\n> B', 'callout@0-15 p@14-15'),
      ('---\na: 1\n---\nx', 'fm@0-12 p@13-14'),
      (
        '|a|b|\n|-|-|\n|1|2|',
        'table@0-17 trh@0-5 td@1-2 td@3-4 tr@12-17 td@13-14 td@15-16',
      ),
      ('%%x%%', 'icmt@0-5'),
      ('#tag', 'tag@0-4'),
      ('a  \nb', 'br@1-4'),
      ('[t](u "x")', 'link@0-10'),
      ('![[a.png|300]]', 'embed@0-14'),
      ('😀 **b**', 'p@0-8 strong@3-8 t@5-6'),
      ('\$\$\nx\n\$\$', 'math@0-7'),
      ('> a\nb', 'bq@0-5 p@2-5'),
      ('1. a\n2. b', 'ol@0-9 li@0-4 li@5-9'),
      ('## H ^id', 'h2@0-8 bid@5-8'),
      ('[^1]: n', 'fn@0-7'),
      ('~~x~~', 'del@0-5'),
      ('==x==', 'mark@0-5'),
      ('a\\\nb', 'br@1-3'),
      ('&amp; x', 't@0-7'),
      (r'\*a\*', 't@0-5'),
      ('  # indented heading', 'h1@2-20'),
    ];

    for (var i = 0; i < cases.length; i++) {
      final (input, expected) = cases[i];
      test('case ${i + 1}: ${input.replaceAll('\n', '⏎')}', () {
        final parsed = MarkdownParser.parse(input);
        final dumpRanges = dumpWithRanges(parsed.root);
        final tokens = dumpRanges.split(' ').toSet();

        final expectedTokens = expected.split(' ');
        for (final exp in expectedTokens) {
          expect(
            tokens,
            contains(exp),
            reason:
                'Expected $exp in "$dumpRanges" for input "${input.replaceAll('\n', '⏎')}"',
          );
        }
      });
    }
  });
}
