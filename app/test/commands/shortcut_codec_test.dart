// © 2026 Tephra. All rights reserved.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/commands/shortcut_codec.dart';

void main() {
  group('ShortcutCodec', () {
    test('parseShortcut and formatShortcut basic roundtrip', () {
      final a = parseShortcut('Ctrl+Shift+K');
      expect(a, isNotNull);
      expect(a!.trigger, LogicalKeyboardKey.keyK);
      expect(a.control, isTrue);
      expect(a.shift, isTrue);
      expect(a.alt, isFalse);
      expect(a.meta, isFalse);
      expect(formatShortcut(a), 'Ctrl+Shift+K');
    });

    test('case-insensitivity and canonical modifier order', () {
      final a = parseShortcut('shift+ctrl+k');
      expect(a, isNotNull);
      expect(formatShortcut(a!), 'Ctrl+Shift+K');
    });

    test('Mod maps to Ctrl', () {
      final a = parseShortcut('Mod+B');
      expect(a, isNotNull);
      expect(a!.control, isTrue);
      expect(formatShortcut(a), 'Ctrl+B');
    });

    test('common shortcuts round trip', () {
      final shortcuts = [
        'Ctrl+Tab',
        'Alt+Left',
        'F2',
        'Ctrl+,',
        r'Ctrl+\',
        'Ctrl+Enter',
        'Ctrl+Shift+Tab',
        'Ctrl+O',
        'Ctrl+P',
        'Ctrl+E',
        'Ctrl+N',
      ];
      for (final s in shortcuts) {
        final parsed = parseShortcut(s);
        expect(parsed, isNotNull, reason: 'Failed parsing $s');
        expect(formatShortcut(parsed!), s);
      }
    });

    test('invalid shortcuts return null', () {
      final invalid = [
        'Ctrl+',
        'Ctrl+Shift',
        'Ctrl+AB',
        'Foo+K',
        '',
        'Ctrl+Shift+Alt+Meta+',
        'UnknownKey',
      ];
      for (final s in invalid) {
        expect(parseShortcut(s), isNull, reason: 'Expected null for $s');
      }
    });

    test('round trip for every key name in grammar', () {
      final letters = [
        'A',
        'B',
        'C',
        'D',
        'E',
        'F',
        'G',
        'H',
        'I',
        'J',
        'K',
        'L',
        'M',
        'N',
        'O',
        'P',
        'Q',
        'R',
        'S',
        'T',
        'U',
        'V',
        'W',
        'X',
        'Y',
        'Z',
      ];
      final digits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
      final fKeys = [
        'F1',
        'F2',
        'F3',
        'F4',
        'F5',
        'F6',
        'F7',
        'F8',
        'F9',
        'F10',
        'F11',
        'F12',
      ];
      final navKeys = [
        'Enter',
        'Tab',
        'Escape',
        'Space',
        'Backspace',
        'Delete',
        'Insert',
        'Home',
        'End',
        'PageUp',
        'PageDown',
        'Up',
        'Down',
        'Left',
        'Right',
      ];
      final punctuation = [
        ',',
        '.',
        '/',
        r'\',
        ';',
        "'",
        '[',
        ']',
        '-',
        '=',
        '`',
      ];

      final allKeys = [
        ...letters,
        ...digits,
        ...fKeys,
        ...navKeys,
        ...punctuation,
      ];

      for (final k in allKeys) {
        final withModifier = 'Ctrl+$k';
        final parsed = parseShortcut(withModifier);
        expect(parsed, isNotNull, reason: 'Failed to parse $withModifier');
        expect(formatShortcut(parsed!), withModifier);
      }
    });
  });
}
