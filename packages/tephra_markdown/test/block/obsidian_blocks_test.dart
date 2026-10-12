// © 2026 Tephra. All rights reserved.

import 'package:tephra_markdown/src/block/block_parser.dart';
import 'package:tephra_markdown/src/nodes.dart';
import 'package:tephra_markdown/src/parser_options.dart';
import 'package:test/test.dart';

import '../helpers/dump.dart';

void main() {
  group('Callout conversion', () {
    test('type lower-casing and title', () {
      final res = parseBlocks('> [!WARNING] Be careful\n> Body line');
      expect(
        dump(res.root),
        'doc(callout{type=warning,title=Be careful}(p(t"Body line")))',
      );
    });

    test('fold expanded and collapsed', () {
      expect(
        dump(parseBlocks('> [!tip]+ Open\n> b').root),
        'doc(callout{type=tip,title=Open,f=+}(p(t"b")))',
      );
      expect(
        dump(parseBlocks('> [!warning]- Closed\n> b').root),
        'doc(callout{type=warning,title=Closed,f=-}(p(t"b")))',
      );
    });

    test('no title and no body', () {
      expect(dump(parseBlocks('> [!note]').root), 'doc(callout{type=note})');
      expect(
        dump(parseBlocks('> [!note]+').root),
        'doc(callout{type=note,f=+})',
      );
      expect(
        dump(parseBlocks('> [!note]\n> Body').root),
        'doc(callout{type=note}(p(t"Body")))',
      );
    });

    test('nested callout', () {
      final res = parseBlocks(
        '> [!note] Outer\n> > [!question] Inner\n> > Body',
      );
      expect(
        dump(res.root),
        'doc(callout{type=note,title=Outer}(callout{type=question,title=Inner}(p(t"Body"))))',
      );
    });

    test('callout inside list', () {
      final res = parseBlocks('- > [!note] in list');
      expect(dump(res.root), 'doc(ul(li(callout{type=note,title=in list})))');
    });

    test('non-callouts stay blockquotes', () {
      expect(
        dump(parseBlocks('> [!note]text').root),
        'doc(bq(p(t"[!note]text")))',
      );
      expect(
        dump(parseBlocks('> [! note] x').root),
        'doc(bq(p(t"[! note] x")))',
      );
      expect(
        dump(parseBlocks('> Not a callout [!note]').root),
        'doc(bq(p(t"Not a callout [!note]")))',
      );
    });

    test('callouts disabled when obsidian is false', () {
      final res = parseBlocks('> [!note] T', options: ParserOptions.commonMark);
      expect(dump(res.root), 'doc(bq(p(t"[!note] T")))');
    });
  });

  group('Math blocks', () {
    test('single-line math block', () {
      expect(dump(parseBlocks(r'$$x$$').root), 'doc(math"x")');
      expect(dump(parseBlocks(r'$$$$').root), 'doc(math"")');
    });

    test('multi-line math block', () {
      expect(
        dump(
          parseBlocks(
            r'$$'
            '\n'
            r'x^2'
            '\n'
            r'$$',
          ).root,
        ),
        'doc(math"x^2")',
      );
      expect(
        dump(
          parseBlocks(
            r'$$'
            '\n'
            r'a'
            '\n'
            r'b'
            '\n'
            r'$$',
          ).root,
        ),
        'doc(math"a⏎b")',
      );
    });

    test('unclosed math block runs to end', () {
      expect(
        dump(
          parseBlocks(
            r'$$'
            '\n'
            r'x',
          ).root,
        ),
        'doc(math"x")',
      );
    });

    test(r'$$ with trailing content is not a math block', () {
      expect(dump(parseBlocks(r'$$a$$ tail').root), r'doc(p(t"$$a$$ tail"))');
    });

    test('math block cannot interrupt a paragraph', () {
      expect(
        dump(
          parseBlocks(
            'para\n'
            r'$$x$$',
          ).root,
        ),
        r'doc(p(t"para⏎$$x$$"))',
      );
    });

    test('math blocks disabled when obsidian is false', () {
      expect(
        dump(parseBlocks(r'$$x$$', options: ParserOptions.commonMark).root),
        r'doc(p(t"$$x$$"))',
      );
    });
  });

  group('Comment blocks', () {
    test('single-line comment is a paragraph (not block)', () {
      expect(dump(parseBlocks('%%hidden%%').root), 'doc(p(t"%%hidden%%"))');
    });

    test('multi-line comment block', () {
      expect(dump(parseBlocks('%%\nhidden\n%%').root), 'doc(cmt)');
      expect(
        dump(parseBlocks('%%\na\n%%\n\ntext').root),
        'doc(cmt,p(t"text"))',
      );
    });

    test('comment block with trailing content on end line', () {
      expect(dump(parseBlocks('%%a\nb%% c').root), 'doc(cmt)');
    });

    test('unterminated comment block extends to end', () {
      expect(dump(parseBlocks('%%a').root), 'doc(cmt)');
    });

    test('comment block cannot interrupt a paragraph', () {
      expect(dump(parseBlocks('para\n%%').root), 'doc(p(t"para⏎%%"))');
    });

    test('comment blocks disabled when obsidian is false', () {
      expect(
        dump(parseBlocks('%%\nx\n%%', options: ParserOptions.commonMark).root),
        'doc(p(t"%%⏎x⏎%%"))',
      );
    });
  });

  group('Footnote definitions', () {
    test('single line footnote definition', () {
      expect(
        dump(parseBlocks('[^note]: The note.').root),
        'doc(fn{label=note}(p(t"The note.")))',
      );
    });

    test('continuation with 4 spaces', () {
      expect(
        dump(parseBlocks('[^1]: a\n    b').root),
        'doc(fn{label=1}(p(t"a⏎b")))',
      );
    });

    test('lazy continuation', () {
      expect(
        dump(parseBlocks('[^1]: a\nnext').root),
        'doc(fn{label=1}(p(t"a⏎next")))',
      );
    });

    test('blank line and second paragraph', () {
      expect(
        dump(parseBlocks('[^1]: a\n\n    second para').root),
        'doc(fn{label=1}(p(t"a"),p(t"second para")))',
      );
    });

    test('empty footnote definition', () {
      expect(dump(parseBlocks('[^1]:').root), 'doc(fn{label=1})');
    });

    test('footnote definition cannot interrupt paragraph', () {
      expect(
        dump(parseBlocks('para\n[^1]: a').root),
        'doc(p(t"para⏎[^1]: a"))',
      );
    });
  });

  group('Frontmatter block', () {
    test('frontmatter node before body', () {
      final res = parseBlocks('---\ntitle: T\n---\nBody');
      expect(dump(res.root), 'doc(fm,p(t"Body"))');
      expect(res.frontmatter?.yaml, 'title: T');
    });

    test('empty frontmatter', () {
      final res = parseBlocks('---\n---\nx');
      expect(dump(res.root), 'doc(fm,p(t"x"))');
      expect(res.frontmatter?.yaml, '');
    });

    test('frontmatter disabled when obsidian is false', () {
      final res = parseBlocks(
        '---\na: 1\n---',
        options: ParserOptions.commonMark,
      );
      expect(dump(res.root), 'doc(hr,h2(t"a: 1"))');
    });
  });

  group('Block ID owners', () {
    test('heading block ID owner', () {
      final res = parseBlocks('## Heading ^h1');
      expect(res.blockIds.length, 1);
      final ref = res.blockIds.first;
      expect(ref.id, 'h1');
      final heading = res.root.children.first as MdHeading;
      expect(heading.blockId, 'h1');
      expect(ref.start, heading.start);
      expect(ref.end, heading.end);
      expect('## Heading ^h1'.substring(ref.idStart, ref.idEnd), '^h1');
    });

    test('paragraph block ID owner', () {
      final text = 'Paragraph text ^abc';
      final res = parseBlocks(text);
      expect(res.blockIds.length, 1);
      final ref = res.blockIds.first;
      expect(ref.id, 'abc');
      final para = res.root.children.first as MdParagraph;
      expect(ref.start, para.start);
      expect(ref.end, para.end);
      expect(text.substring(ref.idStart, ref.idEnd), '^abc');
    });

    test('list item block ID owner', () {
      final text = '- item ^i1\n  - child';
      final res = parseBlocks(text);
      expect(res.blockIds.length, 1);
      final ref = res.blockIds.first;
      expect(ref.id, 'i1');
      final list = res.root.children.first as MdList;
      final item = list.children.first;
      expect(ref.start, item.start);
      expect(ref.end, item.end);
      expect(text.substring(ref.idStart, ref.idEnd), '^i1');
    });

    test('standalone ID line owns previous sibling block', () {
      final text = '> quote\n\n^q1';
      final res = parseBlocks(text);
      expect(res.blockIds.length, 1);
      final ref = res.blockIds.first;
      expect(ref.id, 'q1');
      final quote = res.root.children.first as MdBlockQuote;
      expect(ref.start, quote.start);
      expect(ref.end, quote.end);
      expect(text.substring(ref.idStart, ref.idEnd), '^q1');
    });
  });
}
