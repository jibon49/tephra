// © 2026 Tephra. All rights reserved.

import 'source_styles.dart';

/// A styled range [start, end) on a single line containing an ordered list of [tokens].
final class RangeStyle {
  const RangeStyle(this.start, this.end, this.tokens);

  final int start;
  final int end;
  final List<SourceToken> tokens;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! RangeStyle) return false;
    if (start != other.start || end != other.end) return false;
    if (tokens.length != other.tokens.length) return false;
    for (var i = 0; i < tokens.length; i++) {
      if (tokens[i] != other.tokens[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(start, end, Object.hashAll(tokens));

  @override
  String toString() => 'RangeStyle($start..$end: $tokens)';
}

/// A lightweight, line-local regex styler used for immediately editing lines before a full re-parse.
final class QuickStyler {
  QuickStyler._();

  static final _headingRegExp = RegExp(r'^(#{1,6})(\s)');
  static final _inlineCodeRegExp = RegExp(r'`([^`]+)`');
  static final _strongRegExp = RegExp(r'\*\*([^*]+)\*\*');
  static final _emphasisRegExp = RegExp(r'(?<![*\w])\*([^*\s][^*]*)\*');
  static final _wikilinkRegExp = RegExp(r'\[\[([^\]]+)\]\]');
  static final _tagRegExp = RegExp(
    r'(?<![\w/])#([\p{L}\p{N}_/-]*[\p{L}_/-][\p{L}\p{N}_/-]*)',
    unicode: true,
  );
  static final _highlightRegExp = RegExp(r'==([^=]+)==');
  static final _listMarkerRegExp = RegExp(r'^\s*([-*+]|\d{1,9}[.)])\s');
  static final _quoteMarkerRegExp = RegExp(r'^\s*>+');

  /// Styles a single line of text with regexes into sorted, non-overlapping [RangeStyle]s.
  static List<RangeStyle> style(String line) {
    if (line.isEmpty) return const [];

    final rawSpans = <RawSpan>[];

    // 1. Heading
    final headingMatch = _headingRegExp.firstMatch(line);
    if (headingMatch != null) {
      final level = headingMatch.group(1)!.length;
      final headingToken = switch (level) {
        1 => SourceToken.heading1,
        2 => SourceToken.heading2,
        3 => SourceToken.heading3,
        4 => SourceToken.heading4,
        5 => SourceToken.heading5,
        _ => SourceToken.heading6,
      };
      rawSpans.add(RawSpan(0, line.length, headingToken));
      rawSpans.add(RawSpan(0, headingMatch.end, SourceToken.headingMarker));
    }

    // 2. Quote marker
    final quoteMatch = _quoteMarkerRegExp.firstMatch(line);
    if (quoteMatch != null) {
      rawSpans.add(RawSpan(0, quoteMatch.end, SourceToken.quoteMarker));
    }

    // 3. List marker
    final listMatch = _listMarkerRegExp.firstMatch(line);
    if (listMatch != null) {
      rawSpans.add(RawSpan(0, listMatch.end, SourceToken.listMarker));
    }

    // 4. Inline code
    for (final m in _inlineCodeRegExp.allMatches(line)) {
      rawSpans.add(RawSpan(m.start, m.end, SourceToken.inlineCode));
      rawSpans.add(RawSpan(m.start, m.start + 1, SourceToken.emphasisMarker));
      rawSpans.add(RawSpan(m.end - 1, m.end, SourceToken.emphasisMarker));
    }

    // 5. Strong
    for (final m in _strongRegExp.allMatches(line)) {
      rawSpans.add(RawSpan(m.start, m.end, SourceToken.strong));
      rawSpans.add(RawSpan(m.start, m.start + 2, SourceToken.emphasisMarker));
      rawSpans.add(RawSpan(m.end - 2, m.end, SourceToken.emphasisMarker));
    }

    // 6. Emphasis
    for (final m in _emphasisRegExp.allMatches(line)) {
      rawSpans.add(RawSpan(m.start, m.end, SourceToken.emphasis));
      rawSpans.add(RawSpan(m.start, m.start + 1, SourceToken.emphasisMarker));
      rawSpans.add(RawSpan(m.end - 1, m.end, SourceToken.emphasisMarker));
    }

    // 7. Wikilink
    for (final m in _wikilinkRegExp.allMatches(line)) {
      rawSpans.add(RawSpan(m.start, m.end, SourceToken.wikiTarget));
      rawSpans.add(RawSpan(m.start, m.start + 2, SourceToken.wikiBracket));
      rawSpans.add(RawSpan(m.end - 2, m.end, SourceToken.wikiBracket));
    }

    // 8. Tag
    for (final m in _tagRegExp.allMatches(line)) {
      rawSpans.add(RawSpan(m.start, m.end, SourceToken.tag));
    }

    // 9. Highlight
    for (final m in _highlightRegExp.allMatches(line)) {
      rawSpans.add(RawSpan(m.start, m.end, SourceToken.highlight));
      rawSpans.add(RawSpan(m.start, m.start + 2, SourceToken.emphasisMarker));
      rawSpans.add(RawSpan(m.end - 2, m.end, SourceToken.emphasisMarker));
    }

    return sweepSpans(rawSpans, line.length);
  }
}

final class RawSpan {
  const RawSpan(this.start, this.end, this.token);
  final int start;
  final int end;
  final SourceToken token;
}

/// Converts overlapping spans over a line of [lineLength] into non-overlapping [RangeStyle]s.
List<RangeStyle> sweepSpans(List<RawSpan> spans, int lineLength) {
  if (spans.isEmpty || lineLength == 0) return const [];

  final points = <int>{0, lineLength};
  for (final s in spans) {
    if (s.start >= 0 && s.start <= lineLength) points.add(s.start);
    if (s.end >= 0 && s.end <= lineLength) points.add(s.end);
  }
  final sortedPoints = points.toList()..sort();

  final result = <RangeStyle>[];
  for (var i = 0; i < sortedPoints.length - 1; i++) {
    final start = sortedPoints[i];
    final end = sortedPoints[i + 1];
    if (start >= end) continue;

    final tokens = <SourceToken>[];
    for (final s in spans) {
      if (s.start <= start && s.end >= end) {
        if (!tokens.contains(s.token)) {
          tokens.add(s.token);
        }
      }
    }

    if (tokens.isNotEmpty) {
      result.add(RangeStyle(start, end, tokens));
    }
  }

  return result;
}
