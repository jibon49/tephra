// © 2026 Tephra. All rights reserved.

import 'dart:math' as math;

import 'frontmatter_scanner.dart';
import 'lexical_guard.dart';

sealed class AutocompleteContext {
  const AutocompleteContext({
    required this.replaceStart,
    required this.replaceEnd,
    required this.query,
  });

  /// First offset replaced when a candidate is accepted.
  final int replaceStart;

  /// Caret offset at detection time.
  final int replaceEnd;

  /// Query string between [replaceStart] and [replaceEnd].
  final String query;
}

final class NoteLinkContext extends AutocompleteContext {
  const NoteLinkContext({
    required super.replaceStart,
    required super.replaceEnd,
    required super.query,
    required this.embed,
    required this.closerPresent,
    required this.openStart,
  });

  final bool embed;
  final bool closerPresent;
  final int openStart;

  @override
  String toString() =>
      'NoteLinkContext(query: "$query", embed: $embed, closer: $closerPresent, start: $replaceStart, open: $openStart)';
}

final class HeadingLinkContext extends AutocompleteContext {
  const HeadingLinkContext({
    required super.replaceStart,
    required super.replaceEnd,
    required super.query,
    required this.noteText,
    required this.embed,
    required this.closerPresent,
    required this.openStart,
  });

  final String noteText;
  final bool embed;
  final bool closerPresent;
  final int openStart;

  @override
  String toString() =>
      'HeadingLinkContext(noteText: "$noteText", query: "$query", embed: $embed, closer: $closerPresent, start: $replaceStart)';
}

final class BlockLinkContext extends AutocompleteContext {
  const BlockLinkContext({
    required super.replaceStart,
    required super.replaceEnd,
    required super.query,
    required this.noteText,
    required this.embed,
    required this.closerPresent,
    required this.openStart,
  });

  final String noteText;
  final bool embed;
  final bool closerPresent;
  final int openStart;

  @override
  String toString() =>
      'BlockLinkContext(noteText: "$noteText", query: "$query", embed: $embed, closer: $closerPresent, start: $replaceStart)';
}

final class AliasLinkContext extends AutocompleteContext {
  const AliasLinkContext({
    required super.replaceStart,
    required super.replaceEnd,
    required super.query,
    required this.noteText,
    this.heading,
    required this.embed,
    required this.closerPresent,
    required this.openStart,
  });

  final String noteText;
  final String? heading;
  final bool embed;
  final bool closerPresent;
  final int openStart;

  @override
  String toString() =>
      'AliasLinkContext(noteText: "$noteText", heading: $heading, query: "$query", embed: $embed, closer: $closerPresent, start: $replaceStart)';
}

final class TagContext extends AutocompleteContext {
  const TagContext({
    required super.replaceStart,
    required super.replaceEnd,
    required super.query,
    this.inFrontmatter = false,
  });

  final bool inFrontmatter;

  @override
  String toString() =>
      'TagContext(query: "$query", inFrontmatter: $inFrontmatter, start: $replaceStart)';
}

final class PropertyKeyContext extends AutocompleteContext {
  const PropertyKeyContext({
    required super.replaceStart,
    required super.replaceEnd,
    required super.query,
  });

  @override
  String toString() =>
      'PropertyKeyContext(query: "$query", start: $replaceStart)';
}

final class PropertyValueContext extends AutocompleteContext {
  const PropertyValueContext({
    required super.replaceStart,
    required super.replaceEnd,
    required super.query,
    required this.key,
    this.inInlineList = false,
    this.forceEmpty = false,
  });

  final String key;
  final bool inInlineList;
  final bool forceEmpty;

  @override
  String toString() =>
      'PropertyValueContext(key: "$key", query: "$query", inInlineList: $inInlineList, forceEmpty: $forceEmpty, start: $replaceStart)';
}

final class SlashContext extends AutocompleteContext {
  const SlashContext({
    required super.replaceStart,
    required super.replaceEnd,
    required super.query,
    required this.slashStart,
  });

  final int slashStart;

  @override
  String toString() =>
      'SlashContext(query: "$query", slashStart: $slashStart, start: $replaceStart, end: $replaceEnd)';
}

