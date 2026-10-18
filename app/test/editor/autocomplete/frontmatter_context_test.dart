// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/editor/autocomplete/autocomplete_context.dart';

void main() {
  group('Frontmatter context detection', () {
    (String, int) parseCaret(String input) {
      final idx = input.lastIndexOf('|');
      expect(idx, isNot(-1), reason: 'input must contain "|" indicating caret');
      final text = input.substring(0, idx) + input.substring(idx + 1);
      return (text, idx);
    }

    test('---\\nsta|\\n---\\n -> PropertyKeyContext(query: "sta")', () {
      final (text, caret) = parseCaret('---\nsta|\n---\n');
      final ctx = detectAutocompleteContext(text, caret);
      expect(ctx, isA<PropertyKeyContext>());
      final pkc = ctx as PropertyKeyContext;
      expect(pkc.query, equals('sta'));
    });

    test('---\\nstatus: dr|\\n---\\n -> PropertyValueContext(key: "status", query: "dr")', () {
      final (text, caret) = parseCaret('---\nstatus: dr|\n---\n');
      final ctx = detectAutocompleteContext(text, caret);
      expect(ctx, isA<PropertyValueContext>());
      final pvc = ctx as PropertyValueContext;
      expect(pvc.key, equals('status'));
      expect(pvc.query, equals('dr'));
      expect(pvc.inInlineList, isFalse);
    });

    test('---\\ntags:\\n  - pro|\\n---\\n -> key "tags"', () {
      final (text, caret) = parseCaret('---\ntags:\n  - pro|\n---\n');
      final ctx = detectAutocompleteContext(text, caret);
      expect(ctx, isA<PropertyValueContext>());
      final pvc = ctx as PropertyValueContext;
      expect(pvc.key, equals('tags'));
      expect(pvc.query, equals('pro'));
      expect(pvc.inInlineList, isFalse);
    });

    test('---\\naliases: [A, B|\\n---\\n -> inInlineList, query "B"', () {
      final (text, caret) = parseCaret('---\naliases: [A, B|\n---\n');
      final ctx = detectAutocompleteContext(text, caret);
      expect(ctx, isA<PropertyValueContext>());
      final pvc = ctx as PropertyValueContext;
      expect(pvc.key, equals('aliases'));
      expect(pvc.query, equals('B'));
      expect(pvc.inInlineList, isTrue);
    });

    test('---\\ntitle: "x|\\n---\\n -> null (inside quotes)', () {
      final (text, caret) = parseCaret('---\ntitle: "x|\n---\n');
      final ctx = detectAutocompleteContext(text, caret);
      expect(ctx, isNull);
    });

    test('body line sta| after the closing --- -> null', () {
      final (text, caret) = parseCaret('---\n---\nsta|');
      final ctx = detectAutocompleteContext(text, caret);
      expect(ctx, isNull);
    });

    test('frontmatter never closed: ---\\nsta| -> key context', () {
      final (text, caret) = parseCaret('---\nsta|');
      final ctx = detectAutocompleteContext(text, caret);
      expect(ctx, isA<PropertyKeyContext>());
      final pkc = ctx as PropertyKeyContext;
      expect(pkc.query, equals('sta'));
    });
  });
}
