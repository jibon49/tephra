// © 2026 Tephra. All rights reserved.

import 'dart:math';

import '../line_view.dart';
import 'list_patterns.dart';

(int startLine, int endLine) _affectedLines(LineView v, EditorSelection sel) {
  final start = sel.start;
  final end = sel.end;
  var last = end.line;
  if (end.line > start.line && end.col == 0) {
    last--;
  }
  return (start.line, last);
}

/// Toggles bullet list formatting on the affected lines.
EditPlan? toggleBulletList(LineView v, EditorSelection sel) {
  final (startLine, endLine) = _affectedLines(v, sel);
  final isMulti = endLine > startLine;

  final linesInfo = <int, (String line, ListLine? parsed)>{};
  var allBullets = true;
  var nonBlankCount = 0;

  for (var l = startLine; l <= endLine; l++) {
    final text = v.lineAt(l);
    final isBlank = text.trim().isEmpty;
    if (isBlank && isMulti) continue;

    nonBlankCount++;
    final parsed = parseListLine(text);
    linesInfo[l] = (text, parsed);
    if (parsed == null || parsed.ordered) {
      allBullets = false;
    }
  }

  if (nonBlankCount == 0) return null;

  final edits = <LineEdit>[];
  final colDelta = <int, int>{};

  if (allBullets) {
    // Remove bullet marker, gap, and optional task box
    for (final entry in linesInfo.entries) {
      final l = entry.key;
      final parsed = entry.value.$2!;
      final prefixEnd = parsed.contentStart;
      final indentLen = parsed.indent.length;

      edits.add(LineEdit(LinePos(l, indentLen), LinePos(l, prefixEnd), ''));
      colDelta[l] = -(prefixEnd - indentLen);
    }
  } else {
    // Convert or add bullet
    for (final entry in linesInfo.entries) {
      final l = entry.key;
      final parsed = entry.value.$2;

      if (parsed == null) {
        final text = entry.value.$1;
        var indentLen = 0;
        while (indentLen < text.length &&
            (text[indentLen] == ' ' || text[indentLen] == '\t')) {
          indentLen++;
        }
        edits.add(LineEdit(LinePos(l, indentLen), LinePos(l, indentLen), '- '));
        colDelta[l] = 2;
      } else if (parsed.ordered) {
        final markerStart = parsed.indent.length;
        final markerEnd =
            markerStart + parsed.marker.length + parsed.gap.length;
        edits.add(
          LineEdit(LinePos(l, markerStart), LinePos(l, markerEnd), '- '),
        );
        colDelta[l] = 2 - (markerEnd - markerStart);
      }
    }
  }

  LinePos adjust(LinePos p) {
    if (!sel.isCollapsed && p == sel.start && p.col == 0) {
      return p;
    }
    final delta = colDelta[p.line] ?? 0;
    if (delta != 0) {
      final parsed = linesInfo[p.line]?.$2;
      final indentLen = parsed?.indent.length ?? 0;
      if (delta < 0 && p.col < indentLen - delta) {
        return LinePos(p.line, indentLen);
      }
      return LinePos(p.line, max(0, p.col + delta));
    }
    return p;
  }

  final newSel = sel.isReversed
      ? EditorSelection(adjust(sel.extent), adjust(sel.base))
      : EditorSelection(adjust(sel.base), adjust(sel.extent));

  return EditPlan(edits: edits, selection: newSel);
}

