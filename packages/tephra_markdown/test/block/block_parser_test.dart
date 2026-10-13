// © 2026 Tephra. All rights reserved.

import 'package:tephra_markdown/src/block/block_parser.dart';
import 'package:tephra_markdown/src/nodes.dart';
import 'package:test/test.dart';

import '../helpers/dump.dart';

void main() {
  group('ATX headings', () {
    test('levels 1 to 6', () {
      expect(dump(parseBlocks('# H1').root), 'doc(h1(t"H1"))');
      expect(dump(parseBlocks('## H2').root), 'doc(h2(t"H2"))');
      expect(dump(parseBlocks('### H3').root), 'doc(h3(t"H3"))');
      expect(dump(parseBlocks('#### H4').root), 'doc(h4(t"H4"))');
      expect(dump(parseBlocks('##### H5').root), 'doc(h5(t"H5"))');
      expect(dump(parseBlocks('###### H6').root), 'doc(h6(t"H6"))');
    });

    test('7 hashes is a paragraph', () {
      expect(
        dump(parseBlocks('####### seven').root),
        'doc(p(t"####### seven"))',
      );
    });

    test('# alone is an empty heading', () {
      expect(dump(parseBlocks('#').root), 'doc(h1)');
      expect(dump(parseBlocks('##').root), 'doc(h2)');
    });

    test('closing hashes removed', () {
      expect(dump(parseBlocks('# Heading ###').root), 'doc(h1(t"Heading"))');
      expect(
        dump(parseBlocks('# Heading # # #').root),
        'doc(h1(t"Heading # #"))',
      );
      expect(dump(parseBlocks('# Heading###').root), 'doc(h1(t"Heading###"))');
    });

    test('#5 bolt is a paragraph', () {
      expect(dump(parseBlocks('#5 bolt').root), 'doc(p(t"#5 bolt"))');
    });
  });

  group('Setext headings and thematic breaks', () {
    test('setext = and -', () {
      expect(dump(parseBlocks('para\n=').root), 'doc(h1(t"para"))');
      expect(dump(parseBlocks('para\n-').root), 'doc(h2(t"para"))');
      expect(dump(parseBlocks('para\n===').root), 'doc(h1(t"para"))');
      expect(dump(parseBlocks('para\n---').root), 'doc(h2(t"para"))');
    });

    test('--- alone is hr', () {
      expect(dump(parseBlocks('---').root), 'doc(hr)');
      expect(dump(parseBlocks('***').root), 'doc(hr)');
      expect(dump(parseBlocks('___').root), 'doc(hr)');
    });

    test('- - - is hr not a list', () {
      expect(dump(parseBlocks('- - -').root), 'doc(hr)');
      expect(dump(parseBlocks('* * *').root), 'doc(hr)');
      expect(dump(parseBlocks('_ _ _').root), 'doc(hr)');
    });
  });

  group('Fenced and indented code blocks', () {
    test('fenced backticks and info string', () {
      final res = parseBlocks('``` js linenos\nx\n```');
      final code = res.root.children.first as MdCodeBlock;
      expect(code.language, 'js');
      expect(code.info, 'js linenos');
      expect(code.fenced, isTrue);
      expect(dump(res.root), 'doc(code{lang=js})');
    });

    test('fenced tildes', () {
      expect(dump(parseBlocks('~~~\nx\n~~~').root), 'doc(code)');
    });

    test('unclosed fence runs to the end', () {
      expect(dump(parseBlocks('```\nunclosed').root), 'doc(code)');
    });

    test('indented code with trailing blank lines trimmed', () {
      final res = parseBlocks('    line 1\n    line 2\n    \n\n');
      expect(dump(res.root), 'doc(icode)');
      final code = res.root.children.first as MdCodeBlock;
      expect(code.code, 'line 1\nline 2\n');
    });

    test('blank-line handling in indented code', () {
      final res = parseBlocks('    line 1\n\n    line 2');
      final code = res.root.children.first as MdCodeBlock;
      expect(code.code, 'line 1\n\nline 2\n');
    });
  });

  group('Block quotes', () {
    test('block quote with lazy continuation', () {
      expect(dump(parseBlocks('> a\nb').root), 'doc(bq(p(t"a",sb,t"b")))');
    });

    test('nested quote > > b', () {
      expect(dump(parseBlocks('> > b').root), 'doc(bq(bq(p(t"b"))))');
    });

    test('quote then blank then quote = two quotes', () {
      expect(
        dump(parseBlocks('> a\n\n> b').root),
        'doc(bq(p(t"a")),bq(p(t"b")))',
      );
    });
  });

  group('HTML blocks', () {
    test('type 1 script', () {
      expect(dump(parseBlocks('<script>\nx\n</script>').root), 'doc(html)');
    });

    test('type 2 comment', () {
      expect(dump(parseBlocks('<!-- comment -->').root), 'doc(html)');
    });

    test('type 3 processing instruction', () {
      expect(dump(parseBlocks('<?php echo "hi"; ?>').root), 'doc(html)');
    });

    test('type 4 declaration', () {
      expect(dump(parseBlocks('<!DOCTYPE html>').root), 'doc(html)');
    });

    test('type 5 CDATA', () {
      expect(dump(parseBlocks('<![CDATA[cdata]]>').root), 'doc(html)');
    });

    test('type 6 div closed by blank line', () {
      expect(dump(parseBlocks('<div>\nx\n\ny').root), 'doc(html,p(t"y"))');
    });

    test('type 7 complete tag not interrupting paragraph', () {
      expect(dump(parseBlocks('<a href="x">\ny').root), 'doc(html)');
      expect(
        dump(parseBlocks('para\n<a href="x">').root),
        'doc(p(t"para",sb,ihtml"<a href="x">"))',
      );
    });
  });

  group('Link reference definitions', () {
    test('[a]: b "c" removed from paragraph', () {
      final res = parseBlocks('[a]: b "c"\n\nParagraph');
      expect(dump(res.root), 'doc(p(t"Paragraph"))');
      expect(res.definitions['a']?.url, 'b');
      expect(res.definitions['a']?.title, 'c');
    });

    test('[a]: b title on next line', () {
      final res = parseBlocks('[a]: b\n"c"\n\nParagraph');
      expect(dump(res.root), 'doc(p(t"Paragraph"))');
      expect(res.definitions['a']?.title, 'c');
    });

    test('invalid title keeps title text as paragraph', () {
      final res = parseBlocks('[a]: b\n"c" invalid');
      expect(dump(res.root), 'doc(p(t""c" invalid"))');
      expect(res.definitions['a']?.url, 'b');
      expect(res.definitions['a']?.title, isNull);
    });

    test('duplicate label first wins', () {
      final res = parseBlocks('[a]: first\n[a]: second');
      expect(res.definitions['a']?.url, 'first');
    });

    test('definition cannot interrupt a paragraph', () {
      final res = parseBlocks('para\n[a]: b');
      expect(dump(res.root), 'doc(p(t"para",sb,t"[a]: b"))');
      expect(res.definitions.containsKey('a'), isFalse);
    });
  });

  group('Tabs and column advancement', () {
    test('-→a is an item', () {
      expect(dump(parseBlocks('-\ta').root), 'doc(ul(li(p(t"a"))))');
    });

    test('→code is indented code', () {
      expect(dump(parseBlocks('\tcode').root), 'doc(icode)');
    });

    test('>→a is blockquote with content', () {
      expect(dump(parseBlocks('>\ta').root), 'doc(bq(p(t"a")))');
    });
  });
}