/// Detects if the caret at [caret] in [text] is inside an autocomplete context.
///
/// Returns `null` if the cursor is outside autocompletable constructs or inside
/// syntax fences/math/code/comments.
AutocompleteContext? detectAutocompleteContext(
  String text,
  int caret, {
  bool force = false,
  bool forceEmpty = false,
  bool slashCommands = true,
}) {
  if (caret < 0 || caret > text.length) return null;

  final lexical = lexicalStateAt(text, caret);
  if (lexical.inFence ||
      lexical.inMathBlock ||
      lexical.inInlineCode ||
      lexical.inComment) {
    return null;
  }

  // 1. Line boundaries
  var lineStart = 0;
  for (var i = caret - 1; i >= 0; i--) {
    if (text.codeUnitAt(i) == 0x0A /* \n */ ) {
      lineStart = i + 1;
      break;
    }
  }

  var lineEnd = text.length;
  for (var i = caret; i < text.length; i++) {
    if (text.codeUnitAt(i) == 0x0A /* \n */ ) {
      lineEnd = i;
      break;
    }
  }

  final lineText = text.substring(lineStart, lineEnd);
  final before = text.substring(lineStart, caret);
  final after = text.substring(caret, lineEnd);

  // 2. Frontmatter contexts (keys and values)
  final fm = frontmatterRange(text);
  final inFm = fm != null && fm.containsOffset(caret);

  if (inFm) {
    final lineTrimmed = lineText.trim();
    if (lineTrimmed == '---' || lineTrimmed == '...') {
      return null;
    }

    final lineIndex = lineAtOffset(text, caret);

    // Check PropertyValueContext
    // 2a. Line is `key: value`
    final kvMatch = RegExp(r'^([^\s#:][^:]*):[ \t]+(.*)$').firstMatch(before);
    if (kvMatch != null) {
      final key = _unquoteKey(kvMatch.group(1)!.trim());
      final rest = kvMatch.group(2)!;
      if (rest.startsWith('[')) {
        // Inline list: query = text after the last `,` or `[` with leading spaces trimmed
        final lastDelim = math.max(
          rest.lastIndexOf(','),
          rest.lastIndexOf('['),
        );
        final afterDelim = rest.substring(lastDelim + 1);
        final trimmed = afterDelim.trimLeft();
        final query = trimmed;
        final replaceStart = lineStart + before.length - trimmed.length;
        return PropertyValueContext(
          replaceStart: replaceStart,
          replaceEnd: caret,
          query: query,
          key: key,
          inInlineList: true,
        );
      } else if (rest.startsWith('"') ||
          rest.startsWith("'") ||
          rest.startsWith('|') ||
          rest.startsWith('>')) {
        return null;
      } else {
        final query = rest;
        final replaceStart = lineStart + before.length - rest.length;
        return PropertyValueContext(
          replaceStart: replaceStart,
          replaceEnd: caret,
          query: query,
          key: key,
          inInlineList: false,
        );
      }
    }

    // 2b. Line is list item: ` - item`
    final listMatch = RegExp(r'^\s*-\s+(.*)$').firstMatch(before);
    if (listMatch != null) {
      final key = propertyKeyForLine(text, fm, lineIndex);
      if (key != null) {
        final query = listMatch.group(1)!;
        final replaceStart = lineStart + before.length - query.length;
        return PropertyValueContext(
          replaceStart: replaceStart,
          replaceEnd: caret,
          query: query,
          key: key,
          inInlineList: false,
        );
      }
    }

    // 2c. Force empty value context (after accepting a key)
    if (forceEmpty) {
      final emptyMatch = RegExp(r'^([^\s#:][^:]*):[ \t]*$').firstMatch(before);
      if (emptyMatch != null) {
        final key = _unquoteKey(emptyMatch.group(1)!.trim());
        return PropertyValueContext(
          replaceStart: caret,
          replaceEnd: caret,
          query: '',
          key: key,
          forceEmpty: true,
        );
      }
    }

    // 2d. PropertyKeyContext
    if (!lineText.contains(':')) {
      if (before.isEmpty) {
        if (force) {
          return PropertyKeyContext(
            replaceStart: lineStart,
            replaceEnd: caret,
            query: '',
          );
        }
      } else if (RegExp(r'^[A-Za-z0-9_][A-Za-z0-9_ \-]*$').hasMatch(before)) {
        return PropertyKeyContext(
          replaceStart: lineStart,
          replaceEnd: caret,
          query: before,
        );
      }
    }

    return null;
  }

  // Outside frontmatter
  if (!lexical.isClean) return null;

  if (!force && _isTableDelimiterRow(lineText)) {
    return null;
  }

  // 3. Open delimiter '[[' (links check first)
  final open = before.lastIndexOf('[[');
  if (open != -1) {
    final inner = before.substring(open + 2);
    if (!inner.contains(']') && !inner.contains('[') && inner.length <= 200) {
      final embed = open > 0 && before[open - 1] == '!';
      final openStart = embed ? lineStart + open - 1 : lineStart + open;
      final closerPresent = after.startsWith(']]');

      if (inner.contains('|')) {
        final lastPipe = inner.lastIndexOf('|');
        final query = inner.substring(lastPipe + 1);

        final firstPipe = inner.indexOf('|');
        final firstHash = inner.indexOf('#');

        final String noteText;
        final String? heading;

        if (firstHash != -1 && firstHash < firstPipe) {
          noteText = inner.substring(0, firstHash);
          heading = inner.substring(firstHash + 1, firstPipe);
        } else {
          noteText = inner.substring(0, firstPipe);
          heading = null;
        }

        final replaceStart = lineStart + open + 2 + lastPipe + 1;
        return AliasLinkContext(
          replaceStart: replaceStart,
          replaceEnd: caret,
          query: query,
          noteText: noteText,
          heading: heading,
          embed: embed,
          closerPresent: closerPresent,
          openStart: openStart,
        );
      }

      if (inner.contains('#')) {
        final firstHash = inner.indexOf('#');
        final afterFirstHash = inner.substring(firstHash + 1);

        if (afterFirstHash.startsWith('^')) {
          final query = afterFirstHash.substring(1);
          final noteText = inner.substring(0, firstHash);
          final replaceStart = lineStart + open + 2 + firstHash + 2;
          return BlockLinkContext(
            replaceStart: replaceStart,
            replaceEnd: caret,
            query: query,
            noteText: noteText,
            embed: embed,
            closerPresent: closerPresent,
            openStart: openStart,
          );
        } else {
          final lastHash = inner.lastIndexOf('#');
          final query = inner.substring(lastHash + 1);
          final noteText = inner.substring(0, firstHash);
          final replaceStart = lineStart + open + 2 + lastHash + 1;
          return HeadingLinkContext(
            replaceStart: replaceStart,
            replaceEnd: caret,
            query: query,
            noteText: noteText,
            embed: embed,
            closerPresent: closerPresent,
            openStart: openStart,
          );
        }
      }

      if (inner.contains('^')) {
        final firstCaret = inner.indexOf('^');
        final noteText = inner.substring(0, firstCaret);
        final query = inner.substring(firstCaret + 1);
        final replaceStart = lineStart + open + 2 + firstCaret + 1;
        return BlockLinkContext(
          replaceStart: replaceStart,
          replaceEnd: caret,
          query: query,
          noteText: noteText,
          embed: embed,
          closerPresent: closerPresent,
          openStart: openStart,
        );
      }

      final replaceStart = lineStart + open + 2;
      return NoteLinkContext(
        replaceStart: replaceStart,
        replaceEnd: caret,
        query: inner,
        embed: embed,
        closerPresent: closerPresent,
        openStart: openStart,
      );
    }
  }

  // 4. Tag detection (body only; not in frontmatter)
  // Suppressed when:
  // - before matches ^\s*#{1,6}$ (heading marker)
  if (RegExp(r'^\s*#{1,6}$').hasMatch(before)) {
    return null;
  }

  // - character after caret is a letter/digit (editing in the middle of a word)
  if (after.isNotEmpty &&
      RegExp(r'^[\p{L}\p{N}]', unicode: true).hasMatch(after)) {
    return null;
  }

  // - the # follows `](` or `[[` (links win)
  final lastMdLinkOpen = before.lastIndexOf('](');
  if (lastMdLinkOpen != -1 && !before.substring(lastMdLinkOpen).contains(')')) {
    return null;
  }

  final tagMatch = RegExp(
    r'(?<![\p{L}\p{N}\p{M}_/&#\\])#([\p{L}\p{N}\p{M}_\-/]*)$',
    unicode: true,
  ).firstMatch(before);

  if (tagMatch != null) {
    final query = tagMatch.group(1)!;
    // Suppressed when query is non-empty and all digits (#123 is not a tag)
    if (query.isNotEmpty && RegExp(r'^\d+$').hasMatch(query)) {
      return null;
    }

    final replaceStart = lineStart + tagMatch.start + 1;
    return TagContext(
      replaceStart: replaceStart,
      replaceEnd: caret,
      query: query,
      inFrontmatter: false,
    );
  }

  // 5. Slash command detection (body only; not in frontmatter; clean lexical guard)
  if (slashCommands) {
    final slashMatch = RegExp(r'(^|[ \t])/([^\s/]*)$').firstMatch(before);
    if (slashMatch != null) {
      final prefixLen = slashMatch.group(1)!.length;
      final slashOffset = lineStart + slashMatch.start + prefixLen;
      final query = slashMatch.group(2)!;
      return SlashContext(
        replaceStart: slashOffset,
        replaceEnd: caret,
        query: query,
        slashStart: slashOffset,
      );
    }
  }

  return null;
}

bool _isTableDelimiterRow(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty) return false;
  return RegExp(r'^\|?(\s*:?-+:?\s*\|)+\s*:?-+:?\s*\|?$').hasMatch(trimmed);
}

String _unquoteKey(String k) {
  if ((k.startsWith('"') && k.endsWith('"') && k.length >= 2) ||
      (k.startsWith("'") && k.endsWith("'") && k.length >= 2)) {
    return k.substring(1, k.length - 1);
  }
  return k;
}
