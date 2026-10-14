// © 2026 Tephra. All rights reserved.

import '../line_view.dart';
import 'word_at.dart';

enum InlineFormat {
  bold,
  italic,
  strikethrough,
  highlight,
  code;

  String get marker => switch (this) {
    InlineFormat.bold => '**',
    InlineFormat.italic => '*',
    InlineFormat.strikethrough => '~~',
    InlineFormat.highlight => '==',
    InlineFormat.code => '`',
  };

  String get char => marker[0];
}

/// Evaluates inline formatting toggle for [f].
EditPlan? toggleInlineFormat(LineView v, EditorSelection sel, InlineFormat f) {
  final marker = f.marker;
  final markerChar = f.char;

  if (sel.isCollapsed) {
    // 1. Empty selection -> word around caret
    final caret = sel.base;
    if (caret.line < 0 || caret.line >= v.lineCount) return null;
    final line = v.lineAt(caret.line);

    final range = wordRangeAt(line, caret.col);
    if (range == null) {
      // No word: insert marker marker at caret
      return EditPlan(
        edits: [LineEdit(caret, caret, '$marker$marker')],
        selection: EditorSelection.collapsed(
          LinePos(caret.line, caret.col + marker.length),
        ),
      );
    }

    final wordStartCol = range.$1;
    final wordEndCol = range.$2;

    // Check surrounding runs
    var runBefore = 0;
    while (wordStartCol - 1 - runBefore >= 0 &&
        line[wordStartCol - 1 - runBefore] == markerChar) {
      runBefore++;
    }

    var runAfter = 0;
    while (wordEndCol + runAfter < line.length &&
        line[wordEndCol + runAfter] == markerChar) {
      runAfter++;
    }

    final minRun = runBefore < runAfter ? runBefore : runAfter;
    final unwrapLen = _unwrapLength(f, minRun);

    if (unwrapLen > 0) {
      // Unwrap outer markers
      final edits = <LineEdit>[
        LineEdit(
          LinePos(caret.line, wordStartCol - unwrapLen),
          LinePos(caret.line, wordStartCol),
          '',
        ),
        LineEdit(
          LinePos(caret.line, wordEndCol),
          LinePos(caret.line, wordEndCol + unwrapLen),
          '',
        ),
      ];
      final newCaret = LinePos(caret.line, caret.col - unwrapLen);
      return EditPlan(
        edits: edits,
        selection: EditorSelection.collapsed(newCaret),
      );
    } else {
      // Wrap word
      final edits = <LineEdit>[
        LineEdit(
          LinePos(caret.line, wordStartCol),
          LinePos(caret.line, wordStartCol),
          marker,
        ),
        LineEdit(
          LinePos(caret.line, wordEndCol),
          LinePos(caret.line, wordEndCol),
          marker,
        ),
      ];
      final newCaret = LinePos(caret.line, caret.col + marker.length);
      return EditPlan(
        edits: edits,
        selection: EditorSelection.collapsed(newCaret),
      );
    }
  } else {
    // 2. Non-empty selection
    final start = sel.start;
    final end = sel.end;
    final isSingleLine = start.line == end.line;

    if (isSingleLine) {
      final line = v.lineAt(start.line);

      // Check inner form: selection itself starts and ends with markers
      final selectedText = line.substring(start.col, end.col);
      final innerUnwrap = _innerUnwrapLength(f, selectedText);
      if (innerUnwrap > 0) {
        final newText = selectedText.substring(
          innerUnwrap,
          selectedText.length - innerUnwrap,
        );
        final edits = [LineEdit(start, end, newText)];
        final newStart = start;
        final newEnd = LinePos(start.line, start.col + newText.length);
        final newSel = sel.isReversed
            ? EditorSelection(newEnd, newStart)
            : EditorSelection(newStart, newEnd);
        return EditPlan(edits: edits, selection: newSel);
      }

      // Check outer surrounding markers
      var runBefore = 0;
      while (start.col - 1 - runBefore >= 0 &&
          line[start.col - 1 - runBefore] == markerChar) {
        runBefore++;
      }

      var runAfter = 0;
      while (end.col + runAfter < line.length &&
          line[end.col + runAfter] == markerChar) {
        runAfter++;
      }

      final minRun = runBefore < runAfter ? runBefore : runAfter;
      final unwrapLen = _unwrapLength(f, minRun);

      if (unwrapLen > 0) {
        final edits = <LineEdit>[
          LineEdit(LinePos(start.line, start.col - unwrapLen), start, ''),
          LineEdit(end, LinePos(end.line, end.col + unwrapLen), ''),
        ];
        final newStart = LinePos(start.line, start.col - unwrapLen);
        final newEnd = LinePos(end.line, end.col - unwrapLen);
        final newSel = sel.isReversed
            ? EditorSelection(newEnd, newStart)
            : EditorSelection(newStart, newEnd);
        return EditPlan(edits: edits, selection: newSel);
      }
    }

    // Default for non-empty selection: wrap
    final edits = <LineEdit>[
      LineEdit(start, start, marker),
      LineEdit(end, end, marker),
    ];

    final newStart = LinePos(start.line, start.col + marker.length);
    final newEnd = (start.line == end.line)
        ? LinePos(end.line, end.col + marker.length)
        : end;

    final newSel = sel.isReversed
        ? EditorSelection(newEnd, newStart)
        : EditorSelection(newStart, newEnd);

    return EditPlan(edits: edits, selection: newSel);
  }
}

