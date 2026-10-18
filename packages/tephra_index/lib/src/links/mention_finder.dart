// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_markdown/tephra_markdown.dart';

import '../model/unlinked_mention.dart';
import '../util/snippet.dart';

bool _overlaps(int start, int end, List<(int, int)> ranges) {
  for (final (rStart, rEnd) in ranges) {
    if (start < rEnd && end > rStart) {
      return true;
    }
  }
  return false;
}

void _collectExcludedRanges(MdNode node, List<(int, int)> ranges) {
  if (node is MdWikiLink ||
      node is MdLink ||
      node is MdAutolink ||
      node is MdInlineCode ||
      node is MdCodeBlock ||
      node is MdFrontmatter ||
      node is MdCommentInline ||
      node is MdCommentBlock ||
      node is MdInlineMath ||
      node is MdMathBlock ||
      node is MdTag ||
      node is MdHtmlInline ||
      node is MdHtmlBlock) {
    ranges.add((node.start, node.end));
    return;
  }
  for (final child in node.children) {
    _collectExcludedRanges(child, ranges);
  }
}

/// Finds whole-word, case-insensitive occurrences of [terms] in [text]
/// outside links, code, frontmatter, comments, math, tags and HTML.
List<UnlinkedMention> findMentions(
  VaultPath source,
  String text,
  List<String> terms,
) {
  if (terms.isEmpty || text.isEmpty) return const [];

  final parsed = MarkdownParser.parse(text);
  final excludedRanges = <(int, int)>[];
  _collectExcludedRanges(parsed.root, excludedRanges);

  final sortedTerms = terms.toList()
    ..sort((a, b) => b.length.compareTo(a.length));

  final keptRanges = <(int, int)>[];
  final candidates = <(int, int)>[];

  for (final term in sortedTerms) {
    if (term.trim().isEmpty) continue;
    final pattern = RegExp(
      '(?<![\\p{L}\\p{N}\\p{M}_])${RegExp.escape(term)}(?![\\p{L}\\p{N}\\p{M}_])',
      caseSensitive: false,
      unicode: true,
    );

    for (final match in pattern.allMatches(text)) {
      final start = match.start;
      final end = match.end;

      if (_overlaps(start, end, excludedRanges)) continue;
      if (_overlaps(start, end, keptRanges)) continue;

      keptRanges.add((start, end));
      candidates.add((start, end));
    }
  }

  candidates.sort((a, b) => a.$1.compareTo(b.$1));

  final lines = parsed.lines;
  final mentions = <UnlinkedMention>[];

  for (final (start, end) in candidates) {
    final line = lines.lineOf(start);
    final lStart = lines.lineStart(line);
    final lEnd = lines.lineEnd(line);
    var lineStr = text.substring(lStart, lEnd);
    if (lineStr.endsWith('\r')) {
      lineStr = lineStr.substring(0, lineStr.length - 1);
    }
    final mStartInLine = start - lStart;
    final mEndInLine = end - lStart;
    final snippet = makeSnippet(lineStr, mStartInLine, mEndInLine);

    mentions.add(
      UnlinkedMention(
        source: source,
        start: start,
        end: end,
        line: line,
        matchedText: text.substring(start, end),
        snippet: snippet.text,
        snippetStart: snippet.start,
        snippetEnd: snippet.end,
      ),
    );
  }

  return mentions;
}
