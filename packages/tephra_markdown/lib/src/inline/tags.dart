// © 2026 Tephra. All rights reserved.

import '../nodes.dart';
import '../util/offset_map.dart';
import '../util/unicode.dart';

final class TagResult {
  TagResult(this.node, this.nextIndex);

  final MdTag node;
  final int nextIndex;
}

final RegExp _tagRegex = RegExp(r'[\p{L}\p{M}\p{N}_\-/]+', unicode: true);
final RegExp _nonDigitRegex = RegExp(r'[^0-9]');

/// Checks if [index] in [text] is at a valid boundary to start an Obsidian tag.
bool isTagBoundary(String text, int index) {
  if (index == 0) return true;
  final prev = text.codeUnitAt(index - 1);
  if (prev == 0x23) return false; // '#'
  if (isUnicodeWhitespace(prev)) return true;
  if (prev == 0x28 || // '('
      prev == 0x5B || // '['
      prev == 0x7B || // '{'
      prev == 0x22 || // '"'
      prev == 0x27 || // "'"
      prev == 0x2C || // ','
      prev == 0x3B) {
    // ';'
    return true;
  }
  return false;
}

/// Tries to parse an Obsidian tag starting at [index] in [text].
TagResult? parseTag({
  required String text,
  required int index,
  required OffsetMap map,
}) {
  if (text.codeUnitAt(index) != 0x23) return null; // '#'
  if (!isTagBoundary(text, index)) return null;

  final match = _tagRegex.matchAsPrefix(text, index + 1);
  if (match == null) return null;

  var name = match.group(0)!;
  while (name.endsWith('/')) {
    name = name.substring(0, name.length - 1);
  }

  if (name.isEmpty) return null;
  if (!_nonDigitRegex.hasMatch(name)) return null;

  final end = index + 1 + name.length;
  final node = MdTag(map.toSource(index), map.toSourceEnd(end), name: name);

  return TagResult(node, end);
}
