// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/editor/helpers/block_format.dart';
import 'package:tephra/editor/line_view.dart';

import '../../helpers/marked_text.dart';

void main() {
  group('Block format helpers tests', () {
    test('toggleBulletList cases', () {
      final cases = [
        ('a|', '- a|'),
        ('- a|', 'a|'),
        ('- [ ] a|', 'a|'),
        ('1. a|', '- a|'),
        ('⟦a⏎b⟧', '⟦- a⏎- b⟧'),
        ('⟦- a⏎b⟧', '⟦- a⏎- b⟧'),
      ];

      for (final (input, expected) in cases) {
        final parsed = parseMarked(input);
        final view = ListLineView.fromText(parsed.text);
        final plan = toggleBulletList(view, parsed.selection);

        expect(plan, isNotNull, reason: 'Expected plan for $input');
        var rendered = applyPlan(input, plan!)!;
        if (expected.contains('⏎')) {
          rendered = rendered.replaceAll('\n', '⏎');
        }
        expect(rendered, equals(expected), reason: 'Mismatch for $input');
      }
    });

    test('toggleNumberedList cases', () {
      final cases = [
        ('⟦a⏎b⟧', '⟦1. a⏎2. b⟧'),
        ('1. a|', 'a|'),
        ('- a|', '1. a|'),
      ];

      for (final (input, expected) in cases) {
        final parsed = parseMarked(input);
        final view = ListLineView.fromText(parsed.text);
        final plan = toggleNumberedList(view, parsed.selection);

        expect(plan, isNotNull, reason: 'Expected plan for $input');
        var rendered = applyPlan(input, plan!)!;
        if (expected.contains('⏎')) {
          rendered = rendered.replaceAll('\n', '⏎');
        }
        expect(rendered, equals(expected), reason: 'Mismatch for $input');
      }
    });

    test('toggleQuote cases', () {
      final cases = [('a|', '> a|'), ('> a|', 'a|'), ('⟦a⏎⏎b⟧', '⟦> a⏎>⏎> b⟧')];

      for (final (input, expected) in cases) {
        final parsed = parseMarked(input);
        final view = ListLineView.fromText(parsed.text);
        final plan = toggleQuote(view, parsed.selection);

        expect(plan, isNotNull, reason: 'Expected plan for $input');
        var rendered = applyPlan(input, plan!)!;
        if (expected.contains('⏎')) {
          rendered = rendered.replaceAll('\n', '⏎');
        }
        expect(rendered, equals(expected), reason: 'Mismatch for $input');
      }
    });

    test('cycleHeading cases', () {
      final cases = [
        ('a|', '# a|'),
        ('### a|', '#### a|'),
        ('###### a|', 'a|'),
        ('#a|', '# #a|'),
      ];

      for (final (input, expected) in cases) {
        final parsed = parseMarked(input);
        final view = ListLineView.fromText(parsed.text);
        final plan = cycleHeading(view, parsed.selection);

        expect(plan, isNotNull, reason: 'Expected plan for $input');
        var rendered = applyPlan(input, plan!)!;
        if (expected.contains('⏎')) {
          rendered = rendered.replaceAll('\n', '⏎');
        }
        expect(rendered, equals(expected), reason: 'Mismatch for $input');
      }
    });

    test('toggleTaskStatus cases', () {
      final cases = [
        ('a|', '- [ ] a|'),
        ('- a|', '- [ ] a|'),
        ('- [ ] a|', '- [x] a|'),
        ('- [x] a|', '- [ ] a|'),
        ('- [/] a|', '- [x] a|'),
        ('|', '- [ ] |'),
        ('⟦a⏎b⟧', '⟦- [ ] a⏎- [ ] b⟧'),
      ];

      for (final (input, expected) in cases) {
        final parsed = parseMarked(input);
        final view = ListLineView.fromText(parsed.text);
        final plan = toggleTaskStatus(view, parsed.selection);

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
