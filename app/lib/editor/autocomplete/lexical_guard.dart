// © 2026 Tephra. All rights reserved.

final class LexicalState {
  const LexicalState({
    required this.inFrontmatter,
    required this.inFence,
    required this.inMathBlock,
    required this.inInlineCode,
    required this.inComment,
  });

  final bool inFrontmatter;
  final bool inFence;
  final bool inMathBlock;
  final bool inInlineCode;
  final bool inComment;

  bool get isClean =>
      !inFrontmatter && !inFence && !inMathBlock && !inInlineCode && !inComment;

  @override
  String toString() =>
      'LexicalState(fm: $inFrontmatter, fence: $inFence, math: $inMathBlock, code: $inInlineCode, comment: $inComment)';
}

/// Computes the lexical context state at [offset] in [text] without running the full AST parser.
///
/// Fast O(lines) scan suitable for running on every keystroke (< 2 ms for 5,000 lines).
LexicalState lexicalStateAt(String text, int offset) {
  final caret = offset.clamp(0, text.length);

  // 1. Find line start and lines up to caret line
  var lineStart = 0;
  final lines = <String>[];
  var caretLineIndex = 0;
  var caretLineStart = 0;

  var curr = 0;
  while (curr <= text.length) {
    if (curr == text.length || text.codeUnitAt(curr) == 0x0A /* \n */ ) {
      lines.add(text.substring(lineStart, curr));
      if (caret >= lineStart && (caret <= curr || curr == text.length)) {
        caretLineIndex = lines.length - 1;
        caretLineStart = lineStart;
        break;
      }
      lineStart = curr + 1;
    }
    curr++;
  }

  // 2. Frontmatter: line 0 is exactly --- (trailing spaces allowed) and no later line before caret is --- or ...
  var inFrontmatter = false;
  if (lines.isNotEmpty && lines[0].trimRight() == '---') {
    inFrontmatter = true;
    for (var i = 1; i <= caretLineIndex; i++) {
      final trimmed = lines[i].trim();
      if (trimmed == '---' || trimmed == '...') {
        // If the closing delimiter is on an earlier line, frontmatter has ended.
        if (i < caretLineIndex) {
          inFrontmatter = false;
          break;
        }
      }
    }
  }

  // 3. Fenced code block: toggled by line whose trimmed start is ``` or ~~~
  var inFence = false;
  var fenceChar = 0;
  var fenceLen = 0;

  for (var i = 0; i <= caretLineIndex; i++) {
    final trimmed = lines[i].trim();
    if (!inFence) {
      if (trimmed.length >= 3) {
        final c = trimmed.codeUnitAt(0);
        if (c == 0x60 /* ` */ || c == 0x7E /* ~ */ ) {
          var len = 0;
          while (len < trimmed.length && trimmed.codeUnitAt(len) == c) {
            len++;
          }
          if (len >= 3) {
            inFence = true;
            fenceChar = c;
            fenceLen = len;
          }
        }
      }
    } else {
      if (i < caretLineIndex) {
        if (trimmed.length >= fenceLen && trimmed.codeUnitAt(0) == fenceChar) {
          var len = 0;
          while (len < trimmed.length && trimmed.codeUnitAt(len) == fenceChar) {
            len++;
          }
          if (len >= fenceLen) {
            inFence = false;
          }
        }
      }
    }
  }

  // 4. Math block: toggled by a line whose trimmed text is exactly $$
  var inMathBlock = false;
  for (var i = 0; i <= caretLineIndex; i++) {
    final trimmed = lines[i].trim();
    if (!inMathBlock) {
      if (trimmed == r'$$') {
        inMathBlock = true;
      }
    } else {
      if (i < caretLineIndex && trimmed == r'$$') {
        inMathBlock = false;
      }
    }
  }

  // 5. Inline code: count of ` before caret on the caret line is odd
  var backtickCount = 0;
  for (var i = caretLineStart; i < caret; i++) {
    if (text.codeUnitAt(i) == 0x60 /* ` */ ) {
      backtickCount++;
    }
  }
  final inInlineCode = backtickCount.isOdd;

  // 6. Comment: count of %% before caret since last blank line is odd
  // Scan backwards to find the last blank line
  var scanFrom = 0;
  for (var i = caret - 1; i >= 0; i--) {
    if (text.codeUnitAt(i) == 0x0A /* \n */ ) {
      // Check if line before this newline is blank
      var prev = i - 1;
      while (prev >= 0 &&
          (text.codeUnitAt(prev) == 0x20 || text.codeUnitAt(prev) == 0x09)) {
        prev--;
      }
      if (prev < 0 || text.codeUnitAt(prev) == 0x0A) {
        scanFrom = i + 1;
        break;
      }
    }
  }

  var percentCount = 0;
  var idx = scanFrom;
  while (idx < caret - 1) {
    if (text.codeUnitAt(idx) == 0x25 /* % */ &&
        text.codeUnitAt(idx + 1) == 0x25) {
      percentCount++;
      idx += 2;
    } else {
      idx++;
    }
  }
  final inComment = percentCount.isOdd;

  return LexicalState(
    inFrontmatter: inFrontmatter,
    inFence: inFence,
    inMathBlock: inMathBlock,
    inInlineCode: inInlineCode,
    inComment: inComment,
  );
}
