// © 2026 Tephra. All rights reserved.

import 'package:tephra_index/tephra_index.dart';
import 'package:tephra_markdown/tephra_markdown.dart';

/// Range of the section of headings[index]: heading start → start of the next heading with level <= its level, or textLength.
(int, int) sectionOf(List<MdHeading> headings, int index, int textLength) {
  if (index < 0 || index >= headings.length) {
    throw RangeError.index(index, headings, 'index');
  }
  final h = headings[index];
  final start = h.start;
  for (var i = index + 1; i < headings.length; i++) {
    if (headings[i].level <= h.level) {
      return (start, headings[i].start);
    }
  }
  return (start, textLength);
}

/// Edits that move section [index] so it starts at [insertAt] (a heading start or text.length).
///
/// Returns null when insertAt is inside the section (including its start and end) — the move is not allowed.
List<TextEdit>? moveSectionEdits(
  String text,
  List<MdHeading> headings,
  int index,
  int insertAt,
) {
  if (index < 0 || index >= headings.length) return null;
  final (s, e) = sectionOf(headings, index, text.length);

  // insertAt cannot be inside the section (including start and end).
  if (insertAt >= s && insertAt <= e) {
    return null;
  }
  if (insertAt < 0 || insertAt > text.length) {
    return null;
  }

  var moved = text.substring(s, e);
  var delStart = s;
  if (!moved.endsWith('\n')) {
    moved += '\n';
    if (s > 0 && text[s - 1] == '\n' && (s == 1 || text[s - 2] == '\n')) {
      delStart = s - 1;
    }
  }

  if (insertAt == delStart) {
    return null;
  }

  var movedToInsert = moved;
  if (insertAt == text.length && !text.endsWith('\n')) {
    movedToInsert = '\n$moved';
  }

  return [
    TextEdit(delStart, e, ''),
    TextEdit(insertAt, insertAt, movedToInsert),
  ];
}
