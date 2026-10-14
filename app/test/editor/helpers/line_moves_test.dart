// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/editor/helpers/line_moves.dart';
import 'package:tephra/editor/line_view.dart';

import '../../helpers/marked_text.dart';

void main() {
  group('Line moves helpers tests', () {
    test('moveLinesUp table cases', () {
      final cases = [
        ('a⏎b|', 'b|⏎a'),
        ('a|⏎b', 'a|⏎b'), // line 0 -> no-op
      ];

      for (final (input, expected) in cases) {
        final parsed = parseMarked(input);
        final view = ListLineView.fromText(parsed.text);
        final plan = moveLinesUp(view, parsed.selection);

        expect(plan, isNotNull, reason: 'Expected plan for $input');
        var rendered = applyPlan(input, plan!)!;
        if (expected.contains('⏎')) {
          rendered = rendered.replaceAll('\n', '⏎');
        }
        expect(rendered, equals(expected), reason: 'Mismatch for $input');
      }
    });

    test('moveLinesDown table cases', () {
      final cases = [
        ('a|⏎b', 'b⏎a|'),
        ('a⏎b|', 'a⏎b|'), // last line -> no-op
        ('⟦a⏎b⟧⏎c', 'c⏎⟦a⏎b⟧'),
      ];

      for (final (input, expected) in cases) {
        final parsed = parseMarked(input);
        final view = ListLineView.fromText(parsed.text);
        final plan = moveLinesDown(view, parsed.selection);

        expect(plan, isNotNull, reason: 'Expected plan for $input');
        var rendered = applyPlan(input, plan!)!;
        if (expected.contains('⏎')) {
          rendered = rendered.replaceAll('\n', '⏎');
        }
        expect(rendered, equals(expected), reason: 'Mismatch for $input');
      }
    });

    test('duplicateLines table cases', () {
      final cases = [('a|', 'a⏎a|'), ('⟦a⏎b⟧', 'a⏎b⏎⟦a⏎b⟧'), ('a|b', 'ab⏎a|b')];

      for (final (input, expected) in cases) {
        final parsed = parseMarked(input);
        final view = ListLineView.fromText(parsed.text);
        final plan = duplicateLines(view, parsed.selection);

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
