// © 2026 Tephra. All rights reserved.

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

/// Detects if the caret at [caret] in [text] is inside an autocomplete context.
///
/// Returns `null` if the cursor is outside link constructs or inside syntax fences/math/code/comments/frontmatter.
AutocompleteContext? detectAutocompleteContext(
  String text,
  int caret, {
  bool force = false,
}) {
  if (caret < 0 || caret > text.length) return null;

  final lexical = lexicalStateAt(text, caret);
  if (!lexical.isClean) return null;

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
  if (!force && _isTableDelimiterRow(lineText)) {
    return null;
  }

  final before = text.substring(lineStart, caret);
  final after = text.substring(caret, lineEnd);

  // 2. Open delimiter '[['
  final open = before.lastIndexOf('[[');
  if (open == -1) return null;

  final inner = before.substring(open + 2);
  if (inner.contains(']') || inner.contains('[') || inner.length > 200) {
    return null;
  }

  // 3. Embed check and closer check
  final embed = open > 0 && before[open - 1] == '!';
  final openStart = embed ? lineStart + open - 1 : lineStart + open;
  final closerPresent = after.startsWith(']]');

  // 4. Classify inner
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

  // Plain note link
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

bool _isTableDelimiterRow(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty) return false;
  return RegExp(r'^\|?(\s*:?-+:?\s*\|)+\s*:?-+:?\s*\|?$').hasMatch(trimmed);
}
