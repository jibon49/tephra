// © 2026 Tephra. All rights reserved.

/// Pre-indexed UTF-16 line offsets for fast line-number lookups and slicing.
final class LineIndex {
  LineIndex(String text)
    : _textLength = text.length,
      _lineStarts = _computeStarts(text);

  static List<int> _computeStarts(String text) {
    final starts = <int>[0];
    var pos = text.indexOf('\n');
    while (pos != -1) {
      starts.add(pos + 1);
      pos = text.indexOf('\n', pos + 1);
    }
    return starts;
  }

  final int _textLength;
  final List<int> _lineStarts;

  /// Total number of lines. Empty string has 1 line; `'a\n'` has 2 lines.
  int get lineCount => _lineStarts.length;

  /// Start offset of [line] in UTF-16 code units (0-indexed).
  int lineStart(int line) {
    if (line < 0 || line >= _lineStarts.length) {
      throw RangeError.range(line, 0, _lineStarts.length - 1, 'line');
    }
    return _lineStarts[line];
  }

  /// Offset of the `\n` ending [line], or `text.length` for the last line.
  int lineEnd(int line) {
    if (line < 0 || line >= _lineStarts.length) {
      throw RangeError.range(line, 0, _lineStarts.length - 1, 'line');
    }
    if (line == _lineStarts.length - 1) {
      return _textLength;
    }
    return _lineStarts[line + 1] - 1;
  }

  /// 0-indexed line number containing [offset].
  /// [offset] == `text.length` resolves to the last line.
  /// Throws [RangeError] if [offset] is negative or exceeds `text.length`.
  int lineOf(int offset) {
    if (offset < 0 || offset > _textLength) {
      throw RangeError.range(offset, 0, _textLength, 'offset');
    }
    if (offset == _textLength) {
      return _lineStarts.length - 1;
    }

    var low = 0;
    var high = _lineStarts.length - 1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      final start = _lineStarts[mid];
      if (start <= offset) {
        if (mid == _lineStarts.length - 1 || _lineStarts[mid + 1] > offset) {
          return mid;
        }
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return low;
  }

  /// Returns the text of [line] without the trailing `\n` (and without `\r`).
  String lineText(String text, int line) {
    final start = lineStart(line);
    final end = lineEnd(line);
    var str = text.substring(start, end);
    if (str.endsWith('\r')) {
      str = str.substring(0, str.length - 1);
    }
    return str;
  }
}
