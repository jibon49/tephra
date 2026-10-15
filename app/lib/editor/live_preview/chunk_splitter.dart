// © 2026 Tephra. All rights reserved.

/// Range of a chunk [start, end) within the document.
final class ChunkSpan {
  const ChunkSpan(this.start, this.end);

  final int start;
  final int end;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChunkSpan && start == other.start && end == other.end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'ChunkSpan($start..$end)';
}

/// Splits [text] into chunks that tile the text exactly.
///
/// A new chunk starts at the first non-blank line after one or more blank lines
/// unless kept joined by frontmatter, code fences, math blocks, open comments,
/// indented continuation, or list items.
List<ChunkSpan> splitChunks(String text) {
  if (text.isEmpty) {
    return const [ChunkSpan(0, 0)];
  }

  final chunks = <ChunkSpan>[];
  var chunkStart = 0;
  var hadBlankLines = false;
  var inFrontmatter = false;
  var inCodeFence = false;
  var fenceChar = '';
  var fenceLen = 0;
  var inMathBlock = false;
  var inComment = false;

  bool? chunkStartsWithListMarker;
  var lineIndex = 0;
  var lineStart = 0;

  while (lineStart < text.length) {
    var lineEnd = text.indexOf('\n', lineStart);
    final nextLineStart = (lineEnd == -1) ? text.length : lineEnd + 1;
    if (lineEnd == -1) lineEnd = text.length;

    // Check line content without trailing \r
    var contentEnd = lineEnd;
    if (contentEnd > lineStart && text.codeUnitAt(contentEnd - 1) == 13) {
      contentEnd--;
    }

    final isBlank = _isLineBlank(text, lineStart, contentEnd);

    if (lineIndex == 0) {
      // Frontmatter opens on line 0 if line content is '---'
      if (_isExactMatch(text, lineStart, contentEnd, '---')) {
        inFrontmatter = true;
      }
    }

    if (isBlank) {
      hadBlankLines = true;
    } else {
      final isCurrentList = _isListMarker(text, lineStart, contentEnd);
      chunkStartsWithListMarker ??= isCurrentList;

      if (hadBlankLines) {
        // Check if kept joined
        final keepJoined =
            // (a) Scanner state
            inFrontmatter ||
            inCodeFence ||
            inMathBlock ||
            inComment ||
            // (b) Indented continuation or indented code
            _isIndented(text, lineStart, contentEnd) ||
            // (c) List item continuation
            (isCurrentList && (chunkStartsWithListMarker == true)) ||
            // (d) Link reference definition continuation
            _isLinkReferenceDefinition(text, lineStart, contentEnd);

        if (!keepJoined) {
          // Emit previous chunk ending at current lineStart
          chunks.add(ChunkSpan(chunkStart, lineStart));
          chunkStart = lineStart;
          chunkStartsWithListMarker = isCurrentList;
        }
        hadBlankLines = false;
      }

      // Update block states based on current non-blank line
      if (inFrontmatter && lineIndex > 0) {
        if (_isExactMatch(text, lineStart, contentEnd, '---') ||
            _isExactMatch(text, lineStart, contentEnd, '...')) {
          inFrontmatter = false;
        }
      }

      if (!inFrontmatter) {
        // Code fence handling
        if (!inCodeFence) {
          final fence = _detectOpeningFence(text, lineStart, contentEnd);
          if (fence != null) {
            inCodeFence = true;
            fenceChar = fence.$1;
            fenceLen = fence.$2;
          }
        } else {
          if (_isClosingFence(
            text,
            lineStart,
            contentEnd,
            fenceChar,
            fenceLen,
          )) {
            inCodeFence = false;
          }
        }

        // Math block handling
        if (!inCodeFence) {
          if (!inMathBlock) {
            if (_isOpenMathBlock(text, lineStart, contentEnd)) {
              inMathBlock = true;
            }
          } else {
            if (_isCloseMathBlock(text, lineStart, contentEnd)) {
              inMathBlock = false;
            }
          }
        }

        // Comment handling (odd number of %% toggles state)
        if (!inCodeFence) {
          final count = _countPercentPercent(text, lineStart, contentEnd);
          if (count % 2 == 1) {
            inComment = !inComment;
          }
        }
      }
    }

    lineIndex++;
    lineStart = nextLineStart;
  }

  // Final chunk
  chunks.add(ChunkSpan(chunkStart, text.length));
  return chunks;
}

bool _isLineBlank(String text, int start, int end) {
  for (var i = start; i < end; i++) {
    final c = text.codeUnitAt(i);
    if (c != 32 && c != 9) return false;
  }
  return true;
}

bool _isIndented(String text, int start, int end) {
  if (start >= end) return false;
  final c = text.codeUnitAt(start);
  return c == 32 || c == 9;
}

bool _isExactMatch(String text, int start, int end, String pattern) {
  // Trim trailing whitespace for delimiter checks like '---'
  var e = end;
  while (e > start &&
      (text.codeUnitAt(e - 1) == 32 || text.codeUnitAt(e - 1) == 9)) {
    e--;
  }
  if (e - start != pattern.length) return false;
  for (var i = 0; i < pattern.length; i++) {
    if (text.codeUnitAt(start + i) != pattern.codeUnitAt(i)) return false;
  }
  return true;
}

