// © 2026 Tephra. All rights reserved.

import 'package:tephra_markdown/src/block/block_parser.dart';
import 'package:tephra_markdown/src/parser_options.dart';
import 'package:test/test.dart';

import '../helpers/dump.dart';

String _parse(String text, [ParserOptions options = const ParserOptions()]) {
  return dump(parseBlocks(text, options: options).root);
}

void main() {
  group('CommonMark autolinks', () {
    test('<http://example.com>', () {
      expect(
        _parse('<http://example.com>'),
        'doc(p(auto{url=http://example.com}))',
      );
    });

    test('<me@example.com>', () {
      expect(
        _parse('<me@example.com>'),
        'doc(p(auto{url=mailto:me@example.com}))',
      );
    });
  });

  group('GFM extended autolinks', () {
    test('trailing punctuation excluded: https://example.com/path.', () {
      expect(
        _parse('https://example.com/path.'),
        'doc(p(auto{url=https://example.com/path},t"."))',
      );
    });

    test('www. autolink prepends http://: see www.example.com now', () {
      expect(
        _parse('see www.example.com now'),
        'doc(p(t"see ",auto{url=http://www.example.com},t" now"))',
      );
    });

    test('enclosed in parens: (https://example.com)', () {
      expect(
        _parse('(https://example.com)'),
        'doc(p(t"(",auto{url=https://example.com},t")"))',
      );
    });

    test('balanced parens kept in path: https://a.com/b_(c)', () {
      expect(
        _parse('https://a.com/b_(c)'),
        'doc(p(auto{url=https://a.com/b_(c)}))',
      );
    });

    test('fragment in url: https://example.com/#frag', () {
      expect(
        _parse('https://example.com/#frag'),
        'doc(p(auto{url=https://example.com/#frag}))',
      );
    });

    test('disabled when gfm is false', () {
      expect(
        _parse('https://example.com', ParserOptions.commonMark),
        'doc(p(t"https://example.com"))',
      );
    });
  });
}
