// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/stickies/windows/accelerator.dart';

void main() {
  group('Accelerator', () {
    test('parses Ctrl+Alt+N', () {
      final acc = Accelerator.parse('Ctrl+Alt+N');
      expect(acc.key, 'N');
      expect(acc.hasControl, isTrue);
      expect(acc.hasAlt, isTrue);
      expect(acc.hasShift, isFalse);
      expect(acc.hasMeta, isFalse);
      expect(acc.format(), 'Ctrl+Alt+N');
    });

    test('case-insensitive', () {
      final acc1 = Accelerator.parse('ctrl+alt+n');
      final acc2 = Accelerator.parse('CTRL+ALT+N');
      final acc3 = Accelerator.parse('control+alt+n');
      expect(acc1, equals(acc2));
      expect(acc1, equals(acc3));
      expect(acc1.key, 'N');
      expect(acc1.modifiers, {
        AcceleratorModifier.control,
        AcceleratorModifier.alt,
      });
    });

    test('rejects N alone', () {
      expect(() => Accelerator.parse('N'), throwsA(isA<FormatException>()));
    });

    test('rejects Shift+N without Ctrl/Alt/Win', () {
      expect(
        () => Accelerator.parse('Shift+N'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects unknown key', () {
      expect(
        () => Accelerator.parse('Ctrl+Alt+Enter'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => Accelerator.parse('Ctrl+Alt+Foo'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => Accelerator.parse('Ctrl+Alt+F13'),
        throwsA(isA<FormatException>()),
      );
    });

    test('F5 with Ctrl ok', () {
      final acc = Accelerator.parse('Ctrl+F5');
      expect(acc.key, 'F5');
      expect(acc.hasControl, isTrue);
      expect(acc.hasAlt, isFalse);
      expect(acc.format(), 'Ctrl+F5');
    });

    test('accepts Win/Meta modifier and digit keys', () {
      final acc = Accelerator.parse('Win+Shift+9');
      expect(acc.key, '9');
      expect(acc.hasMeta, isTrue);
      expect(acc.hasShift, isTrue);
      expect(acc.hasControl, isFalse);
      expect(acc.format(), 'Shift+Win+9');
    });

    test('rejects invalid syntax or empty keys', () {
      expect(() => Accelerator.parse(''), throwsA(isA<FormatException>()));
      expect(
        () => Accelerator.parse('Ctrl++N'),
        throwsA(isA<FormatException>()),
      );
      expect(() => Accelerator.parse('Ctrl+'), throwsA(isA<FormatException>()));
      expect(
        () => Accelerator.parse('Ctrl+Alt+A+B'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
