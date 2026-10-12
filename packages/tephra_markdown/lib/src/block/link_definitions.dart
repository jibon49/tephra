// © 2026 Tephra. All rights reserved.

import '../note_models.dart';
import '../util/entities.dart';
import '../util/unicode.dart';

/// Decodes backslash-escaped ASCII punctuation and HTML entities.
String decodeEscapesAndEntities(String s) {
  final buf = StringBuffer();
  var i = 0;
  while (i < s.length) {
    final c = s.codeUnitAt(i);
    if (c == 0x5C &&
        i + 1 < s.length &&
        isAsciiPunctuation(s.codeUnitAt(i + 1))) {
      buf.writeCharCode(s.codeUnitAt(i + 1));
      i += 2;
    } else if (c == 0x26) {
      final semi = s.indexOf(';', i + 1);
      if (semi != -1 && semi - i <= 32) {
        final body = s.substring(i + 1, semi);
        if (body.startsWith('#')) {
          final cp = parseNumericEntity(body);
          if (cp != null) {
            buf.writeCharCode(cp);
            i = semi + 1;
            continue;
          }
        } else {
          final decoded = decodeEntity(body);
          if (decoded != null) {
            buf.write(decoded);
            i = semi + 1;
            continue;
          }
        }
      }
      buf.writeCharCode(c);
      i++;
    } else {
      buf.writeCharCode(c);
      i++;
    }
  }
  return buf.toString();
}

/// Extracts link reference definitions from the start of paragraph [segments].
///
/// Modifies [segments] by removing consumed line segments and records definitions
/// in [definitions] (first definition of a label wins).
void extractLinkDefinitions({
  required String text,
  required List<(int start, int end)> segments,
  required Map<String, LinkDefinition> definitions,
}) {
  while (segments.isNotEmpty) {
    // Reconstruct the virtual text of remaining lines.
    final lines = segments.map((s) => text.substring(s.$1, s.$2)).toList();
    final match = _parseSingleDefinition(lines);
    if (match == null) break;

    final normalized = normalizeLabel(match.label);
    if (!definitions.containsKey(normalized)) {
      definitions[normalized] = LinkDefinition(
        normalized,
        decodeEscapesAndEntities(match.url),
        match.title != null ? decodeEscapesAndEntities(match.title!) : null,
      );
    }

    segments.removeRange(0, match.linesConsumed);
  }
}

final class _DefResult {
  const _DefResult({
    required this.label,
    required this.url,
    required this.title,
    required this.linesConsumed,
  });

  final String label;
  final String url;
  final String? title;
  final int linesConsumed;
}

