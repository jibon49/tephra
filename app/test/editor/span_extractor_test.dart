// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/editor/highlight/source_styles.dart';
import 'package:tephra/editor/highlight/span_extractor.dart';
import 'package:tephra/reading/parse_service.dart';

void main() {
  const parseService = ParseService();

  Future<List<(int, int, SourceToken)>> spansOf(String markdown) async {
    final parsed = await parseService.parse(markdown);
    return extractSpans(parsed).map((s) => (s.start, s.end, s.token)).toList();
  }

  group('extractSpans AST construct tests', () {
    test('ATX heading: # H', () async {
      expect(
        await spansOf('# H'),
        equals([
          (0, 3, SourceToken.heading1),
          (0, 2, SourceToken.headingMarker),
        ]),
      );
    });

    test('Setext heading: Setext\\n===', () async {
      expect(
        await spansOf('Setext\n==='),
        equals([
          (0, 10, SourceToken.heading1),
          (7, 10, SourceToken.headingMarker),
        ]),
      );
    });

    test('Strong: **b**', () async {
      expect(
        await spansOf('**b**'),
        equals([
          (0, 5, SourceToken.strong),
          (0, 2, SourceToken.emphasisMarker),
          (3, 5, SourceToken.emphasisMarker),
        ]),
      );
    });

    test('Emphasis: *i*', () async {
      expect(
        await spansOf('*i*'),
        equals([
          (0, 3, SourceToken.emphasis),
          (0, 1, SourceToken.emphasisMarker),
          (2, 3, SourceToken.emphasisMarker),
        ]),
      );
    });

    test('Strikethrough: ~~s~~', () async {
      expect(
        await spansOf('~~s~~'),
        equals([
          (0, 5, SourceToken.strikethrough),
          (0, 2, SourceToken.emphasisMarker),
          (3, 5, SourceToken.emphasisMarker),
        ]),
      );
    });

    test('Highlight: ==h==', () async {
      expect(
        await spansOf('==h=='),
        equals([
          (0, 5, SourceToken.highlight),
          (0, 2, SourceToken.emphasisMarker),
          (3, 5, SourceToken.emphasisMarker),
        ]),
      );
    });

    test('Inline code: `c`', () async {
      expect(
        await spansOf('`c`'),
        equals([
          (0, 3, SourceToken.inlineCode),
          (0, 1, SourceToken.emphasisMarker),
          (2, 3, SourceToken.emphasisMarker),
        ]),
      );
    });

    test('WikiLink: [[A|B]]', () async {
      expect(
        await spansOf('[[A|B]]'),
        equals([
          (0, 7, SourceToken.wikiTarget),
          (0, 2, SourceToken.wikiBracket),
          (5, 7, SourceToken.wikiBracket),
        ]),
      );
    });

    test('WikiLink embed: ![[a.png]]', () async {
      expect(
        await spansOf('![[a.png]]'),
        equals([
          (0, 10, SourceToken.wikiTarget),
          (0, 3, SourceToken.wikiBracket),
          (8, 10, SourceToken.wikiBracket),
        ]),
      );
    });

    test('Markdown link: [t](u)', () async {
      expect(
        await spansOf('[t](u)'),
        equals([(0, 6, SourceToken.linkText), (2, 6, SourceToken.linkUrl)]),
      );
    });

    test('Autolink: <http://x>', () async {
      expect(
        await spansOf('<http://x>'),
        equals([(0, 10, SourceToken.autolink)]),
      );
    });

    test('Tag: #tag', () async {
      expect(await spansOf('#tag'), equals([(0, 4, SourceToken.tag)]));
    });

    test('BlockId: text ^id', () async {
      expect(await spansOf('text ^id'), equals([(5, 8, SourceToken.blockId)]));
    });

    test(r'Inline math: $x$', () async {
      expect(await spansOf(r'$x$'), equals([(0, 3, SourceToken.mathInline)]));
    });

    test('Footnote reference: [^1]', () async {
      expect(await spansOf('[^1]'), equals([(0, 4, SourceToken.footnote)]));
    });

    test('Comment inline: %%c%%', () async {
      expect(await spansOf('%%c%%'), equals([(0, 5, SourceToken.comment)]));
    });

    test('HTML inline: <b>', () async {
      expect(await spansOf('<b>'), equals([(0, 3, SourceToken.html)]));
    });

    test('Fenced code block', () async {
      const code = '```dart\nx\n```';
      expect(
        await spansOf(code),
        equals([
          (0, 13, SourceToken.codeBlock),
          (0, 7, SourceToken.codeFence),
          (10, 13, SourceToken.codeFence),
        ]),
      );
    });

    test('Math block', () async {
      const math = '\$\$\nx\n\$\$';
      expect(await spansOf(math), equals([(0, 7, SourceToken.mathBlock)]));
    });

    test('Thematic break: ---', () async {
      expect(await spansOf('---'), equals([(0, 3, SourceToken.thematicBreak)]));
    });

    test('Blockquote', () async {
      expect(
        await spansOf('> quote'),
        equals([(0, 2, SourceToken.quoteMarker)]),
      );
    });

    test('Callout', () async {
      const callout = '> [!note]\n> content';
      expect(
        await spansOf(callout),
        equals([
          (0, 2, SourceToken.quoteMarker),
          (10, 12, SourceToken.quoteMarker),
          (2, 9, SourceToken.calloutMarker),
        ]),
      );
    });

    test('Task item: - [ ] task', () async {
      expect(
        await spansOf('- [ ] task'),
        equals([(0, 2, SourceToken.listMarker), (2, 5, SourceToken.taskBox)]),
      );
    });

    test('Table', () async {
      const table = '| a |\n| --- |\n| b |';
      expect(
        await spansOf(table),
        equals([
          (0, 1, SourceToken.tableBorder),
          (4, 5, SourceToken.tableBorder),
          (6, 7, SourceToken.tableBorder),
          (12, 13, SourceToken.tableBorder),
          (14, 15, SourceToken.tableBorder),
          (18, 19, SourceToken.tableBorder),
          (2, 3, SourceToken.tableHeader),
        ]),
      );
    });

    test('Footnote definition: [^1]: def', () async {
      expect(
        await spansOf('[^1]: def'),
        equals([(0, 5, SourceToken.footnote)]),
      );
    });

    test('Frontmatter', () async {
      const doc = '---\ntitle: T\n---\nBody';
      expect(await spansOf(doc), equals([(0, 16, SourceToken.frontmatter)]));
    });
  });
}
