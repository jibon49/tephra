// © 2026 Tephra. All rights reserved.

import '../note_models.dart';
import '../util/entities.dart';
import '../util/unicode.dart';
import 'delimiters.dart';
import 'inline_scanner.dart';

bool _isAsciiPunctuation(int code) {
  return (code >= 33 && code <= 47) ||
      (code >= 58 && code <= 64) ||
      (code >= 91 && code <= 96) ||
      (code >= 123 && code <= 126);
}

/// Decodes backslash-escaped ASCII punctuation and HTML entities in [s].
String decodeEscapesAndEntities(String s) {
  if (s.isEmpty) return s;
  final sb = StringBuffer();
  var i = 0;
  while (i < s.length) {
    final c = s.codeUnitAt(i);
    if (c == 0x5C && i + 1 < s.length) {
      // '\\'
      final next = s.codeUnitAt(i + 1);
      if (_isAsciiPunctuation(next)) {
        sb.writeCharCode(next);
        i += 2;
        continue;
      }
    } else if (c == 0x26) {
      // '&'
      final semi = s.indexOf(';', i + 1);
      if (semi != -1 && semi - i <= 32) {
        final body = s.substring(i + 1, semi);
        if (body.startsWith('#')) {
          final cp = parseNumericEntity(body);
          if (cp != null) {
            sb.writeCharCode(cp);
            i = semi + 1;
            continue;
          }
        } else {
          final decoded = decodeEntity(body);
          if (decoded != null) {
            sb.write(decoded);
            i = semi + 1;
            continue;
          }
        }
      }
    }
    sb.writeCharCode(c);
    i++;
  }
  return sb.toString();
}

final class Bracket {
  Bracket({
    required this.isImage,
    required this.item,
    required this.delimiterBefore,
    this.active = true,
  });

  final bool isImage;
  final InlineItem item;
  final Delimiter? delimiterBefore;
  bool active;

  Bracket? prev;
  Bracket? next;
}

final class BracketStack {
  Bracket? head;
  Bracket? tail;

  void push(Bracket b) {
    if (tail == null) {
      head = b;
      tail = b;
    } else {
      tail!.next = b;
      b.prev = tail;
      tail = b;
    }
  }

  Bracket? pop() {
    final b = tail;
    if (b == null) return null;
    if (b.prev != null) {
      b.prev!.next = null;
      tail = b.prev;
    } else {
      head = null;
      tail = null;
    }
    b.prev = null;
    b.next = null;
    return b;
  }

  void remove(Bracket b) {
    if (b.prev != null) {
      b.prev!.next = b.next;
    } else {
      head = b.next;
    }
    if (b.next != null) {
      b.next!.prev = b.prev;
    } else {
      tail = b.prev;
    }
    b.prev = null;
    b.next = null;
  }
}

int _skipWhitespace(String text, int start) {
  var i = start;
  var hasNewline = false;
  while (i < text.length) {
    final c = text.codeUnitAt(i);
    if (c == 0x20 || c == 0x09) {
      i++;
    } else if (c == 0x0A) {
      if (hasNewline) break;
      hasNewline = true;
      i++;
    } else {
      break;
    }
  }
  return i;
}

(String dest, int nextIdx)? _parseDestination(String text, int start) {
  if (start >= text.length) return null;
  if (text.codeUnitAt(start) == 0x3C) {
    // '<'
    var i = start + 1;
    while (i < text.length) {
      final c = text.codeUnitAt(i);
      if (c == 0x5C &&
          i + 1 < text.length &&
          _isAsciiPunctuation(text.codeUnitAt(i + 1))) {
        i += 2;
        continue;
      }
      if (c == 0x0A || c == 0x3C) return null;
      if (c == 0x3E) {
        // '>'
        final raw = text.substring(start + 1, i);
        return (decodeEscapesAndEntities(raw), i + 1);
      }
      i++;
    }
    return null;
  }

  // Bare destination
  var depth = 0;
  var i = start;
  while (i < text.length) {
    final c = text.codeUnitAt(i);
    if (c <= 0x20 || c == 0x7F) break;
    if (c == 0x5C &&
        i + 1 < text.length &&
        _isAsciiPunctuation(text.codeUnitAt(i + 1))) {
      i += 2;
      continue;
    }
    if (c == 0x28) {
      // '('
      depth++;
      i++;
    } else if (c == 0x29) {
      // ')'
      if (depth == 0) break;
      depth--;
      i++;
    } else {
      i++;
    }
  }
  if (i == start || depth != 0) return null;
  final raw = text.substring(start, i);
  return (decodeEscapesAndEntities(raw), i);
}

