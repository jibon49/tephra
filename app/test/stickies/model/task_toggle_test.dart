// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/stickies/model/task_toggle.dart';

void main() {
  group('toggleTaskAtLine', () {
    test('toggles [ ] to [x]', () {
      const input = '- [ ] Buy groceries';
      final toggled = toggleTaskAtLine(input, 0);
      expect(toggled, equals('- [x] Buy groceries'));
    });

    test('toggles [/] to [ ]', () {
      const input = '- [/] In progress task';
      final toggled = toggleTaskAtLine(input, 0);
      expect(toggled, equals('- [ ] In progress task'));

      const inputX = '* [x] Completed task';
      final toggledX = toggleTaskAtLine(inputX, 0);
      expect(toggledX, equals('* [ ] Completed task'));

      const inputDash = '+ [-] Cancelled task';
      final toggledDash = toggleTaskAtLine(inputDash, 0);
      expect(toggledDash, equals('+ [ ] Cancelled task'));
    });

    test('ordered list task', () {
      const input1 = '1. [ ] First task\n2. [x] Second task';
      final toggled1 = toggleTaskAtLine(input1, 0);
      expect(toggled1, equals('1. [x] First task\n2. [x] Second task'));

      final toggled2 = toggleTaskAtLine(input1, 1);
      expect(toggled2, equals('1. [ ] First task\n2. [ ] Second task'));

      const inputParen = '1) [ ] Task with paren';
      expect(toggleTaskAtLine(inputParen, 0), equals('1) [x] Task with paren'));
    });

    test('non-task line returns null', () {
      expect(toggleTaskAtLine('Regular text', 0), isNull);
      expect(toggleTaskAtLine('- Just a bullet', 0), isNull);
      expect(toggleTaskAtLine('1. Just a numbered item', 0), isNull);
      expect(toggleTaskAtLine('[ ] Not a list item', 0), isNull);
      expect(toggleTaskAtLine('', 0), isNull);
    });

    test('line out of range returns null', () {
      const input = '- [ ] Task 1\n- [ ] Task 2';
      expect(toggleTaskAtLine(input, -1), isNull);
      expect(toggleTaskAtLine(input, 2), isNull);
      expect(toggleTaskAtLine(input, 10), isNull);
    });

    test('other lines unchanged', () {
      const input =
          'Header line\n\n- [ ] Target task\nAnother line\n- [x] Other task\n';
      final toggled = toggleTaskAtLine(input, 2);
      const expected =
          'Header line\n\n- [x] Target task\nAnother line\n- [x] Other task\n';
      expect(toggled, equals(expected));
    });
  });
}