(String, int)? _detectOpeningFence(String text, int start, int end) {
  if (start >= end) return null;
  final first = text.codeUnitAt(start);
  if (first != 32 && first != 96 && first != 126) return null;

  var i = start;
  var spaces = 0;
  while (i < end && spaces < 4 && (text.codeUnitAt(i) == 32)) {
    spaces++;
    i++;
  }
  if (spaces >= 4 || i >= end) return null;

  final c = text.codeUnitAt(i);
  if (c != 96 && c != 126) return null; // '`' or '~'
  final charStr = String.fromCharCode(c);

  var count = 0;
  while (i < end && text.codeUnitAt(i) == c) {
    count++;
    i++;
  }
  if (count >= 3) {
    return (charStr, count);
  }
  return null;
}

bool _isClosingFence(
  String text,
  int start,
  int end,
  String fenceChar,
  int fenceLen,
) {
  var i = start;
  var spaces = 0;
  while (i < end && spaces < 4 && text.codeUnitAt(i) == 32) {
    spaces++;
    i++;
  }
  if (spaces >= 4 || i >= end) return false;

  final c = fenceChar.codeUnitAt(0);
  var count = 0;
  while (i < end && text.codeUnitAt(i) == c) {
    count++;
    i++;
  }
  if (count < fenceLen) return false;

  // Trailing characters must be whitespace
  while (i < end) {
    final ch = text.codeUnitAt(i);
    if (ch != 32 && ch != 9) return false;
    i++;
  }
  return true;
}

bool _isOpenMathBlock(String text, int start, int end) {
  if (start >= end) return false;
  final first = text.codeUnitAt(start);
  if (first != 32 && first != 9 && first != 36) return false;

  var s = start;
  while (s < end && (text.codeUnitAt(s) == 32 || text.codeUnitAt(s) == 9)) {
    s++;
  }
  var e = end;
  while (e > s &&
      (text.codeUnitAt(e - 1) == 32 || text.codeUnitAt(e - 1) == 9)) {
    e--;
  }
  final len = e - s;
  if (len < 2) return false;
  if (text.codeUnitAt(s) == 36 && text.codeUnitAt(s + 1) == 36) {
    if (len == 2) return true; // Just $$
    if (text.codeUnitAt(e - 1) == 36 && text.codeUnitAt(e - 2) == 36) {
      return false; // Inline/single-line $$...$$
    }
    return true;
  }
  return false;
}

bool _isCloseMathBlock(String text, int start, int end) {
  for (var i = start; i < end - 1; i++) {
    if (text.codeUnitAt(i) == 36 && text.codeUnitAt(i + 1) == 36) {
      return true;
    }
  }
  return false;
}

int _countPercentPercent(String text, int start, int end) {
  var count = 0;
  var i = start;
  while (i < end - 1) {
    if (text.codeUnitAt(i) == 37 && text.codeUnitAt(i + 1) == 37) {
      count++;
      i += 2;
    } else {
      i++;
    }
  }
  return count;
}

bool _isListMarker(String text, int start, int end) {
  if (start >= end) return false;
  final first = text.codeUnitAt(start);
  if (first != 32 &&
      first != 9 &&
      first != 45 &&
      first != 42 &&
      first != 43 &&
      (first < 48 || first > 57)) {
    return false;
  }

  var i = start;
  while (i < end && (text.codeUnitAt(i) == 32 || text.codeUnitAt(i) == 9)) {
    i++;
  }
  if (i >= end) return false;

  final c = text.codeUnitAt(i);
  // '-', '*', '+'
  if (c == 45 || c == 42 || c == 43) {
    return i + 1 < end &&
        (text.codeUnitAt(i + 1) == 32 || text.codeUnitAt(i + 1) == 9);
  }

  // digits followed by . or ) and space
  var d = i;
  while (d < end && text.codeUnitAt(d) >= 48 && text.codeUnitAt(d) <= 57) {
    d++;
  }
  if (d > i &&
      d < end &&
      (text.codeUnitAt(d) == 46 || text.codeUnitAt(d) == 41)) {
    return d + 1 < end &&
        (text.codeUnitAt(d + 1) == 32 || text.codeUnitAt(d + 1) == 9);
  }
  return false;
}

bool _isLinkReferenceDefinition(String text, int start, int end) {
  var i = start;
  while (i < end && text.codeUnitAt(i) == 32 && (i - start) < 3) {
    i++;
  }
  if (i >= end || text.codeUnitAt(i) != 91) return false; // '['
  i++;
  var foundCloseBracket = false;
  while (i < end) {
    final c = text.codeUnitAt(i);
    if (c == 92 && i + 1 < end) {
      // '\'
      i += 2;
      continue;
    }
    if (c == 93) {
      // ']'
      foundCloseBracket = true;
      i++;
      break;
    }
    i++;
  }
  if (!foundCloseBracket || i >= end) return false;
  return text.codeUnitAt(i) == 58; // ':'
}
