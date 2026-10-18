// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/editor/autocomplete/autocomplete_context.dart';

void main() {
  group('SlashContext detection', () {
    (String, int) parseCaret(String input) {
      final idx = input.lastIndexOf('|');
      expect(idx, isNot(-1), reason: 'input must contain "|" indicating caret');
      final text = input.substring(0, idx) + input.substring(idx + 1);
      return (text, idx);
    }

    test('/he| at line start -> context (query: "he")', () {
      final (text, caret) = parseCaret('/he|');
      final ctx = detectAutocompleteContext(text, caret);
      expect(ctx, isA<SlashContext>());
      final sc = ctx as SlashContext;
      expect(sc.query, equals('he'));
      expect(sc.slashStart, equals(0));
      expect(sc.replaceStart, equals(0));
      expect(sc.replaceEnd, equals(caret));
    });

    test('foo /he| -> context', () {
      final (text, caret) = parseCaret('foo /he|');
      final ctx = detectAutocompleteContext(text, caret);
      expect(ctx, isA<SlashContext>());
      final sc = ctx as SlashContext;
      expect(sc.query, equals('he'));
      expect(sc.slashStart, equals(4));
      expect(sc.replaceStart, equals(4));
      expect(sc.replaceEnd, equals(caret));
    });

    test('foo/he| -> null (no whitespace before slash)', () {
      final (text, caret) = parseCaret('foo/he|');
      final ctx = detectAutocompleteContext(text, caret);
      expect(ctx, isNull);
    });

    test('https://x| -> null', () {
      final (text, caret) = parseCaret('https://x|');
      final ctx = detectAutocompleteContext(text, caret);
      expect(ctx, isNull);
    });

    test('inside a code fence -> null', () {
      final (text, caret) = parseCaret('```\n/he|\n```');
      final ctx = detectAutocompleteContext(text, caret);
      expect(ctx, isNull);
    });

    test('/| (caret right after slash) -> context with query: ""', () {
      final (text, caret) = parseCaret('/|');
      final ctx = detectAutocompleteContext(text, caret);
      expect(ctx, isA<SlashContext>());
      final sc = ctx as SlashContext;
      expect(sc.query, equals(''));
      expect(sc.slashStart, equals(0));
      expect(sc.replaceStart, equals(0));
      expect(sc.replaceEnd, equals(caret));
    });

    test('/a b| -> null (space ends query)', () {
      final (text, caret) = parseCaret('/a b|');
      final ctx = detectAutocompleteContext(text, caret);
      expect(ctx, isNull);
    });

    test('with corePlugins.slashCommands = false -> null', () {
      final (text, caret) = parseCaret('/he|');
      final ctx = detectAutocompleteContext(text, caret, slashCommands: false);
      expect(ctx, isNull);
    });
  });
}
