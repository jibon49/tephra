// © 2026 Tephra. All rights reserved.

import '../nodes.dart';
import '../note_models.dart';
import '../util/offset_map.dart';

final class WikiLinkResult {
  WikiLinkResult(this.node, this.nextIndex);

  final MdWikiLink node;
  final int nextIndex;
}

final RegExp _sizeRegex = RegExp(r'^(\d+)(?:x(\d+))?$');
final RegExp _pdfPageRegex = RegExp(r'^page=(\d+)$');

(String left, String? rest) _splitFirstPipe(String inner) {
  var pipeIdx = -1;
  var hasBackslash = false;

  for (var i = 0; i < inner.length; i++) {
    if (inner[i] == '|') {
      if (i > 0 && inner[i - 1] == '\\') {
        pipeIdx = i - 1;
        hasBackslash = true;
        break;
      } else {
        pipeIdx = i;
        hasBackslash = false;
        break;
      }
    }
  }

  if (pipeIdx == -1) {
    return (inner, null);
  }

  final left = inner.substring(0, pipeIdx);
  final rest = hasBackslash
      ? inner.substring(pipeIdx + 2)
      : inner.substring(pipeIdx + 1);
  return (left, rest);
}

/// Tries to parse an Obsidian wikilink or embed starting at [index] in [text].
WikiLinkResult? parseWikiLink({
  required String text,
  required int index,
  required OffsetMap map,
}) {
  final bool isEmbed;
  final int openLen;

  if (text.startsWith('![[', index)) {
    isEmbed = true;
    openLen = 3;
  } else if (text.startsWith('[[', index)) {
    isEmbed = false;
    openLen = 2;
  } else {
    return null;
  }

  final newlineIdx = text.indexOf('\n', index + openLen);
  final closeIdx = text.indexOf(']]', index + openLen);

  if (closeIdx == -1) return null;
  if (newlineIdx != -1 && closeIdx > newlineIdx) return null;

  final inner = text.substring(index + openLen, closeIdx);
  if (inner.contains('[[') || inner.contains(']]')) return null;

  // 1. Split on first pipe
  final (rawLeft, rawRest) = _splitFirstPipe(inner);

  // 2. Parse left: split at first '#'
  final hashIdx = rawLeft.indexOf('#');
  final String rawTarget;
  final String? afterHash;

  if (hashIdx != -1) {
    rawTarget = rawLeft.substring(0, hashIdx).trim();
    afterHash = rawLeft.substring(hashIdx + 1);
  } else {
    rawTarget = rawLeft.trim();
    afterHash = null;
  }

  String? heading;
  String? blockRef;
  String? pdfPage;

  if (afterHash != null) {
    if (afterHash.startsWith('^')) {
      final b = afterHash.substring(1).trim();
      blockRef = b.isNotEmpty ? b : null;
    } else {
      final pageMatch = _pdfPageRegex.firstMatch(afterHash.trim());
      if (pageMatch != null) {
        pdfPage = pageMatch.group(1)!;
      } else {
        final h = afterHash.trim();
        heading = h.isNotEmpty ? h : null;
      }
    }
  }

  // 3. Parse rest
  String? alias;
  EmbedSize? size;

  if (rawRest != null) {
    if (isEmbed) {
      final pipeParts = rawRest.split('|');
      final lastPart = pipeParts.last.trim();
      final sizeMatch = _sizeRegex.firstMatch(lastPart);
      if (sizeMatch != null) {
        final width = int.parse(sizeMatch.group(1)!);
        final heightStr = sizeMatch.group(2);
        final height = heightStr != null ? int.parse(heightStr) : null;
        size = EmbedSize(width, height);

        final remaining = pipeParts
            .sublist(0, pipeParts.length - 1)
            .join('|')
            .trim();
        alias = remaining.isNotEmpty ? remaining : null;
      } else {
        final a = rawRest.trim();
        alias = a.isNotEmpty ? a : null;
      }
    } else {
      final a = rawRest.trim();
      alias = a.isNotEmpty ? a : null;
    }
  }

  // 4. Validate
  if (rawTarget.isEmpty &&
      heading == null &&
      blockRef == null &&
      pdfPage == null) {
    return null;
  }

  final end = closeIdx + 2;
  final node = MdWikiLink(
    map.toSource(index),
    map.toSourceEnd(end),
    target: rawTarget,
    heading: heading,
    blockRef: blockRef,
    alias: alias,
    size: size,
    pdfPage: pdfPage,
    embed: isEmbed,
  );

  return WikiLinkResult(node, end);
}
