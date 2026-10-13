// © 2026 Tephra. All rights reserved.

import 'package:tephra_markdown/src/block/block_parser.dart';
import 'package:tephra_markdown/src/parser_options.dart';
import 'package:test/test.dart';

import '../helpers/dump.dart';

String _parse(String text, [ParserOptions options = const ParserOptions()]) {
  return dump(parseBlocks(text, options: options).root);
}

void main() {
  group('Backslash escapes', () {
    test('every ASCII punctuation escape yields that character', () {
      const asciiPunctuation =
          r'!"#$%&'
          "'"
          r'()*+,-./:;<=>?@[\]^_`{|}~';
      for (var i = 0; i < asciiPunctuation.length; i++) {
        final char = asciiPunctuation[i];
        final input = '\\$char';
        expect(
          _parse(input),
          'doc(p(t"$char"))',
          reason: 'Failed for character: $char',
        );
      }
    });

    test(r'\a keeps the backslash', () {
      expect(_parse(r'\a'), r'doc(p(t"\a"))');
    });

    test(r'\*a\* stays text', () {
      expect(_parse(r'\*a\*'), 'doc(p(t"*a*"))');
    });
  });

  group('HTML and numeric entities', () {
    test('&amp; &lt; &#65; &#x41; &nosuch; &copy;', () {
      expect(_parse('&amp;'), 'doc(p(t"&"))');
      expect(_parse('&lt;'), 'doc(p(t"<"))');
      expect(_parse('&#65;'), 'doc(p(t"A"))');
      expect(_parse('&#x41;'), 'doc(p(t"A"))');
      expect(_parse('&nosuch;'), 'doc(p(t"&nosuch;"))');
      expect(_parse('&copy;'), 'doc(p(t"©"))');
    });

    test('decoded # is not a tag', () {
      expect(_parse('&#35;tag'), 'doc(p(t"#tag"))');
    });

    test('decoded * is not emphasis', () {
      expect(_parse('&#42;a&#42;'), 'doc(p(t"*a*"))');
    });
  });
}
