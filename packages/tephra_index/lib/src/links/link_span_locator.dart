// © 2026 Tephra. All rights reserved.

import '../extract/extracted_note.dart';
import '../model/link_record.dart';

/// Returns `(start, end, isAngle)` for the path part of [link] within [text].
(int start, int end, bool isAngle) locateLinkPathSpan(
  String text,
  ExtractedLink link,
) {
  if (link.syntax == LinkSyntax.wiki) {
    final prefixLen = link.kind == LinkKind.embed ? 3 : 2; // ![[ vs [[
    final i = link.start + prefixLen;
    var j = i;
    while (j < link.end && j < text.length) {
      final ch = text[j];
      if (ch == '#' || ch == '|' || ch == ']') {
        break;
      }
      if (ch == '\\' && j + 1 < text.length && text[j + 1] == '|') {
        break; // escaped pipe inside a table cell
      }
      j++;
    }
    return (i, j, false);
  } else {
    // Markdown link: scan backwards from link.end - 1 to find the matching '('
    var depth = 0;
    var p = -1;
    final searchEnd = (link.end - 1).clamp(0, text.length - 1);
    for (var k = searchEnd; k >= link.start; k--) {
      if (text[k] == ')') {
        depth++;
      } else if (text[k] == '(') {
        depth--;
        if (depth == 0) {
          p = k;
          break;
        }
      }
    }

    if (p == -1 || p + 1 >= text.length) {
      return (link.start, link.end, false);
    }

    if (text[p + 1] == '<') {
      final start = p + 2;
      var j = start;
      while (j < link.end && j < text.length) {
        final ch = text[j];
        if (ch == '#' || ch == '>') {
          break;
        }
        j++;
      }
      return (start, j, true);
    } else {
      final start = p + 1;
      var j = start;
      while (j < link.end && j < text.length) {
        final ch = text[j];
        if (ch == '#' || ch == ' ' || ch == ')') {
          break;
        }
        j++;
      }
      return (start, j, false);
    }
  }
}
