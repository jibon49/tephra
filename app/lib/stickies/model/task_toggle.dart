// © 2026 Tephra. All rights reserved.

final _taskLineRegex = RegExp(r'^(\s*(?:[-*+]|\d+[.)])\s+)\[([^\]])\](.*)$');

/// Toggles the task checkbox on 0-based [line] of [text].
/// Returns null if that line is not a task line or is out of range.
String? toggleTaskAtLine(String text, int line) {
  if (line < 0) return null;

  var currentLine = 0;
  var lineStart = 0;

  while (currentLine < line) {
    final nextNewline = text.indexOf('\n', lineStart);
    if (nextNewline == -1) return null;
    lineStart = nextNewline + 1;
    currentLine++;
  }

  if (lineStart > text.length) return null;

  final nextNewline = text.indexOf('\n', lineStart);
  final lineEnd = nextNewline == -1 ? text.length : nextNewline;
  final lineText = text.substring(lineStart, lineEnd);

  final match = _taskLineRegex.firstMatch(lineText);
  if (match == null) return null;

  final currentStatus = match.group(2)!;
  final newStatus = currentStatus == ' ' ? 'x' : ' ';

  final charOffset = lineStart + match.group(1)!.length + 1;
  return text.substring(0, charOffset) +
      newStatus +
      text.substring(charOffset + 1);
}