int _unwrapLength(InlineFormat f, int minRun) {
  switch (f) {
    case InlineFormat.bold:
      return minRun >= 2 ? 2 : 0;
    case InlineFormat.italic:
      return (minRun == 1 || minRun >= 3) ? 1 : 0;
    case InlineFormat.strikethrough:
    case InlineFormat.highlight:
      return minRun >= 2 ? 2 : 0;
    case InlineFormat.code:
      return minRun >= 1 ? 1 : 0;
  }
}

int _innerUnwrapLength(InlineFormat f, String text) {
  final marker = f.marker;
  final markerChar = f.char;

  if (text.length < marker.length * 2) return 0;

  var lead = 0;
  while (lead < text.length && text[lead] == markerChar) {
    lead++;
  }

  var trail = 0;
  while (trail < text.length && text[text.length - 1 - trail] == markerChar) {
    trail++;
  }

  final minRun = lead < trail ? lead : trail;
  return _unwrapLength(f, minRun);
}

final _urlRegex = RegExp(r'^https?://\S+$');

/// Evaluates markdown link insertion for the current selection.
EditPlan? insertLink(LineView v, EditorSelection sel) {
  if (sel.isCollapsed) {
    final caret = sel.base;
    return EditPlan(
      edits: [LineEdit(caret, caret, '[]()')],
      selection: EditorSelection.collapsed(LinePos(caret.line, caret.col + 1)),
    );
  }

  final start = sel.start;
  final end = sel.end;

  if (start.line == end.line) {
    final line = v.lineAt(start.line);
    final selectedText = line.substring(start.col, end.col);

    if (_urlRegex.hasMatch(selectedText)) {
      final replacement = '[]($selectedText)';
      return EditPlan(
        edits: [LineEdit(start, end, replacement)],
        selection: EditorSelection.collapsed(
          LinePos(start.line, start.col + 1),
        ),
      );
    } else {
      final replacement = '[$selectedText]()';
      return EditPlan(
        edits: [LineEdit(start, end, replacement)],
        selection: EditorSelection.collapsed(
          LinePos(start.line, start.col + replacement.length - 1),
        ),
      );
    }
  } else {
    // Multi-line selection: wrap with [ at start and ]() at end
    final edits = [LineEdit(start, start, '['), LineEdit(end, end, ']()')];
    return EditPlan(
      edits: edits,
      selection: EditorSelection.collapsed(LinePos(end.line, end.col + 2)),
    );
  }
}
