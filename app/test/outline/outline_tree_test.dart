// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/outline/outline_tree.dart';
import 'package:tephra_markdown/tephra_markdown.dart';

void main() {
  group('outline_tree', () {
    test('# A, ## B, ### C, ## D, # E -> roots A, E; A.children = [B, D]; B.children = [C]', () {
      final doc = MarkdownParser.parse('# A\n## B\n### C\n## D\n# E');
      final outline = buildOutline(doc.headings);

      expect(outline.length, equals(2));
      final a = outline[0];
      final e = outline[1];

      expect(a.text, equals('A'));
      expect(a.depth, equals(0));
      expect(a.children.length, equals(2));

      final b = a.children[0];
      final d = a.children[1];
      expect(b.text, equals('B'));
      expect(b.depth, equals(1));
      expect(d.text, equals('D'));
      expect(d.depth, equals(1));

      expect(b.children.length, equals(1));
      final c = b.children[0];
      expect(c.text, equals('C'));
      expect(c.depth, equals(2));
      expect(c.children, isEmpty);

      expect(d.children, isEmpty);

      expect(e.text, equals('E'));
      expect(e.depth, equals(0));
      expect(e.children, isEmpty);
    });

    test('### X, # Y -> roots X, Y', () {
      final doc = MarkdownParser.parse('### X\n# Y');
      final outline = buildOutline(doc.headings);

      expect(outline.length, equals(2));
      expect(outline[0].text, equals('X'));
      expect(outline[0].depth, equals(0));
      expect(outline[0].children, isEmpty);

      expect(outline[1].text, equals('Y'));
      expect(outline[1].depth, equals(0));
      expect(outline[1].children, isEmpty);
    });

    test('empty headings produces empty outline', () {
      expect(buildOutline([]), isEmpty);
    });

    test('single heading produces one root', () {
      final doc = MarkdownParser.parse('# Only One');
      final outline = buildOutline(doc.headings);
      expect(outline.length, equals(1));
      expect(outline.first.text, equals('Only One'));
      expect(outline.first.depth, equals(0));
      expect(outline.first.children, isEmpty);
    });

    test('deeply nested hierarchy H1 through H6', () {
      final doc = MarkdownParser.parse(
        '# 1\n## 2\n### 3\n#### 4\n##### 5\n###### 6',
      );
      final outline = buildOutline(doc.headings);
      expect(outline.length, equals(1));
      var current = outline.first;
      for (var lvl = 1; lvl <= 6; lvl++) {
        expect(current.text, equals('$lvl'));
        expect(current.depth, equals(lvl - 1));
        if (lvl < 6) {
          expect(current.children.length, equals(1));
          current = current.children.first;
        } else {
          expect(current.children, isEmpty);
        }
      }
    });

    test('ignores block IDs when extracting heading text', () {
      final doc = MarkdownParser.parse('# Heading with ID ^sec-1');
      final outline = buildOutline(doc.headings);
      expect(outline.length, equals(1));
      expect(outline.first.text, equals('Heading with ID'));
    });
  });
}