(String title, int nextIdx)? _parseTitle(String text, int start) {
  if (start >= text.length) return null;
  final openChar = text.codeUnitAt(start);
  final int closeChar;
  if (openChar == 0x22) {
    // '"'
    closeChar = 0x22;
  } else if (openChar == 0x27) {
    // "'"
    closeChar = 0x27;
  } else if (openChar == 0x28) {
    // '('
    closeChar = 0x29; // ')'
  } else {
    return null;
  }

  var i = start + 1;
  while (i < text.length) {
    final c = text.codeUnitAt(i);
    if (c == 0x5C &&
        i + 1 < text.length &&
        _isAsciiPunctuation(text.codeUnitAt(i + 1))) {
      i += 2;
      continue;
    }
    if (c == 0x0A) {
      // '\n'
      var k = i + 1;
      while (k < text.length &&
          (text.codeUnitAt(k) == 0x20 || text.codeUnitAt(k) == 0x09)) {
        k++;
      }
      if (k < text.length && text.codeUnitAt(k) == 0x0A) {
        return null; // blank line in title not allowed
      }
      i++;
      continue;
    }
    if (c == closeChar) {
      final raw = text.substring(start + 1, i);
      return (decodeEscapesAndEntities(raw), i + 1);
    }
    i++;
  }
  return null;
}

(String url, String? title, int nextIdx)? parseInlineLinkTail(
  String text,
  int start,
) {
  if (start >= text.length || text.codeUnitAt(start) != 0x28) {
    return null; // '('
  }

  var i = _skipWhitespace(text, start + 1);
  if (i < text.length && text.codeUnitAt(i) == 0x29) {
    return ('', null, i + 1);
  }

  final destRes = _parseDestination(text, i);
  if (destRes == null) return null;
  final dest = destRes.$1;
  i = destRes.$2;

  final afterDest = _skipWhitespace(text, i);
  if (afterDest < text.length && text.codeUnitAt(afterDest) == 0x29) {
    return (dest, null, afterDest + 1);
  }

  if (afterDest == i) {
    return null; // Must have whitespace between destination and title
  }

  final titleRes = _parseTitle(text, afterDest);
  if (titleRes == null) return null;
  final title = titleRes.$1;
  i = _skipWhitespace(text, titleRes.$2);

  if (i < text.length && text.codeUnitAt(i) == 0x29) {
    return (dest, title, i + 1);
  }

  return null;
}

(String url, String? title, int nextIdx)? parseReferenceLinkTail({
  required String text,
  required int indexAfterBracket,
  required String bracketInnerText,
  required Map<String, LinkDefinition> definitions,
}) {
  // 1. Full reference [label]
  if (indexAfterBracket < text.length &&
      text.codeUnitAt(indexAfterBracket) == 0x5B) {
    var j = indexAfterBracket + 1;
    while (j < text.length) {
      final c = text.codeUnitAt(j);
      if (c == 0x5C &&
          j + 1 < text.length &&
          _isAsciiPunctuation(text.codeUnitAt(j + 1))) {
        j += 2;
        continue;
      }
      if (c == 0x5B) break;
      if (c == 0x5D) {
        final label = text.substring(indexAfterBracket + 1, j);
        if (label.isNotEmpty &&
            label.length <= 999 &&
            label.trim().isNotEmpty) {
          final norm = normalizeLabel(label);
          final def = definitions[norm];
          if (def != null) {
            return (def.url, def.title, j + 1);
          }
        }
        break;
      }
      j++;
    }
  }

  // 2. Collapsed reference []
  if (indexAfterBracket + 1 < text.length &&
      text.codeUnitAt(indexAfterBracket) == 0x5B &&
      text.codeUnitAt(indexAfterBracket + 1) == 0x5D) {
    final norm = normalizeLabel(bracketInnerText);
    final def = definitions[norm];
    if (def != null) {
      return (def.url, def.title, indexAfterBracket + 2);
    }
  }

  // 3. Shortcut reference
  final norm = normalizeLabel(bracketInnerText);
  final def = definitions[norm];
  if (def != null) {
    return (def.url, def.title, indexAfterBracket);
  }

  return null;
}
