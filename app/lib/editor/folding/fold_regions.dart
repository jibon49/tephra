// © 2026 Tephra. All rights reserved.

import 'package:tephra_markdown/tephra_markdown.dart';

/// The kind of foldable syntactic construct.
enum FoldKind { heading, list }

/// A collapsible region in the document.
final class FoldRegion {
  const FoldRegion({
    required this.kind,
    required this.headerStart,
    required this.from,
    required this.to,
    required this.level,
  });

  /// The syntactic kind of the region (heading or list item).
  final FoldKind kind;

  /// Start offset of the header line in UTF-16 code units.
  final int headerStart;

  /// End of the header line (offset of its newline) where folding begins.
  final int from;

  /// End of the last content line (no trailing newline) included in the fold.
  final int to;

  /// Level of the region (1..6 for headings, nesting depth for lists).
  final int level;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FoldRegion &&
          kind == other.kind &&
          headerStart == other.headerStart &&
          from == other.from &&
          to == other.to &&
          level == other.level;

  @override
  int get hashCode => Object.hash(kind, headerStart, from, to, level);

  @override
  String toString() =>
      'FoldRegion($kind, headerStart: $headerStart, from: $from, to: $to, level: $level)';
}

/// Pure function computing all foldable heading and list regions for [text] and [parsed].
///
/// Frontmatter, code blocks, and tables are never foldable.
List<FoldRegion> computeFoldRegions(
  String text,
  ParsedNote parsed, {
  bool headings = true,
  bool lists = true,
}) {
  final regions = <FoldRegion>[];

  if (headings && parsed.headings.isNotEmpty) {
    for (var i = 0; i < parsed.headings.length; i++) {
      final h = parsed.headings[i];
      final headerStart = h.start;
      final headerLine = parsed.lines.lineOf(headerStart);
      final from = parsed.lines.lineEnd(headerLine);

      // Find the next heading with level <= h.level.
      var nextHeadingStart = text.length;
      for (var j = i + 1; j < parsed.headings.length; j++) {
        final nextH = parsed.headings[j];
        if (nextH.level <= h.level) {
          nextHeadingStart = nextH.start;
          break;
        }
      }

      var to = nextHeadingStart;
      if (to > 0 && text[to - 1] == '\n') {
        to--;
        if (to > 0 && text[to - 1] == '\r') {
          to--;
        }
      }

      // Move `to` back over trailing blank lines.
      while (to > from) {
        final lineOfTo = parsed.lines.lineOf(to);
        final lStart = parsed.lines.lineStart(lineOfTo);
        final lEnd = parsed.lines.lineEnd(lineOfTo);

        if (text.substring(lStart, lEnd).trim().isEmpty) {
          if (lineOfTo == 0) break;
          to = parsed.lines.lineEnd(lineOfTo - 1);
        } else {
          to = lEnd;
          break;
        }
      }

      if (to > from) {
        regions.add(
          FoldRegion(
            kind: FoldKind.heading,
            headerStart: headerStart,
            from: from,
            to: to,
            level: h.level,
          ),
        );
      }
    }
  }

  if (lists) {
    void visitLists(MdNode node, int depth) {
      if (node is MdList) {
        for (final child in node.children) {
          final headerStart = child.start;
          final headerLine = parsed.lines.lineOf(headerStart);
          final from = parsed.lines.lineEnd(headerLine);

          var to = child.end;
          while (to > from && (text[to - 1] == '\n' || text[to - 1] == '\r')) {
            to--;
          }

          while (to > from) {
            final lineOfTo = parsed.lines.lineOf(to);
            if (lineOfTo == headerLine) break;
            final lStart = parsed.lines.lineStart(lineOfTo);
            final lEnd = parsed.lines.lineEnd(lineOfTo);

            if (text.substring(lStart, lEnd).trim().isEmpty) {
              if (lineOfTo == 0) break;
              to = parsed.lines.lineEnd(lineOfTo - 1);
            } else {
              to = lEnd;
              break;
            }
          }

          if (to > from) {
            regions.add(
              FoldRegion(
                kind: FoldKind.list,
                headerStart: headerStart,
                from: from,
                to: to,
                level: depth,
              ),
            );
          }

          for (final grandChild in child.children) {
            visitLists(grandChild, depth + 1);
          }
        }
      } else {
        for (final c in node.children) {
          visitLists(c, depth);
        }
      }
    }

    visitLists(parsed.root, 1);
  }

  regions.sort((a, b) => a.headerStart.compareTo(b.headerStart));
  return regions;
}
