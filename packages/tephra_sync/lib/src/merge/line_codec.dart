// © 2026 Tephra. All rights reserved.

/// Splits text into a list of lines keeping the trailing `\n` on each line
/// except possibly the last line if [text] does not terminate with `\n`.
List<String> splitLines(String text) {
  if (text.isEmpty) return const [];
  final lines = <String>[];
  var start = 0;
  while (start < text.length) {
    final nextNewline = text.indexOf('\n', start);
    if (nextNewline == -1) {
      lines.add(text.substring(start));
      break;
    } else {
      lines.add(text.substring(start, nextNewline + 1));
      start = nextNewline + 1;
    }
  }
  return lines;
}

/// Maps distinct line strings to single UTF-16 code units for line-level diffing.
///
/// Starts at `0x0100` and skips Unicode surrogate pairs (`0xD800` to `0xDFFF`).
/// Limits distinct lines to 60,000. Exceeding this marks the codec as overflowed.
final class LineCodec {
  /// Maximum distinct lines supported before declaring a merge conflict.
  static const int maxDistinctLines = 60000;

  final Map<String, int> _lineToCode = {};
  final Map<int, String> _codeToLine = {};
  int _nextCode = 0x0100;
  bool _overflow = false;

  /// Whether distinct line count exceeded [maxDistinctLines].
  bool get hasOverflow => _overflow;

  /// Current number of distinct line strings registered.
  int get distinctLineCount => _lineToCode.length;

  /// Encodes [lines] into a UTF-16 string where each character represents one line.
  ///
  /// Returns `null` if the distinct line limit ([maxDistinctLines]) is exceeded.
  String? encode(List<String> lines) {
    if (_overflow) return null;
    final buffer = StringBuffer();

    for (final line in lines) {
      var code = _lineToCode[line];
      if (code == null) {
        if (_lineToCode.length >= maxDistinctLines) {
          _overflow = true;
          return null;
        }

        // Skip UTF-16 surrogate range
        if (_nextCode >= 0xD800 && _nextCode <= 0xDFFF) {
          _nextCode = 0xE000;
        }

        code = _nextCode++;
        _lineToCode[line] = code;
        _codeToLine[code] = line;
      }
      buffer.writeCharCode(code);
    }

    return buffer.toString();
  }

  /// Decodes a UTF-16 string back into the corresponding list of line strings.
  List<String> decode(String encoded) {
    final lines = <String>[];
    for (var i = 0; i < encoded.length; i++) {
      final code = encoded.codeUnitAt(i);
      final line = _codeToLine[code];
      if (line != null) {
        lines.add(line);
      }
    }
    return lines;
  }
}
