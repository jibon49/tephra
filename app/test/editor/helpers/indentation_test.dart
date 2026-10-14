// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/editor/editor_options.dart';
import 'package:tephra/editor/helpers/indentation.dart';
import 'package:tephra/editor/line_view.dart';

import '../../helpers/marked_text.dart';

void main() {
  group('Indentation helpers tests', () {
    test('indentOnTab table cases', () {
      final cases = [
        ('- a|', false, const EditorOptions(useTab: true), '\t- a|'),
        ('a|', false, const EditorOptions(useTab: true), 'a\t|'),
        ('⟦a⏎b⟧', false, const EditorOptions(useTab: true), '⟦\ta⏎\tb⟧'),
        ('⟦a⏎⟧b', false, const EditorOptions(useTab: true), '⟦\ta⏎⟧b'),
        ('⟦a⏎\tb⟧', false, const EditorOptions(useTab: true), '⟦\ta⏎\t\tb⟧'),
        ('⟦a⏎⏎b⟧', false, const EditorOptions(useTab: true), '⟦\ta⏎⏎\tb⟧'),
        ('\t- a|', true, const EditorOptions(useTab: true), '- a|'),
        (
          '    - a|',
          true,
          const EditorOptions(useTab: true, tabSize: 4),
          '- a|',
        ),
        ('  - a|', true, const EditorOptions(useTab: true, tabSize: 4), '- a|'),
        ('- a|', true, const EditorOptions(useTab: true), '- a|'),
        ('⟦\ta⏎\tb⟧', true, const EditorOptions(useTab: true), '⟦a⏎b⟧'),
        (
          '- a|',
          false,
          const EditorOptions(useTab: false, tabSize: 4),
          '    - a|',
        ),
        ('a|', false, const EditorOptions(useTab: false, tabSize: 2), 'a  |'),
      ];

      for (final (input, shift, options, expected) in cases) {
        final parsed = parseMarked(input);
        final view = ListLineView.fromText(parsed.text);
        final plan = indentOnTab(view, parsed.selection, options, shift: shift);

        expect(
          plan,
          isNotNull,
          reason: 'Expected plan for $input with shift=$shift',
        );

        var rendered = applyPlan(input, plan!)!;
        if (expected.contains('⏎')) {
          rendered = rendered.replaceAll('\n', '⏎');
        }
        expect(
          rendered,
          equals(expected),
          reason: 'Mismatch for $input with shift=$shift',
        );
      }
    });
  });
}
