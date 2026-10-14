// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/editor/helpers/list_continuation.dart';
import 'package:tephra/editor/line_view.dart';

import '../../helpers/marked_text.dart';

void main() {
  group('List continuation on Enter tests', () {
    test('listContinuationOnEnter table cases', () {
      final cases = [
        ('- a|', '- a⏎- |'),
        ('- a|b', '- a⏎- |b'),
        ('* a|', '* a⏎* |'),
        ('+ a|', '+ a⏎+ |'),
        ('1. a|', '1. a⏎2. |'),
        ('9. a|', '9. a⏎10. |'),
        ('1) a|', '1) a⏎2) |'),
        ('1. a|⏎2. b⏎3. c', '1. a⏎2. |⏎3. b⏎4. c'),
        ('1. a|⏎   - sub⏎2. b', '1. a⏎2. |⏎   - sub⏎3. b'),
        ('1. a|⏎2. b⏎5. c', '1. a⏎2. |⏎3. b⏎5. c'),
        ('- [ ] a|', '- [ ] a⏎- [ ] |'),
        ('- [x] a|', '- [x] a⏎- [ ] |'),
        ('- [/] a|', '- [/] a⏎- [ ] |'),
        ('  - a|', '  - a⏎  - |'),
        ('\t- a|', '\t- a⏎\t- |'),
        ('-\ta|', '-\ta⏎-\t|'),
        ('- |', '|'),
        ('1. |', '|'),
        ('  - [ ] |', '|'),
        ('- a|  with selection', null), // non-empty selection -> null
        ('a|', null),
        ('-a|', null),
        ('---|', null),
        ('|- a', null),
        ('- |a', '- ⏎- |a'),
      ];

      for (final (input, expected) in cases) {
        if (input == '- a|  with selection') {
          // Explicit non-empty selection case
          const marked = '- ⟦a⟧';
          final parsed = parseMarked(marked);
          final view = ListLineView.fromText(parsed.text);
          final plan = listContinuationOnEnter(view, parsed.selection);
          expect(plan, isNull);
          continue;
        }

        final parsed = parseMarked(input);
        final view = ListLineView.fromText(parsed.text);
        final plan = listContinuationOnEnter(view, parsed.selection);

        if (expected == null) {
          expect(plan, isNull, reason: 'Expected no plan for $input');
        } else {
          expect(plan, isNotNull, reason: 'Expected plan for $input');
          var rendered = applyPlan(input, plan!)!;
          if (expected.contains('⏎')) {
            rendered = rendered.replaceAll('\n', '⏎');
          }
          expect(
            rendered,
            equals(expected),
            reason: 'Mismatch for input $input',
          );
        }
      }
    });
  });
}
