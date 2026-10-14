// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/editor/helpers/auto_pair.dart';
import 'package:tephra/editor/line_view.dart';

import '../../helpers/marked_text.dart';

void main() {
  group('Auto-pair typing tests', () {
    test('autoPairOnType table cases', () {
      final cases = [
        ('|', '(', '(|)', false),
        ('a|', '(', 'a(|)', false),
        ('|b', '(', null, false),
        ('⟦ab⟧', '(', '(⟦ab⟧)', false),
        ('⟦ab⟧', '*', '*⟦ab⟧*', false),
        ('⟦ab⟧', '"', '"⟦ab⟧"', false),
        ('|', '*', '*|*', false),
        ('x |', '*', 'x *|*', false),
        ('a|', '*', null, false),
        ('snake|', '_', null, false),
        ('|', '`', '`|`', false),
        ('don|', "'", null, false),
        ('|', r'$', null, false),
        ('|', '~', null, false),
        ('(|', '[', '([|]', false),
        ('a (|', '(', 'a ((|)', false),
        ('|', '(', null, true), // disabled -> null
        ('|', 'ab', null, false), // multi-char -> null
      ];

      for (final (input, typed, expected, disabled) in cases) {
        final parsed = parseMarked(input);
        final view = ListLineView.fromText(parsed.text);
        final tracker = AutoPairTracker();

        final plan = autoPairOnType(
          view,
          parsed.selection,
          typed,
          tracker,
          disabled: disabled,
        );

        if (expected == null) {
          expect(
            plan,
            isNull,
            reason: 'Expected no plan for $input with typed "$typed"',
          );
        } else {
          expect(
            plan,
            isNotNull,
            reason: 'Expected plan for $input with typed "$typed"',
          );
          final rendered = applyPlan(input, plan!);
          expect(
            rendered,
            equals(expected),
            reason: 'Mismatch for $input with typed "$typed"',
          );
        }
      }
    });

    test('skip-over with tracked vs untracked closer', () {
      // (|) tracked [type )] => ()|
      {
        final parsed = parseMarked('(|)');
        final view = ListLineView.fromText(parsed.text);
        final tracker = AutoPairTracker()..add(const LinePos(0, 1));
        final plan = autoPairOnType(view, parsed.selection, ')', tracker);
        expect(plan, isNotNull);
        final rendered = applyPlan('(|)', plan!);
        expect(rendered, equals('()|'));
        expect(tracker.contains(const LinePos(0, 1)), isFalse);
      }

      // (|) untracked [type )] => null
      {
        final parsed = parseMarked('(|)');
        final view = ListLineView.fromText(parsed.text);
        final tracker = AutoPairTracker();
        final plan = autoPairOnType(view, parsed.selection, ')', tracker);
        expect(plan, isNull);
      }

      // "|" tracked [type "] => ""|
      {
        final parsed = parseMarked('"|"');
        final view = ListLineView.fromText(parsed.text);
        final tracker = AutoPairTracker()..add(const LinePos(0, 1));
        final plan = autoPairOnType(view, parsed.selection, '"', tracker);
        expect(plan, isNotNull);
        final rendered = applyPlan('"|"', plan!);
        expect(rendered, equals('""|'));
      }

      // *|* tracked [type *] => **|
      {
        final parsed = parseMarked('*|*');
        final view = ListLineView.fromText(parsed.text);
        final tracker = AutoPairTracker()..add(const LinePos(0, 1));
        final plan = autoPairOnType(view, parsed.selection, '*', tracker);
        expect(plan, isNotNull);
        final rendered = applyPlan('*|*', plan!);
        expect(rendered, equals('**|'));
      }
    });

    test('autoPairOnBackspace cases', () {
      // [|] tracked [backspace] => |
      {
        final parsed = parseMarked('[|]');
        final view = ListLineView.fromText(parsed.text);
        final tracker = AutoPairTracker()..add(const LinePos(0, 1));
        final plan = autoPairOnBackspace(view, parsed.selection, tracker);
        expect(plan, isNotNull);
        final rendered = applyPlan('[|]', plan!);
        expect(rendered, equals('|'));
      }

      // [|] untracked [backspace] => null
      {
        final parsed = parseMarked('[|]');
        final view = ListLineView.fromText(parsed.text);
        final tracker = AutoPairTracker();
        final plan = autoPairOnBackspace(view, parsed.selection, tracker);
        expect(plan, isNull);
      }

      // a(|) tracked [backspace] => a|
      {
        final parsed = parseMarked('a(|)');
        final view = ListLineView.fromText(parsed.text);
        final tracker = AutoPairTracker()..add(const LinePos(0, 2));
        final plan = autoPairOnBackspace(view, parsed.selection, tracker);
        expect(plan, isNotNull);
        final rendered = applyPlan('a(|)', plan!);
        expect(rendered, equals('a|'));
      }

      // (| [backspace] => null
      {
        final parsed = parseMarked('(|');
        final view = ListLineView.fromText(parsed.text);
        final tracker = AutoPairTracker();
        final plan = autoPairOnBackspace(view, parsed.selection, tracker);
        expect(plan, isNull);
      }
    });
  });

  group('AutoPairTracker mapping and prune', () {
    test('onEdit shifts tracked closer on same line', () {
      final tracker = AutoPairTracker()..add(const LinePos(0, 5));
      // Insert 2 chars at col 2
      tracker.onEdit(const LineEdit(LinePos(0, 2), LinePos(0, 2), 'ab'));
      expect(tracker.contains(const LinePos(0, 7)), isTrue);
    });

    test('onEdit shifts tracked closer when line inserted above', () {
      final tracker = AutoPairTracker()..add(const LinePos(1, 4));
      // Insert line at line 0
      tracker.onEdit(const LineEdit(LinePos(0, 0), LinePos(0, 0), 'new\n'));
      expect(tracker.contains(const LinePos(2, 4)), isTrue);
    });

    test('onEdit removes closer when deleted', () {
      final tracker = AutoPairTracker()..add(const LinePos(0, 3));
      // Delete range covering col 3
      tracker.onEdit(const LineEdit(LinePos(0, 1), LinePos(0, 4), ''));
      expect(tracker.contains(const LinePos(0, 3)), isFalse);
    });

    test('prune drops stale entries where character is no longer closer', () {
      final tracker = AutoPairTracker()
        ..add(const LinePos(0, 1))
        ..add(const LinePos(0, 4));
      // Document text: '(abc' (col 1 is 'a', not closer; col 4 is out of range)
      final view = ListLineView(['(abc']);
      tracker.prune(view);
      expect(tracker.contains(const LinePos(0, 1)), isFalse);
      expect(tracker.contains(const LinePos(0, 4)), isFalse);
    });
  });
}
