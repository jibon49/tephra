// © 2026 Tephra. All rights reserved.

import 'package:tephra_markdown/src/block/block_parser.dart';
import 'package:tephra_markdown/src/parser_options.dart';
import 'package:test/test.dart';

import '../helpers/dump.dart';

String _parse(String text, [ParserOptions options = const ParserOptions()]) {
  return dump(parseBlocks(text, options: options).root);
}

void main() {
  group('Inline links and images', () {
    test('inline link with title in double quotes', () {
      expect(
        _parse('[text](url "title")'),
        'doc(p(link{url=url,title=title}(t"text")))',
      );
    });

    test('inline link with title in single quotes', () {
      expect(
        _parse("[text](url 'title')"),
        'doc(p(link{url=url,title=title}(t"text")))',
      );
    });

    test('inline link with title in parentheses', () {
      expect(
        _parse('[text](url (title))'),
        'doc(p(link{url=url,title=title}(t"text")))',
      );
    });

    test('<...> destination with spaces', () {
      expect(_parse('[text](<a b.md>)'), 'doc(p(link{url=a b.md}(t"text")))');
    });

    test('nested parens in destinations', () {
      expect(
        _parse('[text](https://a.com/b_(c))'),
        'doc(p(link{url=https://a.com/b_(c)}(t"text")))',
      );
    });

    test('image alt text children', () {
      expect(
        _parse('![img](a.png "t")'),
        'doc(p(img{url=a.png,title=t}(t"img")))',
      );
    });

    test('link containing an image', () {
      expect(
        _parse('[![i](a.png)](b)'),
        'doc(p(link{url=b}(img{url=a.png}(t"i"))))',
      );
    });

    test('no link inside a link', () {
      expect(
        _parse('[a [b](u)](v)'),
        'doc(p(t"[a ",link{url=u}(t"b"),t"](v)"))',
      );
    });

    test(r'[a](b stays text', () {
      expect(_parse('[a](b'), 'doc(p(t"[a](b"))');
    });

    test(r'\[a](b) stays text', () {
      expect(_parse(r'\[a](b)'), 'doc(p(t"[a](b)"))');
    });
  });

  group('Reference links', () {
    test('full reference link', () {
      expect(
        _parse('[a][ref]\n\n[ref]: u "T"'),
        'doc(p(link{url=u,title=T}(t"a")))',
      );
    });

    test('collapsed reference link', () {
      expect(_parse('[a][]\n\n[a]: u'), 'doc(p(link{url=u}(t"a")))');
    });

    test('shortcut reference link', () {
      expect(
        _parse('[ref]\n\n[ref]: http://x'),
        'doc(p(link{url=http://x}(t"ref")))',
      );
    });

    test('case-insensitive label', () {
      expect(_parse('[a][REF]\n\n[ref]: u'), 'doc(p(link{url=u}(t"a")))');
    });

    test('unresolved label stays text', () {
      expect(_parse('[unknown]'), 'doc(p(t"[unknown]"))');
    });
  });
}
