// © 2026 Tephra. All rights reserved.

import 'dart:math';

import '../editor_options.dart';
import '../line_view.dart';
import 'list_patterns.dart';

/// Evaluates indentation when Tab or Shift+Tab is pressed.
EditPlan? indentOnTab(
  LineView v,
  EditorSelection sel,
  EditorOptions o, {
  required bool shift,
  bool forceLine = false,
}) {
  final start = sel.start;
  final end = sel.end;

  var lastLine = end.line;
  if (end.line > start.line && end.col == 0) {
    lastLine--;
  }

  final selectionSpansLines = sel.end.line > sel.start.line;
  final isMultiLine = lastLine > start.line;
  final caretLineText = v.lineAt(start.line);
  final isList = parseListLine(caretLineText) != null;

  if (!shift) {
    // TAB
    final shouldIndentLines =
        isMultiLine || selectionSpansLines || isList || forceLine;

    if (shouldIndentLines) {
      final edits = <LineEdit>[];
      final unit = o.indentUnit;

      for (var l = start.line; l <= lastLine; l++) {
        final text = v.lineAt(l);
        if (text.isEmpty && isMultiLine) continue;

        edits.add(LineEdit(LinePos(l, 0), LinePos(l, 0), unit));
      }

      LinePos shiftPos(LinePos p) {
        if (p.line >= start.line && p.line <= lastLine) {
          final text = v.lineAt(p.line);
          if (text.isEmpty && isMultiLine) return p;
          if (p.col >= 1) {
            return LinePos(p.line, p.col + unit.length);
          }
        }
        return p;
      }

      final newSelection = sel.isReversed
          ? EditorSelection(shiftPos(sel.extent), shiftPos(sel.base))
          : EditorSelection(shiftPos(sel.base), shiftPos(sel.extent));

      return EditPlan(edits: edits, selection: newSelection);
    } else {
      // Plain text caret or single-line selection: replace with indentUnit
      final unit = o.indentUnit;
      final edits = [LineEdit(start, end, unit)];
      final newCaret = LinePos(start.line, start.col + unit.length);
      return EditPlan(
        edits: edits,
        selection: EditorSelection.collapsed(newCaret),
      );
    }
  } else {
    // SHIFT+TAB
    final edits = <LineEdit>[];
    final removedPerLine = <int, int>{};

    for (var l = start.line; l <= lastLine; l++) {
      final text = v.lineAt(l);
      if (text.startsWith('\t')) {
        edits.add(LineEdit(LinePos(l, 0), LinePos(l, 1), ''));
        removedPerLine[l] = 1;
      } else {
        var spaces = 0;
        while (spaces < text.length && text[spaces] == ' ') {
          spaces++;
        }
        final removeCount = min(spaces, o.tabSize);
        if (removeCount > 0) {
          edits.add(LineEdit(LinePos(l, 0), LinePos(l, removeCount), ''));
          removedPerLine[l] = removeCount;
        }
      }
    }

    LinePos unshiftPos(LinePos p) {
      final removed = removedPerLine[p.line] ?? 0;
      if (removed > 0) {
        return LinePos(p.line, max(0, p.col - removed));
      }
      return p;
    }

    final newSelection = sel.isReversed
        ? EditorSelection(unshiftPos(sel.extent), unshiftPos(sel.base))
        : EditorSelection(unshiftPos(sel.base), unshiftPos(sel.extent));

    return EditPlan(edits: edits, selection: newSelection);
  }
}
