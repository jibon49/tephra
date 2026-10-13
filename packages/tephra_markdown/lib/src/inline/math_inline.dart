// © 2026 Tephra. All rights reserved.

import '../nodes.dart';
import '../util/offset_map.dart';
import '../util/unicode.dart';

final class MathInlineResult {
  MathInlineResult(this.node, this.nextIndex);

  final MdInlineMath node;
  final int nextIndex;
}

/// Tries to parse an Obsidian inline math expression starting at [index] in [text].
MathInlineResult? parseMathInline({
  required String text,
  required int index,
  required OffsetMap map,
}) {
  if (text.codeUnitAt(index) != 0x24) return null; // '$'

  // 1. Double dollar $$...$$
  if (text.startsWith(r'$$', index)) {
    final closeIdx = text.indexOf(r'$$', index + 2);
    if (closeIdx != -1) {
      final tex = text.substring(index + 2, closeIdx);
      if (tex.isNotEmpty &&
          !tex.startsWith(' ') &&
          !tex.startsWith('\t') &&
          !tex.startsWith('\n') &&
          !tex.endsWith(' ') &&
          !tex.endsWith('\t') &&
          !tex.endsWith('\n')) {
        final end = closeIdx + 2;
        final node = MdInlineMath(
          map.toSource(index),
          map.toSourceEnd(end),
          tex: tex,
        );
        return MathInlineResult(node, end);
      }
    }
    return null;
  }

  // 2. Single dollar $...$
  if (index + 1 >= text.length) return null;
  final nextChar = text.codeUnitAt(index + 1);
  if (isUnicodeWhitespace(nextChar)) return null;

  var j = index + 1;
  while (j < text.length) {
    if (text.codeUnitAt(j) == 0x5C) {
      // '\\'
      j += 2;
      continue;
    }
    if (text.codeUnitAt(j) == 0x0A) {
      // '\n'
      // Check for blank line following \n
      var k = j + 1;
      while (k < text.length &&
          (text.codeUnitAt(k) == 0x20 || text.codeUnitAt(k) == 0x09)) {
        k++;
      }
      if (k < text.length && text.codeUnitAt(k) == 0x0A) {
        // Blank line encountered -> not closed
        return null;
      }
      j++;
      continue;
    }
    if (text.codeUnitAt(j) == 0x24) {
      // '$'
      // Check closing $ conditions:
      // Char before closing $ must not be whitespace
      final prevChar = text.codeUnitAt(j - 1);
      if (isUnicodeWhitespace(prevChar)) {
        j++;
        continue;
      }
      // Closing $ must not be followed by a digit
      if (j + 1 < text.length) {
        final afterClose = text.codeUnitAt(j + 1);
        if (afterClose >= 0x30 && afterClose <= 0x39) {
          // '0'-'9'
          j++;
          continue;
        }
      }
      final tex = text.substring(index + 1, j);
      if (tex.isNotEmpty) {
        final end = j + 1;
        final node = MdInlineMath(
          map.toSource(index),
          map.toSourceEnd(end),
          tex: tex,
        );
        return MathInlineResult(node, end);
      }
    }
    j++;
  }

  return null;
}