/// Toggles numbered list formatting on the affected lines.
EditPlan? toggleNumberedList(LineView v, EditorSelection sel) {
  final (startLine, endLine) = _affectedLines(v, sel);
  final isMulti = endLine > startLine;

  final linesInfo = <int, (String line, ListLine? parsed)>{};
  var allOrdered = true;
  var nonBlankCount = 0;

  for (var l = startLine; l <= endLine; l++) {
    final text = v.lineAt(l);
    final isBlank = text.trim().isEmpty;
    if (isBlank && isMulti) continue;

    nonBlankCount++;
    final parsed = parseListLine(text);
    linesInfo[l] = (text, parsed);
    if (parsed == null || !parsed.ordered) {
      allOrdered = false;
    }
  }

  if (nonBlankCount == 0) return null;

  final edits = <LineEdit>[];
  final colDelta = <int, int>{};

  if (allOrdered) {
    // Remove ordered marker and gap
    for (final entry in linesInfo.entries) {
      final l = entry.key;
      final parsed = entry.value.$2!;
      final prefixEnd = parsed.contentStart;
      final indentLen = parsed.indent.length;

      edits.add(LineEdit(LinePos(l, indentLen), LinePos(l, prefixEnd), ''));
      colDelta[l] = -(prefixEnd - indentLen);
    }
  } else {
    // Number sequentially starting from 1
    var num = 1;
    for (final entry in linesInfo.entries) {
      final l = entry.key;
      final parsed = entry.value.$2;
      final rep = '$num. ';

      if (parsed == null) {
        final text = entry.value.$1;
        var indentLen = 0;
        while (indentLen < text.length &&
            (text[indentLen] == ' ' || text[indentLen] == '\t')) {
          indentLen++;
        }
        edits.add(LineEdit(LinePos(l, indentLen), LinePos(l, indentLen), rep));
        colDelta[l] = rep.length;
      } else {
        final markerStart = parsed.indent.length;
        final markerEnd =
            markerStart + parsed.marker.length + parsed.gap.length;
        edits.add(
          LineEdit(LinePos(l, markerStart), LinePos(l, markerEnd), rep),
        );
        colDelta[l] = rep.length - (markerEnd - markerStart);
      }
      num++;
    }
  }

  LinePos adjust(LinePos p) {
    if (!sel.isCollapsed && p == sel.start && p.col == 0) {
      return p;
    }
    final delta = colDelta[p.line] ?? 0;
    if (delta != 0) {
      return LinePos(p.line, max(0, p.col + delta));
    }
    return p;
  }

  final newSel = sel.isReversed
      ? EditorSelection(adjust(sel.extent), adjust(sel.base))
      : EditorSelection(adjust(sel.base), adjust(sel.extent));

  return EditPlan(edits: edits, selection: newSel);
}

/// Toggles block quote formatting (`> `) on affected lines.
EditPlan? toggleQuote(LineView v, EditorSelection sel) {
  final (startLine, endLine) = _affectedLines(v, sel);
  final isMulti = endLine > startLine;

  final lines = <int, String>{};
  var allQuotes = true;
  var count = 0;

  for (var l = startLine; l <= endLine; l++) {
    final text = v.lineAt(l);
    if (text.isEmpty && isMulti) {
      lines[l] = text;
      continue;
    }
    count++;
    lines[l] = text;
    final trimmed = text.trimLeft();
    if (!trimmed.startsWith('>')) {
      allQuotes = false;
    }
  }

  if (count == 0 && lines.isEmpty) return null;

  final edits = <LineEdit>[];
  final colDelta = <int, int>{};

  if (allQuotes && count > 0) {
    // Remove one > or >
    for (final entry in lines.entries) {
      final l = entry.key;
      final text = entry.value;
      if (text.isEmpty) continue;

      var indent = 0;
      while (indent < text.length &&
          (text[indent] == ' ' || text[indent] == '\t')) {
        indent++;
      }
      if (indent < text.length && text[indent] == '>') {
        final removeLen = (indent + 1 < text.length && text[indent + 1] == ' ')
            ? 2
            : 1;
        edits.add(
          LineEdit(LinePos(l, indent), LinePos(l, indent + removeLen), ''),
        );
        colDelta[l] = -removeLen;
      }
    }
  } else {
    // Insert >  at column 0
    for (final entry in lines.entries) {
      final l = entry.key;
      final text = entry.value;
      final rep = text.isEmpty && isMulti ? '>' : '> ';
      edits.add(LineEdit(LinePos(l, 0), LinePos(l, 0), rep));
      colDelta[l] = rep.length;
    }
  }

  LinePos adjust(LinePos p) {
    if (!sel.isCollapsed && p == sel.start && p.col == 0) {
      return p;
    }
    final delta = colDelta[p.line] ?? 0;
    if (delta != 0) {
      return LinePos(p.line, max(0, p.col + delta));
    }
    return p;
  }

  final newSel = sel.isReversed
      ? EditorSelection(adjust(sel.extent), adjust(sel.base))
      : EditorSelection(adjust(sel.base), adjust(sel.extent));

  return EditPlan(edits: edits, selection: newSel);
}

