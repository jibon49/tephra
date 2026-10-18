// © 2026 Tephra. All rights reserved.

import '../model/block_record.dart';
import '../model/heading_record.dart';

/// Obsidian-style heading normalisation for matching: removes the characters # | ^ : % [ ] \ and the sequence '%%',
/// collapses runs of whitespace to one space, trims, lower-cases.
String normalizeHeading(String text) {
  var s = text.replaceAll('%%', '');
  s = s.replaceAll(RegExp(r'[#|^:%\[\]\\]'), '');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return s.toLowerCase();
}

/// Resolves 'H1' or a chain 'H1#H2#H3' against [headings] (document order). Each next heading must come after the previous one and have
/// a deeper level than it. Returns the last matched heading, or null.
HeadingRecord? findHeading(List<HeadingRecord> headings, String headingChain) {
  final parts = headingChain
      .split('#')
      .map(normalizeHeading)
      .where((s) => s.isNotEmpty)
      .toList();
  if (parts.isEmpty) return null;

  var currentIndex = 0;
  HeadingRecord? lastMatch;

  for (var p = 0; p < parts.length; p++) {
    final targetKey = parts[p];
    HeadingRecord? match;
    var foundIndex = -1;

    for (var i = currentIndex; i < headings.length; i++) {
      final h = headings[i];
      if (h.text.toLowerCase() == targetKey ||
          normalizeHeading(h.text) == targetKey) {
        if (lastMatch == null || h.level > lastMatch.level) {
          match = h;
          foundIndex = i;
          break;
        }
      }
    }

    if (match == null) return null;
    lastMatch = match;
    currentIndex = foundIndex + 1;
  }

  return lastMatch;
}

/// Case-insensitive block id lookup ('^' stripped if present).
BlockRecord? findBlock(List<BlockRecord> blocks, String blockRef) {
  final target = (blockRef.startsWith('^') ? blockRef.substring(1) : blockRef)
      .toLowerCase();
  for (final b in blocks) {
    if (b.id.toLowerCase() == target) {
      return b;
    }
  }
  return null;
}

/// Section range of [heading]: from heading.start to the start of the next heading with level <= heading.level, or [textLength].
(int, int) sectionRange(
  List<HeadingRecord> headings,
  HeadingRecord heading,
  int textLength,
) {
  final startIndex = headings.indexOf(heading);
  var endOffset = textLength;

  if (startIndex != -1) {
    for (var i = startIndex + 1; i < headings.length; i++) {
      final next = headings[i];
      if (next.level <= heading.level) {
        endOffset = next.start;
        break;
      }
    }
  }

  return (heading.start, endOffset);
}
