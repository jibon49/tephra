// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/editor/helpers/inline_format.dart';
import 'package:tephra/editor/line_view.dart';

import '../../helpers/marked_text.dart';

void main() {
  group('Inline format helpers tests', () {
    test('toggleInlineFormat table cases', () {
      final cases = [
        ('hel|lo', InlineFormat.bold, '**hel|lo**'),
        ('**hel|lo**', InlineFormat.bold, 'hel|lo'),
        ('⟦hello⟧', InlineFormat.bold, '**⟦hello⟧**'),
        ('**⟦hello⟧**', InlineFormat.bold, '⟦hello⟧'),
        ('⟦**hello**⟧', InlineFormat.bold, '⟦hello⟧'),
        ('|', InlineFormat.bold, '**|**'),
        ('a | b', InlineFormat.bold, 'a **|** b'),
        ('a |b', InlineFormat.bold, 'a **|b**'),
        ('hello|', InlineFormat.bold, '**hello|**'),
        ('*hel|lo*', InlineFormat.italic, 'hel|lo'),
        ('hel|lo', InlineFormat.italic, '*hel|lo*'),
        ('**hel|lo**', InlineFormat.italic, '***hel|lo***'),
        ('***hel|lo***', InlineFormat.italic, '**hel|lo**'),
        ('***hel|lo***', InlineFormat.bold, '*hel|lo*'),
        ('⟦a⏎b⟧', InlineFormat.bold, '**⟦a⏎b⟧**'),
        ('⟦x⟧', InlineFormat.highlight, '==⟦x⟧=='),
        ('==⟦x⟧==', InlineFormat.highlight, '⟦x⟧'),
        ('⟦x⟧', InlineFormat.strikethrough, '~~⟦x⟧~~'),
        ('⟦code⟧', InlineFormat.code, '`⟦code⟧`'),
        ('`⟦code⟧`', InlineFormat.code, '⟦code⟧'),
      ];

      for (final (input, format, expected) in cases) {
        final parsed = parseMarked(input);
        final view = ListLineView.fromText(parsed.text);
        final plan = toggleInlineFormat(view, parsed.selection, format);

        expect(
          plan,
          isNotNull,
          reason: 'Expected plan for $input with format $format',
        );

        var rendered = applyPlan(input, plan!)!;
        if (expected.contains('⏎')) {
          rendered = rendered.replaceAll('\n', '⏎');
        }
        expect(
          rendered,
          equals(expected),
          reason: 'Mismatch for $input with format $format',
        );
      }
    });

    test('insertLink table cases', () {
      final cases = [
        ('⟦text⟧', '[text](|)'),
        ('⟦https://a.com⟧', '[|](https://a.com)'),
        ('|', '[|]()'),
      ];

      for (final (input, expected) in cases) {
        final parsed = parseMarked(input);
        final view = ListLineView.fromText(parsed.text);
        final plan = insertLink(view, parsed.selection);

        expect(plan, isNotNull, reason: 'Expected plan for $input');

        var rendered = applyPlan(input, plan!)!;
        if (expected.contains('⏎')) {
          rendered = rendered.replaceAll('\n', '⏎');
        }
        expect(rendered, equals(expected), reason: 'Mismatch for $input');
      }
    });
  });
}
