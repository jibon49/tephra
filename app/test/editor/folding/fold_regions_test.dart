// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/editor/folding/fold_regions.dart';
import 'package:tephra_markdown/tephra_markdown.dart';

void main() {
  group('computeFoldRegions', () {
    test('Example 1: headings folding with hierarchical levels', () {
      const text = '# A\na\n## B\nb\n# C\nc';
      final parsed = MarkdownParser.parse(text);
      final regions = computeFoldRegions(text, parsed);

      expect(regions.length, 3);
      // A (headerStart 0, from 3, to 12)
      expect(regions[0].kind, FoldKind.heading);
      expect(regions[0].headerStart, 0);
      expect(regions[0].from, 3);
      expect(regions[0].to, 12);
      expect(regions[0].level, 1);

      // B (headerStart 6, from 10, to 12)
      expect(regions[1].kind, FoldKind.heading);
      expect(regions[1].headerStart, 6);
      expect(regions[1].from, 10);
      expect(regions[1].to, 12);
      expect(regions[1].level, 2);

      // C (headerStart 13, from 16, to 18)
      expect(regions[2].kind, FoldKind.heading);
      expect(regions[2].headerStart, 13);
      expect(regions[2].from, 16);
      expect(regions[2].to, 18);
      expect(regions[2].level, 1);
    });

    test('Example 2: list items with continuation / nested children', () {
      const text = '- a\n  - b\n  - c\n- d\n';
      final parsed = MarkdownParser.parse(text);
      final regions = computeFoldRegions(text, parsed);

      // for '- a\n  - b\n  - c\n- d\n' one region (0, 3, 15)
      expect(regions.length, 1);
      expect(regions[0].kind, FoldKind.list);
      expect(regions[0].headerStart, 0);
      expect(regions[0].from, 3);
      expect(regions[0].to, 15);
    });

    test('heading inside a fenced block is not a region', () {
      const text = '```\n# Not a heading\nhello\n```\n';
      final parsed = MarkdownParser.parse(text);
      final regions = computeFoldRegions(text, parsed);

      expect(regions, isEmpty);
    });

    test('a heading directly followed by another heading of same level is not foldable', () {
      const text = '# A\n# B\nContent B';
      final parsed = MarkdownParser.parse(text);
      final regions = computeFoldRegions(text, parsed);

      expect(regions.length, 1);
      expect(regions[0].headerStart, 4); // Only # B is foldable
    });

    test('trailing blank lines are excluded from `to`', () {
      const text = '# Heading\nContent line\n\n\n# Next\n';
      final parsed = MarkdownParser.parse(text);
      final regions = computeFoldRegions(text, parsed);

      expect(regions.length, 1);
      final h = regions[0];
      // Content line starts at 10 and ends at 22 ('\n')
      expect(text.substring(10, 22), 'Content line');
      expect(h.to, 22);
    });

    test('trailing blank lines at end of file are excluded from `to`', () {
      const text = '# Heading\nContent line\n\n\n';
      final parsed = MarkdownParser.parse(text);
      final regions = computeFoldRegions(text, parsed);

      expect(regions.length, 1);
      final h = regions[0];
      expect(h.to, 22);
    });

    test('headings: false removes heading regions', () {
      const text = '# Heading\nText\n- list item\n  - child\n';
      final parsed = MarkdownParser.parse(text);
      final regions = computeFoldRegions(text, parsed, headings: false);

      expect(regions.every((r) => r.kind != FoldKind.heading), isTrue);
      expect(regions.length, 1);
      expect(regions[0].kind, FoldKind.list);
    });

    test('lists: false removes list regions', () {
      const text = '# Heading\nText\n- list item\n  - child\n';
      final parsed = MarkdownParser.parse(text);
      final regions = computeFoldRegions(text, parsed, lists: false);

      expect(regions.every((r) => r.kind != FoldKind.list), isTrue);
      expect(regions.length, 1);
      expect(regions[0].kind, FoldKind.heading);
    });

    test('frontmatter, code blocks and tables are never foldable', () {
      const text = '''---
title: Note
tags: [test]
---

| col 1 | col 2 |
| --- | --- |
| val 1 | val 2 |

```dart
void main() {
  print('code');
}
```
''';
      final parsed = MarkdownParser.parse(text);
      final regions = computeFoldRegions(text, parsed);

      expect(regions, isEmpty);
    });
  });
}
