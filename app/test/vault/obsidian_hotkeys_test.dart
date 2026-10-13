// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/vault/obsidian_hotkeys.dart';

void main() {
  test('converts Mod+b to Ctrl+B for editor:toggle-bold', () {
    final input = {
      'editor:toggle-bold': [
        {
          'modifiers': ['Mod'],
          'key': 'b',
        },
      ],
    };
    final out = convertObsidianHotkeys(input);
    expect(
      out,
      equals({
        'editor.toggle-bold': ['Ctrl+B'],
      }),
    );
  });

  test('converts Mod+Shift+ArrowUp to Ctrl+Shift+Up', () {
    final input = {
      'editor:swap-line-up': [
        {
          'modifiers': ['Mod', 'Shift'],
          'key': 'ArrowUp',
        },
      ],
    };
    final out = convertObsidianHotkeys(input);
    expect(
      out,
      equals({
        'editor.move-line-up': ['Ctrl+Shift+Up'],
      }),
    );
  });

  test(
    'sorts modifiers into Ctrl+Alt+Shift+Meta order regardless of input order',
    () {
      final input = {
        'editor:toggle-code': [
          {
            'modifiers': ['Alt', 'Mod'],
            'key': 'c',
          },
        ],
      };
      final out = convertObsidianHotkeys(input);
      expect(
        out,
        equals({
          'editor.toggle-code': ['Ctrl+Alt+C'],
        }),
      );
    },
  );

  test('skips unknown commands and drops unknown keys', () {
    final input = {
      'unknown:command': [
        {
          'modifiers': ['Mod'],
          'key': 'x',
        },
      ],
      'editor:save-file': [
        {
          'modifiers': ['Mod'],
          'key': 'UnknownKeyName',
        },
        {
          'modifiers': ['Mod'],
          'key': 's',
        },
      ],
    };
    final out = convertObsidianHotkeys(input);
    expect(
      out,
      equals({
        'note.save': ['Ctrl+S'],
      }),
    );
  });

  test('empty list stays empty list (unbound)', () {
    final input = {'editor:open-search': <dynamic>[]};
    final out = convertObsidianHotkeys(input);
    expect(out, equals({'editor.find': <String>[]}));
  });

  test('keeps multiple shortcuts for a single command', () {
    final input = {
      'editor:open-search': [
        {
          'modifiers': ['Mod'],
          'key': 'f',
        },
        {
          'modifiers': ['Mod', 'Alt'],
          'key': 'f',
        },
      ],
    };
    final out = convertObsidianHotkeys(input);
    expect(
      out,
      equals({
        'editor.find': ['Ctrl+F', 'Ctrl+Alt+F'],
      }),
    );
  });
}
