// © 2026 Tephra. All rights reserved.

import 'package:tephra_markdown/src/block/block_parser.dart';
import 'package:tephra_markdown/src/nodes.dart';
import 'package:test/test.dart';

import '../helpers/dump.dart';

void main() {
  group('HTML block types and end conditions', () {
    test('type 1 script closed by </script>', () {
      final res = parseBlocks(
        '<script type="text/javascript">\nalert(1);\n</script>\n\npara',
      );
      expect(dump(res.root), 'doc(html,p(t"para"))');
      final html = res.root.children.first as MdHtmlBlock;
      expect(
        html.html,
        '<script type="text/javascript">\nalert(1);\n</script>',
      );
    });

    test('type 1 pre closed on same line', () {
      final res = parseBlocks('<pre>code</pre>');
      expect(dump(res.root), 'doc(html)');
      final html = res.root.children.first as MdHtmlBlock;
      expect(html.html, '<pre>code</pre>');
    });

    test('type 2 comment closed by -->', () {
      final res = parseBlocks('<!--\ncomment line\n-->\npara');
      expect(dump(res.root), 'doc(html,p(t"para"))');
    });

    test('type 3 processing instruction closed by ?>', () {
      final res = parseBlocks('<?xml version="1.0"?>\ncontent');
      expect(dump(res.root), 'doc(html,p(t"content"))');
    });

    test('type 4 declaration closed by >', () {
      final res = parseBlocks('<!DOCTYPE html>\nbody');
      expect(dump(res.root), 'doc(html,p(t"body"))');
    });

    test('type 5 CDATA closed by ]]>', () {
      final res = parseBlocks('<![CDATA[\nsome cdata\n]]>\nbody');
      expect(dump(res.root), 'doc(html,p(t"body"))');
    });

    test('type 6 block tag closed by blank line', () {
      final res = parseBlocks('<div>\nhello world\n\nsecond block');
      expect(dump(res.root), 'doc(html,p(t"second block"))');
    });

    test('type 7 complete tag closed by blank line', () {
      final res = parseBlocks('<a href="x">\nlink body\n\nafter link');
      expect(dump(res.root), 'doc(html,p(t"after link"))');
    });
  });

  group('Paragraph interruption by HTML blocks', () {
    test('type 7 cannot interrupt a paragraph', () {
      final res = parseBlocks('para\n<a href="x">');
      expect(dump(res.root), 'doc(p(t"para⏎<a href="x">"))');
    });

    test('type 6 can interrupt a paragraph', () {
      final res = parseBlocks('para\n<div>\ninside\n\nafter');
      expect(dump(res.root), 'doc(p(t"para"),html,p(t"after"))');
    });

    test('type 1 can interrupt a paragraph', () {
      final res = parseBlocks('para\n<script>\nx\n</script>');
      expect(dump(res.root), 'doc(p(t"para"),html)');
    });
  });
}
