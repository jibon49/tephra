// © 2026 Tephra. All rights reserved.

import '../line_view.dart';

/// Tracks active closing characters inserted by auto-pair.
final class AutoPairTracker {
  final Set<LinePos> _tracked = {};

  void add(LinePos closerPos) {
    _tracked.add(closerPos);
  }

  bool contains(LinePos p) => _tracked.contains(p);

  void remove(LinePos p) {
    _tracked.remove(p);
  }

  void clear() {
    _tracked.clear();
  }

  /// Maps tracked positions through a [LineEdit].
  void onEdit(LineEdit e) {
    if (_tracked.isEmpty) return;

    final updated = <LinePos>{};
    final start = e.start;
    final end = e.end;

    // Split replacement into lines
    final repLines = e.text.split('\n');
    final int lineDelta = (repLines.length - 1) - (end.line - start.line);

    for (final p in _tracked) {
      // 1. Position strictly before edit start
      if (p.line < start.line || (p.line == start.line && p.col < start.col)) {
        updated.add(p);
        continue;
      }

      // Position is the newly inserted closer of this 2-char pair insertion
      if (start == end &&
          repLines.length == 1 &&
          repLines.first.length == 2 &&
          p.line == start.line &&
          p.col == start.col + 1) {
        updated.add(p);
        continue;
      }

      // 2. Position inside the replaced range -> remove
      if (p.line > start.line && p.line < end.line) {
        continue;
      }
      if (p.line == start.line && p.line == end.line) {
        if (p.col >= start.col && p.col < end.col) {
          continue;
        }
      } else {
        if (p.line == start.line && p.col >= start.col) {
          continue;
        }
        if (p.line == end.line && p.col < end.col) {
          continue;
        }
      }

      // 3. Position after edit
      if (p.line == end.line) {
        final int colDelta = (repLines.length == 1)
            ? (repLines.first.length - (end.col - start.col))
            : (repLines.last.length - end.col);
        final int newLine = start.line + repLines.length - 1;
        final int newCol = p.col + colDelta;
        if (newCol >= 0) {
          updated.add(LinePos(newLine, newCol));
        }
      } else if (p.line > end.line) {
        updated.add(LinePos(p.line + lineDelta, p.col));
      }
    }

    _tracked
      ..clear()
      ..addAll(updated);
  }

  /// Drops entries whose character is no longer a valid closer.
  void prune(LineView v) {
    _tracked.removeWhere((p) {
      if (p.line < 0 || p.line >= v.lineCount) return true;
      final line = v.lineAt(p.line);
      if (p.col < 0 || p.col >= line.length) return true;
      final ch = line[p.col];
      return ch != ')' &&
          ch != ']' &&
          ch != '}' &&
          ch != '"' &&
          ch != '`' &&
          ch != '*' &&
          ch != '_';
    });
  }
}

const _pairs = {
  '(': ')',
  '[': ']',
  '{': '}',
  '"': '"',
  '`': '`',
  '*': '*',
  '_': '_',
};

const _closers = {')', ']', '}', '"', '`', '*', '_'};

const _allowedNextChars = {')', ']', '}', ',', '.', ';', ':', '!', '?'};

const _allowedPrevCharsForSymmetric = {'(', '[', '{', '>', ',', ';', ':'};

/// Evaluates auto-pairing when a character [typed] is entered.
EditPlan? autoPairOnType(
  LineView v,
  EditorSelection sel,
  String typed,
  AutoPairTracker t, {
  bool disabled = false,
}) {
  if (disabled || typed.length != 1) return null;

  final c = typed;

  // R1 wrap: selection non-empty and c is one of the seven opening characters
  if (!sel.isCollapsed && _pairs.containsKey(c)) {
    final closer = _pairs[c]!;
    final edits = <LineEdit>[
      LineEdit(sel.start, sel.start, c),
      LineEdit(sel.end, sel.end, closer),
    ];

    final newStart = LinePos(sel.start.line, sel.start.col + 1);
    final newEnd = sel.start.line == sel.end.line
        ? LinePos(sel.end.line, sel.end.col + 1)
        : sel.end;

    final newSelection = sel.isReversed
        ? EditorSelection(newEnd, newStart)
        : EditorSelection(newStart, newEnd);

    return EditPlan(edits: edits, selection: newSelection);
  }

  // From here on, selection must be collapsed
  if (!sel.isCollapsed) return null;

  final caret = sel.base;
  if (caret.line < 0 || caret.line >= v.lineCount) return null;
  final line = v.lineAt(caret.line);

  final prev = caret.col > 0 && caret.col <= line.length
      ? line[caret.col - 1]
      : null;
  final next = caret.col < line.length ? line[caret.col] : null;

  // R2 skip-over
  if (_closers.contains(c) && next == c && t.contains(caret)) {
    t.remove(caret);
    return EditPlan(
      edits: const [],
      selection: EditorSelection.collapsed(LinePos(caret.line, caret.col + 1)),
    );
  }

  // R3 auto-close
  if (_pairs.containsKey(c)) {
    final isNextAllowed =
        next == null || next.trim().isEmpty || _allowedNextChars.contains(next);

    final isSymmetric = c == '"' || c == '`' || c == '*' || c == '_';
    final isPrevAllowed =
        !isSymmetric ||
        prev == null ||
        prev.trim().isEmpty ||
        _allowedPrevCharsForSymmetric.contains(prev);

    if (isNextAllowed && isPrevAllowed) {
      final closer = _pairs[c]!;
      final closerPos = LinePos(caret.line, caret.col + 1);
      t.add(closerPos);

      return EditPlan(
        edits: [LineEdit(caret, caret, '$c$closer')],
        selection: EditorSelection.collapsed(closerPos),
      );
    }
  }

  // R4 otherwise null
  return null;
}

/// Evaluates auto-pairing deletion when Backspace is pressed.
EditPlan? autoPairOnBackspace(
  LineView v,
  EditorSelection sel,
  AutoPairTracker t, {
  bool disabled = false,
}) {
  if (disabled || !sel.isCollapsed) return null;

  final caret = sel.base;
  if (caret.line < 0 || caret.line >= v.lineCount || caret.col == 0) {
    return null;
  }

  final line = v.lineAt(caret.line);
  if (caret.col > line.length) return null;

  final prev = line[caret.col - 1];
  final next = caret.col < line.length ? line[caret.col] : null;

  if (next != null && _pairs[prev] == next && t.contains(caret)) {
    t.remove(caret);
    return EditPlan(
      edits: [
        LineEdit(
          LinePos(caret.line, caret.col - 1),
          LinePos(caret.line, caret.col + 1),
          '',
        ),
      ],
      selection: EditorSelection.collapsed(LinePos(caret.line, caret.col - 1)),
    );
  }

  return null;
}
