// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/editor/autocomplete/autocomplete_context.dart';

void main() {
  group('TagContext detection', () {
    (String, int) parseCaret(String input) {
      final idx = input.lastIndexOf('|');
      expect(idx, isNot(-1), reason: 'input must contain "|" indicating caret');
      final text = input.substring(0, idx) + input.substring(idx + 1);
      return (text, idx);
    }

    test('Text #pro| -> TagContext(query: "pro")', () {
      final (text, caret) = parseCaret('Text #pro|');
      final ctx = detectAutocompleteContext(text, caret);
      expect(ctx, isA<TagContext>());
      final tc = ctx as TagContext;
      expect(tc.query, equals('pro'));
      expect(tc.inFrontmatter, isFalse);
      expect(tc.replaceStart, equals(6));
      expect(tc.replaceEnd, equals(caret));
    });

    test('# | -> null (trailing space)', () {
      final (text, caret) = parseCaret('# |');
      final ctx = detectAutocompleteContext(text, caret);
      expect(ctx, isNull);
    });

    test('#| at line start -> null (heading marker)', () {
      final (text, caret) = parseCaret('#|');
      final ctx = detectAutocompleteContext(text, caret);
      expect(ctx, isNull);
    });

    test('a#b| -> null (preceded by a word character)', () {
      final (text, caret) = parseCaret('a#b|');
      final ctx = detectAutocompleteContext(text, caret);
      expect(ctx, isNull);
    });

    test('https://x.com/#frag| -> null (/ before #)', () {
      final (text, caret) = parseCaret('https://x.com/#frag|');
      final ctx = detectAutocompleteContext(text, caret);
      expect(ctx, isNull);
    });

    test('#123| -> null (all digits)', () {
      final (text, caret) = parseCaret('Text #123|');
      final ctx = detectAutocompleteContext(text, caret);
      expect(ctx, isNull);
    });

    test('#12a| -> context (contains letter)', () {
      final (text, caret) = parseCaret('Text #12a|');
      final ctx = detectAutocompleteContext(text, caret);
      expect(ctx, isA<TagContext>());
      final tc = ctx as TagContext;
      expect(tc.query, equals('12a'));
    });

    test('inside inline code -> null', () {
      final (text, caret) = parseCaret('`#a|`');
      final ctx = detectAutocompleteContext(text, caret);
      expect(ctx, isNull);
    });

    test('[[a#b| -> HeadingLinkContext (not a tag)', () {
      final (text, caret) = parseCaret('[[a#b|');
      final ctx = detectAutocompleteContext(text, caret);
      expect(ctx, isA<HeadingLinkContext>());
      final hc = ctx as HeadingLinkContext;
      expect(hc.noteText, equals('a'));
      expect(hc.query, equals('b'));
    });

    test('#বাংলা| -> context (Bengali unicode text)', () {
      final (text, caret) = parseCaret('Text #বাংলা|');
      final ctx = detectAutocompleteContext(text, caret);
      expect(ctx, isA<TagContext>());
      final tc = ctx as TagContext;
      expect(tc.query, equals('বাংলা'));
    });

    test('#a/b| -> query "a/b" (nested tag)', () {
      final (text, caret) = parseCaret('Text #a/b|');
      final ctx = detectAutocompleteContext(text, caret);
      expect(ctx, isA<TagContext>());
      final tc = ctx as TagContext;
      expect(tc.query, equals('a/b'));
    });
  });
}
