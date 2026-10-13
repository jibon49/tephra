// © 2026 Tephra. All rights reserved.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

final class ShortcutCodec {
  static const Map<String, (LogicalKeyboardKey, String)> _keyMap = {
    // Letters
    'a': (LogicalKeyboardKey.keyA, 'A'),
    'b': (LogicalKeyboardKey.keyB, 'B'),
    'c': (LogicalKeyboardKey.keyC, 'C'),
    'd': (LogicalKeyboardKey.keyD, 'D'),
    'e': (LogicalKeyboardKey.keyE, 'E'),
    'f': (LogicalKeyboardKey.keyF, 'F'),
    'g': (LogicalKeyboardKey.keyG, 'G'),
    'h': (LogicalKeyboardKey.keyH, 'H'),
    'i': (LogicalKeyboardKey.keyI, 'I'),
    'j': (LogicalKeyboardKey.keyJ, 'J'),
    'k': (LogicalKeyboardKey.keyK, 'K'),
    'l': (LogicalKeyboardKey.keyL, 'L'),
    'm': (LogicalKeyboardKey.keyM, 'M'),
    'n': (LogicalKeyboardKey.keyN, 'N'),
    'o': (LogicalKeyboardKey.keyO, 'O'),
    'p': (LogicalKeyboardKey.keyP, 'P'),
    'q': (LogicalKeyboardKey.keyQ, 'Q'),
    'r': (LogicalKeyboardKey.keyR, 'R'),
    's': (LogicalKeyboardKey.keyS, 'S'),
    't': (LogicalKeyboardKey.keyT, 'T'),
    'u': (LogicalKeyboardKey.keyU, 'U'),
    'v': (LogicalKeyboardKey.keyV, 'V'),
    'w': (LogicalKeyboardKey.keyW, 'W'),
    'x': (LogicalKeyboardKey.keyX, 'X'),
    'y': (LogicalKeyboardKey.keyY, 'Y'),
    'z': (LogicalKeyboardKey.keyZ, 'Z'),

    // Digits
    '0': (LogicalKeyboardKey.digit0, '0'),
    '1': (LogicalKeyboardKey.digit1, '1'),
    '2': (LogicalKeyboardKey.digit2, '2'),
    '3': (LogicalKeyboardKey.digit3, '3'),
    '4': (LogicalKeyboardKey.digit4, '4'),
    '5': (LogicalKeyboardKey.digit5, '5'),
    '6': (LogicalKeyboardKey.digit6, '6'),
    '7': (LogicalKeyboardKey.digit7, '7'),
    '8': (LogicalKeyboardKey.digit8, '8'),
    '9': (LogicalKeyboardKey.digit9, '9'),

    // Function keys
    'f1': (LogicalKeyboardKey.f1, 'F1'),
    'f2': (LogicalKeyboardKey.f2, 'F2'),
    'f3': (LogicalKeyboardKey.f3, 'F3'),
    'f4': (LogicalKeyboardKey.f4, 'F4'),
    'f5': (LogicalKeyboardKey.f5, 'F5'),
    'f6': (LogicalKeyboardKey.f6, 'F6'),
    'f7': (LogicalKeyboardKey.f7, 'F7'),
    'f8': (LogicalKeyboardKey.f8, 'F8'),
    'f9': (LogicalKeyboardKey.f9, 'F9'),
    'f10': (LogicalKeyboardKey.f10, 'F10'),
    'f11': (LogicalKeyboardKey.f11, 'F11'),
    'f12': (LogicalKeyboardKey.f12, 'F12'),

    // Special keys
    'enter': (LogicalKeyboardKey.enter, 'Enter'),
    'tab': (LogicalKeyboardKey.tab, 'Tab'),
    'escape': (LogicalKeyboardKey.escape, 'Escape'),
    'space': (LogicalKeyboardKey.space, 'Space'),
    'backspace': (LogicalKeyboardKey.backspace, 'Backspace'),
    'delete': (LogicalKeyboardKey.delete, 'Delete'),
    'insert': (LogicalKeyboardKey.insert, 'Insert'),
    'home': (LogicalKeyboardKey.home, 'Home'),
    'end': (LogicalKeyboardKey.end, 'End'),
    'pageup': (LogicalKeyboardKey.pageUp, 'PageUp'),
    'pagedown': (LogicalKeyboardKey.pageDown, 'PageDown'),
    'up': (LogicalKeyboardKey.arrowUp, 'Up'),
    'down': (LogicalKeyboardKey.arrowDown, 'Down'),
    'left': (LogicalKeyboardKey.arrowLeft, 'Left'),
    'right': (LogicalKeyboardKey.arrowRight, 'Right'),

    // Punctuation
    ',': (LogicalKeyboardKey.comma, ','),
    '.': (LogicalKeyboardKey.period, '.'),
    '/': (LogicalKeyboardKey.slash, '/'),
    r'\': (LogicalKeyboardKey.backslash, r'\'),
    ';': (LogicalKeyboardKey.semicolon, ';'),
    "'": (LogicalKeyboardKey.quote, "'"),
    '[': (LogicalKeyboardKey.bracketLeft, '['),
    ']': (LogicalKeyboardKey.bracketRight, ']'),
    '-': (LogicalKeyboardKey.minus, '-'),
    '=': (LogicalKeyboardKey.equal, '='),
    '`': (LogicalKeyboardKey.backquote, '`'),
  };

  static final Map<LogicalKeyboardKey, String> _reverseKeyMap = {
    for (final entry in _keyMap.values) entry.$1: entry.$2,
  };

  static SingleActivator? parseShortcut(String s) {
    if (s.isEmpty) return null;
    final tokens = s.split('+');
    for (final token in tokens) {
      if (token.isEmpty) return null;
    }

    var control = false;
    var alt = false;
    var shift = false;
    var meta = false;

    for (var i = 0; i < tokens.length - 1; i++) {
      final mod = tokens[i].toLowerCase();
      if (mod == 'ctrl' || mod == 'mod') {
        control = true;
      } else if (mod == 'alt') {
        alt = true;
      } else if (mod == 'shift') {
        shift = true;
      } else if (mod == 'meta') {
        meta = true;
      } else {
        return null;
      }
    }

    final keyToken = tokens.last.toLowerCase();
    final mapping = _keyMap[keyToken];
    if (mapping == null) return null;

    return SingleActivator(
      mapping.$1,
      control: control,
      alt: alt,
      shift: shift,
      meta: meta,
    );
  }

  static String formatShortcut(SingleActivator a) {
    final keyName = _reverseKeyMap[a.trigger];
    if (keyName == null) {
      return a.trigger.keyLabel;
    }

    final parts = <String>[];
    if (a.control) parts.add('Ctrl');
    if (a.alt) parts.add('Alt');
    if (a.shift) parts.add('Shift');
    if (a.meta) parts.add('Meta');
    parts.add(keyName);

    return parts.join('+');
  }
}

SingleActivator? parseShortcut(String s) => ShortcutCodec.parseShortcut(s);

String formatShortcut(SingleActivator a) => ShortcutCodec.formatShortcut(a);