_DefResult? _parseSingleDefinition(List<String> lines) {
  if (lines.isEmpty) return null;

  var lineIdx = 0;
  var col = 0;
  var curLine = lines[0];

  // Optional leading spaces up to 3 columns.
  while (col < curLine.length &&
      (curLine[col] == ' ' || curLine[col] == '\t')) {
    col++;
  }
  if (col >= curLine.length || curLine[col] != '[') return null;

  // Scan link label [label]:
  final labelStart = col + 1;
  var i = labelStart;
  var foundClose = false;
  while (lineIdx < lines.length) {
    curLine = lines[lineIdx];
    while (i < curLine.length) {
      final ch = curLine[i];
      if (ch == '\\' && i + 1 < curLine.length) {
        i += 2;
        continue;
      }
      if (ch == '[') return null; // Unescaped [ not allowed in label
      if (ch == ']') {
        foundClose = true;
        break;
      }
      i++;
    }
    if (foundClose) break;
    // CommonMark spec §4.7: link label cannot contain blank lines and max 999 chars
    lineIdx++;
    if (lineIdx >= lines.length) return null;
    i = 0;
  }
  if (!foundClose) return null;

  // Next char must be ':'
  if (i + 1 >= curLine.length || curLine[i + 1] != ':') return null;

  // Label text
  String rawLabel;
  if (lineIdx == 0) {
    rawLabel = curLine.substring(labelStart, i);
  } else {
    final sb = StringBuffer();
    sb.write(lines[0].substring(labelStart));
    for (var l = 1; l < lineIdx; l++) {
      sb.write('\n');
      sb.write(lines[l]);
    }
    sb.write('\n');
    sb.write(curLine.substring(0, i));
    rawLabel = sb.toString();
  }
  if (rawLabel.trim().isEmpty || rawLabel.length > 999) return null;

  col = i + 2; // Past ']:'

  // Optional whitespace (at most one newline)
  var sawNewline = false;
  while (true) {
    while (col < curLine.length &&
        (curLine[col] == ' ' || curLine[col] == '\t')) {
      col++;
    }
    if (col < curLine.length) break;
    // Reached end of line
    if (sawNewline) return null; // Only at most one newline allowed
    lineIdx++;
    if (lineIdx >= lines.length) return null;
    curLine = lines[lineIdx];
    col = 0;
    sawNewline = true;
  }

  // Scan destination
  String dest;
  if (curLine[col] == '<') {
    final destStart = col + 1;
    var destEnd = -1;
    for (var j = destStart; j < curLine.length; j++) {
      if (curLine[j] == '\\' && j + 1 < curLine.length) {
        j++;
        continue;
      }
      if (curLine[j] == '<') return null;
      if (curLine[j] == '>') {
        destEnd = j;
        break;
      }
    }
    if (destEnd == -1) return null;
    dest = curLine.substring(destStart, destEnd);
    col = destEnd + 1;
  } else {
    final destStart = col;
    var parens = 0;
    while (col < curLine.length) {
      final ch = curLine[col];
      final cu = curLine.codeUnitAt(col);
      if (ch == '\\' && col + 1 < curLine.length) {
        col += 2;
        continue;
      }
      if (ch == ' ' || ch == '\t' || cu < 32 || cu == 127) {
        break;
      }
      if (ch == '(') {
        parens++;
        if (parens > 32) return null;
      } else if (ch == ')') {
        if (parens == 0) break;
        parens--;
      }
      col++;
    }
    if (parens != 0 || col == destStart) return null;
    dest = curLine.substring(destStart, col);
  }

  final destLineIdx = lineIdx;

  // After destination: optional whitespace before title
  final preTitleLineIdx = lineIdx;
  final preTitleCol = col;
  var whitespaceBeforeTitleNewline = false;

  while (true) {
    while (col < curLine.length &&
        (curLine[col] == ' ' || curLine[col] == '\t')) {
      col++;
    }
    if (col < curLine.length) break;
    if (whitespaceBeforeTitleNewline) break;
    if (lineIdx + 1 >= lines.length) break;
    lineIdx++;
    curLine = lines[lineIdx];
    col = 0;
    whitespaceBeforeTitleNewline = true;
  }

  // Check if title is present
  if (col < curLine.length &&
      (curLine[col] == '"' || curLine[col] == "'" || curLine[col] == '(')) {
    final openQuote = curLine[col];
    final closeQuote = openQuote == '(' ? ')' : openQuote;
    final titleStartLineIdx = lineIdx;
    final titleStartCol = col + 1;

    var foundTitleEnd = false;
    var titleEndLineIdx = lineIdx;
    var titleEndCol = -1;

    var tI = titleStartCol;
    while (titleEndLineIdx < lines.length) {
      curLine = lines[titleEndLineIdx];
      while (tI < curLine.length) {
        final ch = curLine[tI];
        if (ch == '\\' && tI + 1 < curLine.length) {
          tI += 2;
          continue;
        }
        if (ch == closeQuote) {
          foundTitleEnd = true;
          titleEndCol = tI;
          break;
        }
        tI++;
      }
      if (foundTitleEnd) break;
      titleEndLineIdx++;
      if (titleEndLineIdx >= lines.length) break;
      if (lines[titleEndLineIdx].trim().isEmpty) {
        break; // Blank line in title forbidden
      }
      tI = 0;
    }

    if (foundTitleEnd) {
      // Check trailing on title end line
      var afterTitle = titleEndCol + 1;
      curLine = lines[titleEndLineIdx];
      while (afterTitle < curLine.length &&
          (curLine[afterTitle] == ' ' || curLine[afterTitle] == '\t')) {
        afterTitle++;
      }
      if (afterTitle == curLine.length) {
        // Valid title!
        String titleStr;
        if (titleStartLineIdx == titleEndLineIdx) {
          titleStr = curLine.substring(titleStartCol, titleEndCol);
        } else {
          final sb = StringBuffer();
          sb.write(lines[titleStartLineIdx].substring(titleStartCol));
          for (var l = titleStartLineIdx + 1; l < titleEndLineIdx; l++) {
            sb.write('\n');
            sb.write(lines[l]);
          }
          sb.write('\n');
          sb.write(curLine.substring(0, titleEndCol));
          titleStr = sb.toString();
        }
        return _DefResult(
          label: rawLabel,
          url: dest,
          title: titleStr,
          linesConsumed: titleEndLineIdx + 1,
        );
      }
    }

    // Title was invalid.
    if (whitespaceBeforeTitleNewline) {
      // Title was on a separate line from destination.
      // Destination line is complete!
      return _DefResult(
        label: rawLabel,
        url: dest,
        title: null,
        linesConsumed: destLineIdx + 1,
      );
    } else {
      // Title on the same line was invalid -> entire definition invalid
      return null;
    }
  }

  // No title: check trailing on destination line
  curLine = lines[destLineIdx];
  var trailCol = preTitleLineIdx == destLineIdx ? preTitleCol : col;
  while (trailCol < curLine.length &&
      (curLine[trailCol] == ' ' || curLine[trailCol] == '\t')) {
    trailCol++;
  }
  if (trailCol < curLine.length) {
    return null; // Garbage after destination
  }

  return _DefResult(
    label: rawLabel,
    url: dest,
    title: null,
    linesConsumed: destLineIdx + 1,
  );
}
