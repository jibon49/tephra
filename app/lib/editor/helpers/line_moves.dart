// © 2026 Tephra. All rights reserved.

import '../line_view.dart';

(int startLine, int endLine) _affectedLines(LineView v, EditorSelection sel) {
  final start = sel.start;
  final end = sel.end;
  var last = end.line;
  if (end.line > start.line && end.col == 0) {
    last--;
  }
  return (start.line, last);
}

/// Moves affected lines up by one line.
EditPlan? moveLinesUp(LineView v, EditorSelection sel) {
  final (startLine, endLine) = _affectedLines(v, sel);
  if (startLine == 0) {
    return EditPlan(edits: const [], selection: sel);
  }

  final aboveLine = startLine - 1;
  final aboveText = v.lineAt(aboveLine);

  final blockLines = <String>[];
  for (var l = startLine; l <= endLine; l++) {
    blockLines.add(v.lineAt(l));
  }
  final blockText = blockLines.join('\n');

  final replacement = '$blockText\n$aboveText';
  final endLineText = v.lineAt(endLine);

  final edits = [
    LineEdit(
      LinePos(aboveLine, 0),
      LinePos(endLine, endLineText.length),
      replacement,
    ),
  ];

  final newSel = EditorSelection(
    LinePos(sel.base.line - 1, sel.base.col),
    LinePos(sel.extent.line - 1, sel.extent.col),
  );

  return EditPlan(edits: edits, selection: newSel);
}

/// Moves affected lines down by one line.
EditPlan? moveLinesDown(LineView v, EditorSelection sel) {
  final (startLine, endLine) = _affectedLines(v, sel);
  if (endLine >= v.lineCount - 1) {
    return EditPlan(edits: const [], selection: sel);
  }

  final belowLine = endLine + 1;
  final belowText = v.lineAt(belowLine);

  final blockLines = <String>[];
  for (var l = startLine; l <= endLine; l++) {
    blockLines.add(v.lineAt(l));
  }
  final blockText = blockLines.join('\n');

  final replacement = '$belowText\n$blockText';

  final edits = [
    LineEdit(
      LinePos(startLine, 0),
      LinePos(belowLine, belowText.length),
      replacement,
    ),
  ];

  final newSel = EditorSelection(
    LinePos(sel.base.line + 1, sel.base.col),
    LinePos(sel.extent.line + 1, sel.extent.col),
  );

  return EditPlan(edits: edits, selection: newSel);
}

/// Duplicates affected lines directly below them.
EditPlan? duplicateLines(LineView v, EditorSelection sel) {
  final (startLine, endLine) = _affectedLines(v, sel);

  final blockLines = <String>[];
  for (var l = startLine; l <= endLine; l++) {
    blockLines.add(v.lineAt(l));
  }
  final blockText = blockLines.join('\n');
  final lineCount = endLine - startLine + 1;

  final endLineText = v.lineAt(endLine);
  final edits = [
    LineEdit(
      LinePos(endLine, endLineText.length),
      LinePos(endLine, endLineText.length),
      '\n$blockText',
    ),
  ];

  final newSel = EditorSelection(
    LinePos(sel.base.line + lineCount, sel.base.col),
    LinePos(sel.extent.line + lineCount, sel.extent.col),
  );

  return EditPlan(edits: edits, selection: newSel);
}
