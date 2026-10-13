// © 2026 Tephra. All rights reserved.

import '../nodes.dart';
import '../util/offset_map.dart';
import 'inline_parser.dart';

final class FootnoteRefResult {
  FootnoteRefResult(this.node, this.nextIndex);

  final MdFootnoteRef node;
  final int nextIndex;
}

final class InlineFootnoteResult {
  InlineFootnoteResult(this.node, this.nextIndex);

  final MdInlineFootnote node;
  final int nextIndex;
}

final RegExp _footnoteRefRegex = RegExp(r'\[\^([^\s\]\[\^]+)\]');

/// Tries to parse a footnote reference `[^label]` starting at [index] in [text].
FootnoteRefResult? parseFootnoteRef({
  required String text,
  required int index,
  required OffsetMap map,
}) {
  if (text.codeUnitAt(index) != 0x5B) return null; // '['
  if (index + 1 >= text.length || text.codeUnitAt(index + 1) != 0x5E) {
    return null; // '^'
  }

  final match = _footnoteRefRegex.matchAsPrefix(text, index);
  if (match == null) return null;

  final label = match.group(1)!;
  final end = index + match.group(0)!.length;

  final node = MdFootnoteRef(
    map.toSource(index),
    map.toSourceEnd(end),
    label: label,
  );

  return FootnoteRefResult(node, end);
}

/// Tries to parse an inline footnote `^[inline note]` starting at [index] in [text].
InlineFootnoteResult? parseInlineFootnote({
  required String text,
  required int index,
  required OffsetMap map,
  required InlineContext ctx,
  required List<MdNode> Function(InlineSource, InlineContext) parseInlinesFn,
}) {
  if (index + 1 >= text.length) return null;
  if (text.codeUnitAt(index) != 0x5E || text.codeUnitAt(index + 1) != 0x5B) {
    return null; // '^['
  }

  var depth = 1;
  var j = index + 2;
  var closeIdx = -1;

  while (j < text.length) {
    final code = text.codeUnitAt(j);
    if (code == 0x5C && j + 1 < text.length) {
      // '\\'
      j += 2;
      continue;
    }
    if (code == 0x5B) {
      // '['
      depth++;
      j++;
      continue;
    }
    if (code == 0x5D) {
      // ']'
      depth--;
      if (depth == 0) {
        closeIdx = j;
        break;
      }
      j++;
      continue;
    }
    j++;
  }

  if (closeIdx == -1) return null;

  final innerText = text.substring(index + 2, closeIdx);
  final innerMap = OffsetMap.shifted(map, index + 2);
  final children = parseInlinesFn(
    InlineSource(text: innerText, map: innerMap),
    ctx,
  );

  final end = closeIdx + 1;
  final node = MdInlineFootnote(
    map.toSource(index),
    map.toSourceEnd(end),
    children: children,
  );

  return InlineFootnoteResult(node, end);
}