final _headingRegex = RegExp(r'^(#{1,6}) ');

/// Cycles heading level `#` through `######` on the caret line.
EditPlan? cycleHeading(LineView v, EditorSelection sel) {
  final lineIndex = sel.base.line;
  if (lineIndex < 0 || lineIndex >= v.lineCount) return null;

  final line = v.lineAt(lineIndex);
  final match = _headingRegex.firstMatch(line);

  final List<LineEdit> edits;
  final int delta;

  if (match == null) {
    // No heading -> insert '# '
    edits = [LineEdit(LinePos(lineIndex, 0), LinePos(lineIndex, 0), '# ')];
    delta = 2;
  } else {
    final hashes = match.group(1)!;
    if (hashes.length < 6) {
      // Add one hash
      edits = [LineEdit(LinePos(lineIndex, 0), LinePos(lineIndex, 0), '#')];
      delta = 1;
    } else {
      // Remove '###### '
      edits = [
        LineEdit(LinePos(lineIndex, 0), LinePos(lineIndex, match.end), ''),
      ];
      delta = -match.end;
    }
  }

  LinePos adjust(LinePos p) {
    if (p.line == lineIndex) {
      return LinePos(p.line, max(0, p.col + delta));
    }
    return p;
  }

  final newSel = sel.isReversed
      ? EditorSelection(adjust(sel.extent), adjust(sel.base))
      : EditorSelection(adjust(sel.base), adjust(sel.extent));

  return EditPlan(edits: edits, selection: newSel);
}

/// Toggles task status on the affected lines (Ctrl+Enter).
EditPlan? toggleTaskStatus(LineView v, EditorSelection sel) {
  final (startLine, endLine) = _affectedLines(v, sel);
  final isMulti = endLine > startLine;

  final edits = <LineEdit>[];
  final colDelta = <int, int>{};

  for (var l = startLine; l <= endLine; l++) {
    final text = v.lineAt(l);
    if (text.isEmpty && isMulti) continue;

    if (text.isEmpty && !isMulti) {
      // Single blank line gets '- [ ] '
      edits.add(LineEdit(LinePos(l, 0), LinePos(l, 0), '- [ ] '));
      colDelta[l] = 6;
      continue;
    }

    final parsed = parseListLine(text);

    if (parsed == null) {
      // Not a list line -> insert '- [ ] ' after indentation
      var indent = 0;
      while (indent < text.length &&
          (text[indent] == ' ' || text[indent] == '\t')) {
        indent++;
      }
      edits.add(LineEdit(LinePos(l, indent), LinePos(l, indent), '- [ ] '));
      colDelta[l] = 6;
    } else if (parsed.taskChar == null) {
      // List line without task box -> insert '[ ] ' after marker + gap
      final insertPos =
          parsed.indent.length + parsed.marker.length + parsed.gap.length;
      edits.add(LineEdit(LinePos(l, insertPos), LinePos(l, insertPos), '[ ] '));
      colDelta[l] = 4;
    } else {
      // Task line -> toggle status
      final taskChar = parsed.taskChar!;
      final newChar = (taskChar == 'x' || taskChar == 'X') ? ' ' : 'x';
      final charPos =
          parsed.indent.length + parsed.marker.length + parsed.gap.length + 1;
      edits.add(
        LineEdit(LinePos(l, charPos), LinePos(l, charPos + 1), newChar),
      );
      // Delta is 0 because 1 char replaced by 1 char
    }
  }

  LinePos adjust(LinePos p) {
    if (!sel.isCollapsed && p == sel.start && p.col == 0) {
      return p;
    }
    final delta = colDelta[p.line] ?? 0;
    if (delta != 0) {
      return LinePos(p.line, max(0, p.col + delta));
    }
    return p;
  }

  final newSel = sel.isReversed
      ? EditorSelection(adjust(sel.extent), adjust(sel.base))
      : EditorSelection(adjust(sel.base), adjust(sel.extent));

  return EditPlan(edits: edits, selection: newSel);
}
