// © 2026 Tephra. All rights reserved.

import 'dart:math';

import 'package:tephra/editor/line_view.dart';

/// Result of parsing a marked text string containing caret or selection markers.
final class ParsedMarkedText {
  const ParsedMarkedText(
    this.text,
    this.selection, {
    this.usedReturnSymbol = false,
  });

  final String text;
  final EditorSelection selection;
  final bool usedReturnSymbol;
}

/// Parses marked text with caret `|` or selection `⟦...⟧` and newline symbol `⏎`.
ParsedMarkedText parseMarked(String marked) {
  final hasReturnSymbol = marked.contains('⏎');
  final normalized = marked.replaceAll('⏎', '\n');

  final pipeIndex = normalized.indexOf('|');
  final openBracket = normalized.indexOf('⟦');
  final closeBracket = normalized.indexOf('⟧');

  if (openBracket != -1 && closeBracket != -1) {
    final first = min(openBracket, closeBracket);
    final second = max(openBracket, closeBracket);

    final sb = StringBuffer();
    sb.write(normalized.substring(0, first));
    sb.write(normalized.substring(first + 1, second));
    sb.write(normalized.substring(second + 1));
    final cleanText = sb.toString();

    final baseOffset = openBracket;
    final extentOffset = closeBracket > openBracket
        ? closeBracket - 1
        : closeBracket;

    final view = ListLineView.fromText(cleanText);
    return ParsedMarkedText(
      cleanText,
      EditorSelection(posOf(view, baseOffset), posOf(view, extentOffset)),
      usedReturnSymbol: hasReturnSymbol,
    );
  } else if (pipeIndex != -1) {
    final cleanText =
        '${normalized.substring(0, pipeIndex)}${normalized.substring(pipeIndex + 1)}';
    final view = ListLineView.fromText(cleanText);
    final pos = posOf(view, pipeIndex);
    return ParsedMarkedText(
      cleanText,
      EditorSelection.collapsed(pos),
      usedReturnSymbol: hasReturnSymbol,
    );
  } else {
    return ParsedMarkedText(
      normalized,
      const EditorSelection.collapsed(LinePos(0, 0)),
      usedReturnSymbol: hasReturnSymbol,
    );
  }
}

/// Renders clean [text] and [selection] into marked text notation.
String renderMarked(
  String text,
  EditorSelection selection, {
  bool useReturnSymbol = false,
}) {
  final view = ListLineView.fromText(text);
  final baseOffset = offsetOf(view, selection.base);
  final extentOffset = offsetOf(view, selection.extent);

  final String markedWithCarets;
  if (selection.isCollapsed) {
    markedWithCarets =
        '${text.substring(0, baseOffset)}|${text.substring(baseOffset)}';
  } else if (baseOffset <= extentOffset) {
    markedWithCarets =
        '${text.substring(0, baseOffset)}⟦${text.substring(baseOffset, extentOffset)}⟧${text.substring(extentOffset)}';
  } else {
    markedWithCarets =
        '${text.substring(0, extentOffset)}⟧${text.substring(extentOffset, baseOffset)}⟦${text.substring(baseOffset)}';
  }

  if (useReturnSymbol) {
    return markedWithCarets.replaceAll('\n', '⏎');
  }
  return markedWithCarets;
}

/// Applies an [EditPlan] to [marked] text and returns the resulting marked text.
String? applyPlan(String marked, EditPlan? plan) {
  if (plan == null) return null;
  final parsed = parseMarked(marked);
  var currentText = parsed.text;

  if (plan.edits.isNotEmpty) {
    final view = ListLineView.fromText(currentText);
    // Sort edits descending by start offset to apply back-to-front
    final sortedEdits = List<LineEdit>.from(plan.edits)
      ..sort((a, b) {
        final aOffset = offsetOf(view, a.start);
        final bOffset = offsetOf(view, b.start);
        return bOffset.compareTo(aOffset);
      });

    for (final edit in sortedEdits) {
      final lineView = ListLineView.fromText(currentText);
      final start = offsetOf(lineView, edit.start);
      final end = offsetOf(lineView, edit.end);
      currentText =
          currentText.substring(0, start) +
          edit.text +
          currentText.substring(end);
    }
  }

  return renderMarked(
    currentText,
    plan.selection,
    useReturnSymbol: parsed.usedReturnSymbol,
  );
}
