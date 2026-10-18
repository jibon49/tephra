// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/editor/autocomplete/autocomplete_context.dart';
import 'package:tephra/editor/autocomplete/slash_commands.dart';
import 'package:tephra/editor/autocomplete/snippet_placement.dart';
import 'package:tephra/settings/vault_settings.dart';
import 'package:tephra_index/tephra_index.dart';

void main() {
  group('snippet_placement', () {
    (String, int) parseCaret(String input) {
      final idx = input.lastIndexOf('|');
      expect(idx, isNot(-1), reason: 'input must contain "|" indicating caret');
      final text = input.substring(0, idx) + input.substring(idx + 1);
      return (text, idx);
    }

    final commandsMap = {for (final c in defaultSlashCommands) c.id: c};
    final now = DateTime(2026, 10, 15, 14, 5, 9);
    const settings = VaultSettings();

    test('/h2| at line start in "a\\n/h2" -> "a\\n## "', () {
      final (text, caret) = parseCaret('a\n/h2|');
      final ctx = detectAutocompleteContext(text, caret) as SlashContext;
      final cmd = commandsMap['heading2']!;
      final snippet = cmd.build(SlashInput(now: now, settings: settings));

      final ins = placeSlash(text, ctx, cmd, snippet);
      final newText = applyTextEdits(text, ins.edits);
      expect(newText, equals('a\n## '));
      expect(ins.caretAfter, equals(5));
    });

    test(
      'foo /h2| -> "## foo " (prefix inserted at line start, /h2 deleted)',
      () {
        final (text, caret) = parseCaret('foo /h2|');
        final ctx = detectAutocompleteContext(text, caret) as SlashContext;
        final cmd = commandsMap['heading2']!;
        final snippet = cmd.build(SlashInput(now: now, settings: settings));

        final ins = placeSlash(text, ctx, cmd, snippet);
        final newText = applyTextEdits(text, ins.edits);
        expect(newText, equals('## foo '));
        expect(ins.caretAfter, equals(7));
      },
    );

    test('- item /callout-tip| -> linePrefix is two spaces', () {
      final (text, caret) = parseCaret('- item /callout-tip|');
      final ctx = detectAutocompleteContext(text, caret) as SlashContext;
      final cmd = commandsMap['callout-tip']!;
      final snippet = cmd.build(SlashInput(now: now, settings: settings));

      final ins = placeSlash(text, ctx, cmd, snippet);
      final newText = applyTextEdits(text, ins.edits);
      expect(newText, equals('- item \n  > [!tip]\n  > '));
      expect(ins.caretAfter, equals(newText.length));
    });

    test('> /callout-tip| (inside a quote) -> "> > [!tip]\\n> > "', () {
      final (text, caret) = parseCaret('> /callout-tip|');
      final ctx = detectAutocompleteContext(text, caret) as SlashContext;
      final cmd = commandsMap['callout-tip']!;
      final snippet = cmd.build(SlashInput(now: now, settings: settings));

      final ins = placeSlash(text, ctx, cmd, snippet);
      final newText = applyTextEdits(text, ins.edits);
      expect(newText, equals('> > [!tip]\n> > '));
      expect(ins.caretAfter, equals(newText.length));
    });

    test('/table| on an empty line -> 4-line table with caret after first "| "', () {
      final (text, caret) = parseCaret('/table|');
      final ctx = detectAutocompleteContext(text, caret) as SlashContext;
      final cmd = commandsMap['table']!;
      final snippet = cmd.build(SlashInput(now: now, settings: settings));

      final ins = placeSlash(text, ctx, cmd, snippet);
      final newText = applyTextEdits(text, ins.edits);
      const expected =
          '|   |   |   |\n| --- | --- | --- |\n|   |   |   |\n|   |   |   |\n';
      expect(newText, equals(expected));
      expect(ins.caretAfter, equals(2));
    });

    test('/hr| after a paragraph line -> blank line + "---"', () {
      final (text, caret) = parseCaret('Hello paragraph\n/hr|');
      final ctx = detectAutocompleteContext(text, caret) as SlashContext;
      final cmd = commandsMap['horizontal-rule']!;
      final snippet = cmd.build(
        SlashInput(now: now, settings: settings, isLineZero: false),
      );

      final ins = placeSlash(text, ctx, cmd, snippet);
      final newText = applyTextEdits(text, ins.edits);
      expect(newText, equals('Hello paragraph\n\n---'));
      expect(ins.caretAfter, equals(newText.length));
    });

    test('/hr| on line 0 -> "***"', () {
      final (text, caret) = parseCaret('/hr|');
      final ctx = detectAutocompleteContext(text, caret) as SlashContext;
      final cmd = commandsMap['horizontal-rule']!;
      final snippet = cmd.build(
        SlashInput(now: now, settings: settings, isLineZero: true),
      );

      final ins = placeSlash(text, ctx, cmd, snippet);
      final newText = applyTextEdits(text, ins.edits);
      expect(newText, equals('***'));
      expect(ins.caretAfter, equals(3));
    });

    test('/today| -> today\'s date, no newline', () {
      final (text, caret) = parseCaret('/today|');
      final ctx = detectAutocompleteContext(text, caret) as SlashContext;
      final cmd = commandsMap['today']!;
      final snippet = cmd.build(SlashInput(now: now, settings: settings));

      final ins = placeSlash(text, ctx, cmd, snippet);
      final newText = applyTextEdits(text, ins.edits);
      expect(newText, equals('2026-10-15'));
      expect(ins.caretAfter, equals(10));
    });

    test('/task| -> "- [ ] "', () {
      final (text, caret) = parseCaret('/task|');
      final ctx = detectAutocompleteContext(text, caret) as SlashContext;
      final cmd = commandsMap['task']!;
      final snippet = cmd.build(SlashInput(now: now, settings: settings));

      final ins = placeSlash(text, ctx, cmd, snippet);
      final newText = applyTextEdits(text, ins.edits);
      expect(newText, equals('- [ ] '));
      expect(ins.caretAfter, equals(6));
    });
  });
}
