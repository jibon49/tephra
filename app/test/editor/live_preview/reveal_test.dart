// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/editor/live_preview/lp_decoration.dart';
import 'package:tephra/editor/live_preview/reveal.dart';

void main() {
  group('Live Preview reveal rule', () {
    test('inclusive boundary touching', () {
      const dec = LpHide(0, 2, reveal: LpReveal(0, 8));

      // Caret exactly at boundary (8,8) touches [0..8] -> revealed
      expect(isRevealed(dec, const TextRange.range(8, 8)), isTrue);

      // Caret past boundary (9,9) does not touch [0..8] -> not revealed
      expect(isRevealed(dec, const TextRange.range(9, 9)), isFalse);

      // Selection overlapping range (3,12) -> revealed
      expect(isRevealed(dec, const TextRange.range(3, 12)), isTrue);

      // Backward selection (12, 3) -> revealed
      expect(isRevealed(dec, const TextRange.range(12, 3)), isTrue);
    });

    test('decoration with reveal == null is never revealed', () {
      const replaceChar = LpReplaceChar(0, 1, '•');
      expect(isRevealed(replaceChar, const TextRange.range(0, 0)), isFalse);
      expect(isRevealed(replaceChar, const TextRange.range(0, 5)), isFalse);
    });

    test('multi-line construct reveal covering lines 0-1', () {
      // Line 0: "Line 0\n" (0..7)
      // Line 1: "Line 1" (7..13)
      const calloutHeader = LpWidget(
        0,
        6,
        LpWidgetKind.calloutHeader,
        reveal: LpReveal(0, 13),
      );

      // Caret on line 1 at offset 10 reveals the construct
      expect(isRevealed(calloutHeader, const TextRange.collapsed(10)), isTrue);

      // Caret after construct at offset 15 does not reveal
      expect(isRevealed(calloutHeader, const TextRange.collapsed(15)), isFalse);
    });
  });
}
