// © 2026 Tephra. All rights reserved.

import '../nodes.dart';
import '../util/offset_map.dart';

final class CodeSpanResult {
  CodeSpanResult(this.node, this.nextIndex);
  final MdInlineCode node;
  final int nextIndex;
}

/// Tries to parse a code span starting at [index] in [text].
///
/// Returns [CodeSpanResult] if matched, or `null`.
CodeSpanResult? parseCodeSpan({
  required String text,
  required int index,
  required OffsetMap map,
  required bool inTableCell,
}) {
  if (text.codeUnitAt(index) != 0x60) return null; // '`'

  // Count opening backticks
  var openLen = 0;
  while (index + openLen < text.length &&
      text.codeUnitAt(index + openLen) == 0x60) {
    openLen++;
  }

  // Find matching run of exactly openLen backticks
  var i = index + openLen;
  var closeStart = -1;

  while (i < text.length) {
    if (text.codeUnitAt(i) == 0x60) {
      var count = 0;
      final start = i;
      while (i < text.length && text.codeUnitAt(i) == 0x60) {
        count++;
        i++;
      }
      if (count == openLen) {
        closeStart = start;
        break;
      }
    } else {
      i++;
    }
  }

  if (closeStart == -1) return null;

  var content = text.substring(index + openLen, closeStart);
  // Replace newlines with spaces
  content = content.replaceAll('\n', ' ');

  // If content begins and ends with space and contains at least one non-space, strip one space from both ends
  if (content.length >= 2 &&
      content.startsWith(' ') &&
      content.endsWith(' ') &&
      content.trim().isNotEmpty) {
    content = content.substring(1, content.length - 1);
  }

  // Inside table cell, replace \| with |
  if (inTableCell) {
    content = content.replaceAll(r'\|', '|');
  }

  final node = MdInlineCode(
    map.toSource(index),
    map.toSourceEnd(closeStart + openLen),
    code: content,
  );

  return CodeSpanResult(node, closeStart + openLen);
}
