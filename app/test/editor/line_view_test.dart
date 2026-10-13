// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/editor/line_view.dart';

import '../helpers/marked_text.dart';

void main() {
  group('LineView & LinePos', () {
    test(
      'offsetOf and posOf round trip over a\\nbc\\n\\nd for every offset',
      () {
        const text = 'a\nbc\n\nd';
        final view = ListLineView.fromText(text);
        expect(view.lineCount, 4);
        expect(view.lineAt(0), 'a');
        expect(view.lineAt(1), 'bc');
        expect(view.lineAt(2), '');
        expect(view.lineAt(3), 'd');

        for (var offset = 0; offset <= text.length; offset++) {
          final pos = posOf(view, offset);
          final roundTripOffset = offsetOf(view, pos);
          expect(roundTripOffset, offset, reason: 'Mismatch at offset $offset');
        }
      },
    );

    test('emoji line posOf and offsetOf round trip correctly', () {
      const text = 'hello 🌍 world\nsecond line';
      final view = ListLineView.fromText(text);

      for (var offset = 0; offset <= text.length; offset++) {
        final pos = posOf(view, offset);
        final roundTripOffset = offsetOf(view, pos);
        expect(
          roundTripOffset,
          offset,
          reason: 'Mismatch at emoji offset $offset',
        );
      }
    });

    test('ListLineView.fromText("") has 1 line', () {
      final view = ListLineView.fromText('');
      expect(view.lineCount, 1);
      expect(view.lineAt(0), '');
      expect(offsetOf(view, const LinePos(0, 0)), 0);
      expect(posOf(view, 0), const LinePos(0, 0));
    });

    test('out of bounds offsetOf clamps correctly', () {
      final view = ListLineView.fromText('hello\nworld');
      expect(offsetOf(view, const LinePos(-1, 0)), 0);
      expect(offsetOf(view, const LinePos(10, 0)), 11); // total length
      expect(offsetOf(view, const LinePos(0, 99)), 5); // end of line 0
    });

    test('posOf clamps negative and beyond total length', () {
      final view = ListLineView.fromText('hello\nworld');
      expect(posOf(view, -5), const LinePos(0, 0));
      expect(posOf(view, 100), const LinePos(1, 5));
    });
  });

  group('MarkedText notation round trip', () {
    test('round trip for a⟦b⏎c⟧d', () {
      const marked = 'a⟦b⏎c⟧d';
      final parsed = parseMarked(marked);
      expect(parsed.text, 'ab\ncd');
      expect(parsed.selection.base, const LinePos(0, 1));
      expect(parsed.selection.extent, const LinePos(1, 1));
      expect(parsed.usedReturnSymbol, isTrue);

      final rendered = renderMarked(
        parsed.text,
        parsed.selection,
        useReturnSymbol: parsed.usedReturnSymbol,
      );
      expect(rendered, marked);
    });

    test('round trip for collapsed caret |', () {
      const marked = '|';
      final parsed = parseMarked(marked);
      expect(parsed.text, '');
      expect(parsed.selection.isCollapsed, isTrue);
      expect(parsed.selection.base, const LinePos(0, 0));

      final rendered = renderMarked(parsed.text, parsed.selection);
      expect(rendered, marked);
    });

    test('round trip for empty selection ⟦⟧', () {
      const marked = '⟦⟧';
      final parsed = parseMarked(marked);
      expect(parsed.text, '');
      expect(parsed.selection.base, const LinePos(0, 0));
      expect(parsed.selection.extent, const LinePos(0, 0));

      // With base == extent, renderMarked renders as collapsed caret or ⟦⟧
      final rendered = renderMarked(parsed.text, parsed.selection);
      expect(rendered, '|');
    });

    test('applyPlan replaces text and positions cursor', () {
      const initial = 'hello |world';
      const plan = EditPlan(
        edits: [LineEdit(LinePos(0, 6), LinePos(0, 11), 'earth')],
        selection: EditorSelection.collapsed(LinePos(0, 11)),
      );
      final result = applyPlan(initial, plan);
      expect(result, 'hello earth|');
    });
  });
}
