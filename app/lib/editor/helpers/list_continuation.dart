// © 2026 Tephra. All rights reserved.

import '../line_view.dart';
import 'list_patterns.dart';

/// Evaluates list continuation when Enter is pressed.
EditPlan? listContinuationOnEnter(
  LineView v,
  EditorSelection sel, {
  int scanLimit = 500,
}) {
  if (!sel.isCollapsed) return null;

  final caret = sel.base;
  if (caret.line < 0 || caret.line >= v.lineCount) return null;

  final line = v.lineAt(caret.line);
  final parsed = parseListLine(line);
  if (parsed == null) return null;

  if (caret.col < parsed.contentStart) return null;

  final textAfterMarker = line.substring(parsed.contentStart);
  final isEmptyItem = textAfterMarker.trim().isEmpty;

  // Empty item -> replace whole line with '' and end list
  if (isEmptyItem) {
    return EditPlan(
      edits: [
        LineEdit(LinePos(caret.line, 0), LinePos(caret.line, line.length), ''),
      ],
      selection: EditorSelection.collapsed(LinePos(caret.line, 0)),
    );
  }

  // Split line at caret
  final rawAfter = line.substring(caret.col);
  final afterTrimmed = rawAfter.trimLeft();

  final nextMarker = parsed.ordered
      ? '${parsed.number + 1}${parsed.delimiter}'
      : parsed.marker;

  final hasTask = parsed.taskChar != null;
  final taskPrefix = hasTask ? '[ ]${parsed.taskGap ?? ' '}' : '';

  final newPrefix = '${parsed.indent}$nextMarker${parsed.gap}$taskPrefix';
  final newLineText = '\n$newPrefix$afterTrimmed';

  final edits = <LineEdit>[
    LineEdit(
      LinePos(caret.line, caret.col),
      LinePos(caret.line, line.length),
      newLineText,
    ),
  ];

  // Renumbering for ordered lists
  if (parsed.ordered) {
    var expected = parsed.number + 2;
    final totalLines = v.lineCount;
    final maxLine = (caret.line + 1 + scanLimit).clamp(0, totalLines);

    for (var l = caret.line + 1; l < maxLine; l++) {
      final currentLine = v.lineAt(l);
      if (currentLine.trim().isEmpty) continue;

      final currentParsed = parseListLine(currentLine);
      if (currentParsed == null) break;

      // Skip lines with longer indent (nested items)
      if (currentParsed.indent.length > parsed.indent.length &&
          currentParsed.indent.startsWith(parsed.indent)) {
        continue;
      }

      // Check if matching ordered list item
      if (currentParsed.indent == parsed.indent &&
          currentParsed.delimiter == parsed.delimiter &&
          currentParsed.ordered &&
          currentParsed.number == expected - 1) {
        final newNumberStr = '$expected${currentParsed.delimiter}';
        final markerStart = currentParsed.indent.length;
        final markerEnd = markerStart + currentParsed.marker.length;

        edits.add(
          LineEdit(
            LinePos(l, markerStart),
            LinePos(l, markerEnd),
            newNumberStr,
          ),
        );
        expected++;
      } else {
        break;
      }
    }
  }

  final newSelection = EditorSelection.collapsed(
    LinePos(caret.line + 1, newPrefix.length),
  );

  return EditPlan(edits: edits, selection: newSelection);
}
