// © 2026 Tephra. All rights reserved.

import '../nodes.dart';
import '../util/offset_map.dart';
import '../util/unicode.dart';

final class AutolinkResult {
  AutolinkResult(this.node, this.nextIndex);

  final MdAutolink node;
  final int nextIndex;
}

final RegExp _uriAutolinkRegex = RegExp(
  r'<([A-Za-z][A-Za-z0-9+.-]{1,31}:[^<>\x00-\x20]*)>',
);

final RegExp _emailAutolinkRegex = RegExp(
  r"<([a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*)>",
);

final RegExp _extendedAutolinkRegex = RegExp(
  r'(https?://|www\.)[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+(?:[^\s<]*)',
  caseSensitive: false,
);

/// Tries to parse a CommonMark `<scheme:...>` or `<email@...>` autolink.
AutolinkResult? parseCommonMarkAutolink({
  required String text,
  required int index,
  required OffsetMap map,
}) {
  if (text.codeUnitAt(index) != 0x3C) return null; // '<'

  final uriMatch = _uriAutolinkRegex.matchAsPrefix(text, index);
  if (uriMatch != null) {
    final raw = uriMatch.group(0)!;
    final url = uriMatch.group(1)!;
    final end = index + raw.length;
    final node = MdAutolink(
      map.toSource(index),
      map.toSourceEnd(end),
      url: url,
    );
    return AutolinkResult(node, end);
  }

  final emailMatch = _emailAutolinkRegex.matchAsPrefix(text, index);
  if (emailMatch != null) {
    final raw = emailMatch.group(0)!;
    final email = emailMatch.group(1)!;
    final end = index + raw.length;
    final node = MdAutolink(
      map.toSource(index),
      map.toSourceEnd(end),
      url: 'mailto:$email',
    );
    return AutolinkResult(node, end);
  }

  return null;
}

/// Checks if [index] in [text] is at a valid word boundary for GFM extended autolinks.
bool isExtendedAutolinkBoundary(String text, int index) {
  if (index == 0) return true;
  final prev = text.codeUnitAt(index - 1);
  if (isUnicodeWhitespace(prev)) return true;
  if (prev == 0x2A || // '*'
      prev == 0x5F || // '_'
      prev == 0x7E || // '~'
      prev == 0x28) {
    // '('
    return true;
  }
  return false;
}

/// Tries to parse a GFM extended autolink starting at [index] in [text].
AutolinkResult? parseExtendedAutolink({
  required String text,
  required int index,
  required OffsetMap map,
}) {
  if (!isExtendedAutolinkBoundary(text, index)) return null;

  final match = _extendedAutolinkRegex.matchAsPrefix(text, index);
  if (match == null) return null;

  var candidate = match.group(0)!;

  // Trim trailing punctuation per GFM spec
  while (candidate.isNotEmpty) {
    final lastChar = candidate[candidate.length - 1];
    if (lastChar == '?' ||
        lastChar == '!' ||
        lastChar == '.' ||
        lastChar == ',' ||
        lastChar == ':' ||
        lastChar == '*' ||
        lastChar == '_' ||
        lastChar == '~' ||
        lastChar == "'" ||
        lastChar == '"') {
      candidate = candidate.substring(0, candidate.length - 1);
      continue;
    }
    if (lastChar == ')') {
      var openCount = 0;
      var closeCount = 0;
      for (var i = 0; i < candidate.length; i++) {
        if (candidate.codeUnitAt(i) == 0x28) openCount++;
        if (candidate.codeUnitAt(i) == 0x29) closeCount++;
      }
      if (closeCount > openCount) {
        candidate = candidate.substring(0, candidate.length - 1);
        continue;
      }
    }
    if (lastChar == ';') {
      final ampIdx = candidate.lastIndexOf('&');
      if (ampIdx != -1) {
        final possibleEntity = candidate.substring(
          ampIdx + 1,
          candidate.length - 1,
        );
        if (RegExp(r'^[a-zA-Z0-9#]+$').hasMatch(possibleEntity)) {
          candidate = candidate.substring(0, candidate.length - 1);
          continue;
        }
      }
    }
    break;
  }

  if (candidate.isEmpty) return null;

  final url = candidate.toLowerCase().startsWith('www.')
      ? 'http://$candidate'
      : candidate;

  final end = index + candidate.length;
  final node = MdAutolink(map.toSource(index), map.toSourceEnd(end), url: url);

  return AutolinkResult(node, end);
}
