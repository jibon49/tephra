// © 2026 Tephra. All rights reserved.

import '../note_models.dart';
import '../parser_options.dart';
import 'line_cursor.dart';

final class ListMarkerMatch {
  ListMarkerMatch({
    required this.ordered,
    required this.bulletChar,
    required this.delimiter,
    required this.startNumber,
    required this.markerOffset,
    required this.markerOffsetColumn,
    required this.padding,
    required this.contentColumn,
    this.task,
  });

  final bool ordered;
  final int? bulletChar;
  final int? delimiter;
  final int startNumber;
  final int markerOffset;
  final int markerOffsetColumn;
  final int padding;
  final int contentColumn;
  final TaskStatus? task;
}

final RegExp _taskRegex = RegExp(r'^\[(.)\][ \t]', unicode: true);

/// Checks if [cursor] is at a thematic break.
bool isThematicBreak(LineCursor cursor) {
  if (cursor.indent > 3) return false;
  var count = 0;
  int? marker;

  var off = cursor.nextNonSpaceOffset;
  while (off < cursor.lineEnd) {
    final cu = cursor.text.codeUnitAt(off);
    if (cu == 0x20 || cu == 0x09) {
      off++;
      continue;
    }
    if (cu == 0x2A || cu == 0x2D || cu == 0x5F) {
      // '*', '-', '_'
      if (marker == null) {
        marker = cu;
        count = 1;
      } else if (marker == cu) {
        count++;
      } else {
        return false;
      }
      off++;
    } else {
      return false;
    }
  }

  return count >= 3;
}

/// Matches a list item marker at [cursor].
///
/// Returns [ListMarkerMatch] if matched, or `null`.
ListMarkerMatch? checkListMarker(
  LineCursor cursor, {
  required bool canInterruptParagraph,
  required ParserOptions options,
}) {
  if (cursor.indent > 3) return null;
  if (cursor.blank) return null;

  // Thematic breaks take precedence over list markers (e.g. "- - -")
  if (isThematicBreak(cursor)) return null;

  final text = cursor.text;
  var off = cursor.nextNonSpaceOffset;
  final markerOffset = off;
  final markerOffsetCol = cursor.nextNonSpaceColumn;

  final firstCu = text.codeUnitAt(off);
  bool ordered = false;
  int? bullet;
  int? delim;
  var startNumber = 1;
  var markerLen = 0;

  if (firstCu == 0x2A || firstCu == 0x2B || firstCu == 0x2D) {
    // '*', '+', '-'
    bullet = firstCu;
    markerLen = 1;
    off++;
  } else if (firstCu >= 0x30 && firstCu <= 0x39) {
    // 0-9 digits (up to 9 digits)
    var numDigits = 0;
    var num = 0;
    while (off < cursor.lineEnd &&
        text.codeUnitAt(off) >= 0x30 &&
        text.codeUnitAt(off) <= 0x39) {
      numDigits++;
      if (numDigits > 9) return null;
      num = num * 10 + (text.codeUnitAt(off) - 0x30);
      off++;
    }
    if (off >= cursor.lineEnd) return null;
    final delimCu = text.codeUnitAt(off);
    if (delimCu == 0x2E || delimCu == 0x29) {
      // '.' or ')'
      ordered = true;
      delim = delimCu;
      startNumber = num;
      markerLen = numDigits + 1;
      off++;
    } else {
      return null;
    }
  } else {
    return null;
  }

  // Next char must be space, tab, or EOL
  if (off < cursor.lineEnd) {
    final nextCu = text.codeUnitAt(off);
    if (nextCu != 0x20 && nextCu != 0x09) {
      return null;
    }
  }

  // Ordered list can only interrupt paragraph if start number is 1
  if (!canInterruptParagraph && ordered && startNumber != 1) {
    return null;
  }

  // Check if rest of line is blank (empty item)
  var restOff = off;
  var spacesAfter = 0;
  var col = markerOffsetCol + markerLen;
  while (restOff < cursor.lineEnd) {
    final cu = text.codeUnitAt(restOff);
    if (cu == 0x20) {
      col++;
      spacesAfter++;
      restOff++;
    } else if (cu == 0x09) {
      final tabWidth = 4 - (col % 4);
      col += tabWidth;
      spacesAfter += tabWidth;
      restOff++;
    } else {
      break;
    }
  }

  final isRestBlank = restOff >= cursor.lineEnd;
  // Empty item cannot interrupt paragraph
  if (!canInterruptParagraph && isRestBlank) {
    return null;
  }

  int padding;
  int contentColumn;

  if (isRestBlank) {
    padding = 1;
    contentColumn = markerOffsetCol + markerLen + 1;
  } else if (spacesAfter >= 1 && spacesAfter <= 4) {
    padding = spacesAfter;
    contentColumn = markerOffsetCol + markerLen + spacesAfter;
  } else {
    padding = 1;
    contentColumn = markerOffsetCol + markerLen + 1;
  }

  // Advance cursor to content start
  cursor.advanceToNextNonSpace();
  cursor.advanceOffset(markerLen);
  cursor.advanceColumns(padding);

  // Task detection
  TaskStatus? task;
  if (options.gfm && !isRestBlank) {
    final remaining = cursor.text.substring(cursor.offset, cursor.lineEnd);
    final match = _taskRegex.firstMatch(remaining);
    if (match != null) {
      final taskChar = match.group(1)!;
      final isValidTask =
          options.obsidian ||
          taskChar == ' ' ||
          taskChar == 'x' ||
          taskChar == 'X';
      if (isValidTask) {
        final charOffset = cursor.offset + 1;
        task = TaskStatus(taskChar, charOffset);
        // Consume checkbox [c] and subsequent spaces/tabs
        cursor.advanceOffset(2 + taskChar.length); // '[' + char + ']'
        cursor.advanceToNextNonSpace();
      }
    }
  }

  return ListMarkerMatch(
    ordered: ordered,
    bulletChar: bullet,
    delimiter: delim,
    startNumber: startNumber,
    markerOffset: markerOffset,
    markerOffsetColumn: markerOffsetCol,
    padding: padding,
    contentColumn: contentColumn,
    task: task,
  );
}
