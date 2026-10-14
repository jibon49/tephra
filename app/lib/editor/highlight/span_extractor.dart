// © 2026 Tephra. All rights reserved.

import 'package:tephra_markdown/tephra_markdown.dart';

import 'source_styles.dart';

/// A styled range in document UTF-16 offsets [start, end) tagged with a [SourceToken].
final class StyledSpan {
  const StyledSpan(this.start, this.end, this.token);

  final int start;
  final int end;
  final SourceToken token;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StyledSpan &&
          start == other.start &&
          end == other.end &&
          token == other.token;

  @override
  int get hashCode => Object.hash(start, end, token);

  @override
  String toString() => '($start, $end, $token)';
}

/// Extracts a pre-order list of [StyledSpan]s from a [ParsedNote] using its AST.
List<StyledSpan> extractSpans(ParsedNote parsed) {
  final spans = <StyledSpan>[];
  final text = parsed.text;

  void visit(MdNode node) {
    switch (node) {
      case MdDocument():
        for (final child in node.children) {
          visit(child);
        }

      case MdFrontmatter():
        spans.add(StyledSpan(node.start, node.end, SourceToken.frontmatter));

      case MdHeading():
        final token = switch (node.level) {
          1 => SourceToken.heading1,
          2 => SourceToken.heading2,
          3 => SourceToken.heading3,
          4 => SourceToken.heading4,
          5 => SourceToken.heading5,
          _ => SourceToken.heading6,
        };
        spans.add(StyledSpan(node.start, node.end, token));

        if (node.isSetext) {
          // Find the underline line at the end
          final slice = text.substring(node.start, node.end);
          final lastNewline = slice.lastIndexOf('\n');
          if (lastNewline != -1) {
            final underlineStart = node.start + lastNewline + 1;
            spans.add(
              StyledSpan(underlineStart, node.end, SourceToken.headingMarker),
            );
          }
        } else {
          // ATX heading: `#` run + following space
          var i = node.start;
          while (i < node.end && text[i] == '#') {
            i++;
          }
          while (i < node.end && (text[i] == ' ' || text[i] == '\t')) {
            i++;
          }
          if (i > node.start) {
            spans.add(StyledSpan(node.start, i, SourceToken.headingMarker));
          }
        }
        for (final child in node.children) {
          visit(child);
        }

      case MdParagraph():
        for (final child in node.children) {
          visit(child);
        }

      case MdStrong():
        spans.add(StyledSpan(node.start, node.end, SourceToken.strong));
        spans.add(
          StyledSpan(node.start, node.start + 2, SourceToken.emphasisMarker),
        );
        spans.add(
          StyledSpan(node.end - 2, node.end, SourceToken.emphasisMarker),
        );
        for (final child in node.children) {
          visit(child);
        }

      case MdEmphasis():
        spans.add(StyledSpan(node.start, node.end, SourceToken.emphasis));
        spans.add(
          StyledSpan(node.start, node.start + 1, SourceToken.emphasisMarker),
        );
        spans.add(
          StyledSpan(node.end - 1, node.end, SourceToken.emphasisMarker),
        );
        for (final child in node.children) {
          visit(child);
        }

      case MdStrikethrough():
        spans.add(StyledSpan(node.start, node.end, SourceToken.strikethrough));
        spans.add(
          StyledSpan(node.start, node.start + 2, SourceToken.emphasisMarker),
        );
        spans.add(
          StyledSpan(node.end - 2, node.end, SourceToken.emphasisMarker),
        );
        for (final child in node.children) {
          visit(child);
        }

      case MdHighlight():
        spans.add(StyledSpan(node.start, node.end, SourceToken.highlight));
        spans.add(
          StyledSpan(node.start, node.start + 2, SourceToken.emphasisMarker),
        );
        spans.add(
          StyledSpan(node.end - 2, node.end, SourceToken.emphasisMarker),
        );
        for (final child in node.children) {
          visit(child);
        }

      case MdInlineCode():
        spans.add(StyledSpan(node.start, node.end, SourceToken.inlineCode));
        var count = 0;
        while (node.start + count < node.end &&
            text[node.start + count] == '`') {
          count++;
        }
        if (count > 0 && node.start + count <= node.end) {
          spans.add(
            StyledSpan(
              node.start,
              node.start + count,
              SourceToken.emphasisMarker,
            ),
          );
          spans.add(
            StyledSpan(node.end - count, node.end, SourceToken.emphasisMarker),
          );
        }

      case MdWikiLink():
        spans.add(StyledSpan(node.start, node.end, SourceToken.wikiTarget));
        final leadingLen = node.embed ? 3 : 2;
        spans.add(
          StyledSpan(
            node.start,
            node.start + leadingLen,
            SourceToken.wikiBracket,
          ),
        );
        spans.add(StyledSpan(node.end - 2, node.end, SourceToken.wikiBracket));

      case MdLink():
        spans.add(StyledSpan(node.start, node.end, SourceToken.linkText));
        if (node.image) {
          spans.add(
            StyledSpan(node.start, node.start + 1, SourceToken.wikiBracket),
          );
        }
        // linkUrl is the tail: after last child (or closing bracket)
        final int tailStart;
        if (node.children.isNotEmpty) {
          tailStart = node.children.last.end;
        } else {
          final openBracket = node.image ? node.start + 1 : node.start;
          final closeBracket = text.indexOf(']', openBracket);
          tailStart = closeBracket != -1 ? closeBracket : node.start;
        }
        if (tailStart < node.end) {
          spans.add(StyledSpan(tailStart, node.end, SourceToken.linkUrl));
        }
        for (final child in node.children) {
          visit(child);
        }

      case MdAutolink():
        spans.add(StyledSpan(node.start, node.end, SourceToken.autolink));

      case MdTag():
        spans.add(StyledSpan(node.start, node.end, SourceToken.tag));

      case MdBlockId():
        spans.add(StyledSpan(node.start, node.end, SourceToken.blockId));

      case MdInlineMath():
        spans.add(StyledSpan(node.start, node.end, SourceToken.mathInline));

      case MdFootnoteRef():
        spans.add(StyledSpan(node.start, node.end, SourceToken.footnote));

      case MdInlineFootnote():
        spans.add(StyledSpan(node.start, node.end, SourceToken.footnote));
        for (final child in node.children) {
          visit(child);
        }

      case MdCommentInline():
      case MdCommentBlock():
        spans.add(StyledSpan(node.start, node.end, SourceToken.comment));

      case MdHtmlInline():
      case MdHtmlBlock():
        spans.add(StyledSpan(node.start, node.end, SourceToken.html));

      case MdCodeBlock():
        spans.add(StyledSpan(node.start, node.end, SourceToken.codeBlock));
        if (node.fenced) {
          final firstNewline = text.indexOf('\n', node.start);
          final firstLineEnd = firstNewline != -1 && firstNewline < node.end
              ? firstNewline
              : node.end;
          spans.add(
            StyledSpan(node.start, firstLineEnd, SourceToken.codeFence),
          );

          final slice = text.substring(node.start, node.end);
          final lastNewline = slice.lastIndexOf('\n');
          if (lastNewline != -1) {
            final lastLineStart = node.start + lastNewline + 1;
            if (lastLineStart < node.end) {
              spans.add(
                StyledSpan(lastLineStart, node.end, SourceToken.codeFence),
              );
            }
          }
        }

      case MdMathBlock():
        spans.add(StyledSpan(node.start, node.end, SourceToken.mathBlock));

      case MdThematicBreak():
        spans.add(StyledSpan(node.start, node.end, SourceToken.thematicBreak));

      case MdBlockQuote():
        _extractQuoteMarkers(text, node.start, node.end, spans);
        for (final child in node.children) {
          visit(child);
        }

      case MdCallout():
        _extractQuoteMarkers(text, node.start, node.end, spans);
        // First line callout marker [!type]±
        final firstNewline = text.indexOf('\n', node.start);
        final firstLineEnd = firstNewline != -1 && firstNewline < node.end
            ? firstNewline
            : node.end;
        final firstLine = text.substring(node.start, firstLineEnd);
        final openBracket = firstLine.indexOf('[');
        final closeBracket = firstLine.indexOf(']');
        if (openBracket != -1 &&
            closeBracket != -1 &&
            closeBracket > openBracket) {
          var markerEnd = closeBracket + 1;
          if (markerEnd < firstLine.length &&
              (firstLine[markerEnd] == '+' || firstLine[markerEnd] == '-')) {
            markerEnd++;
          }
          spans.add(
            StyledSpan(
              node.start + openBracket,
              node.start + markerEnd,
              SourceToken.calloutMarker,
            ),
          );
        }
        for (final child in node.children) {
          visit(child);
        }

      case MdList():
        for (final child in node.children) {
          visit(child);
        }

      case MdListItem():
        if (node.task != null) {
          final statusOffset = node.task!.offset;
          if (statusOffset > node.start && statusOffset + 2 <= node.end) {
            spans.add(
              StyledSpan(node.start, statusOffset - 1, SourceToken.listMarker),
            );
            spans.add(
              StyledSpan(
                statusOffset - 1,
                statusOffset + 2,
                SourceToken.taskBox,
              ),
            );
          }
        } else {
          final markerEnd = node.children.isNotEmpty
              ? node.children.first.start
              : node.end;
          if (markerEnd > node.start) {
            spans.add(
              StyledSpan(node.start, markerEnd, SourceToken.listMarker),
            );
          }
        }
        for (final child in node.children) {
          visit(child);
        }

      case MdTable():
        // Border spans for unescaped '|'
        for (var i = node.start; i < node.end; i++) {
          if (text[i] == '|' && (i == 0 || text[i - 1] != '\\')) {
            spans.add(StyledSpan(i, i + 1, SourceToken.tableBorder));
          }
        }
        // Headers and delimiter rows
        for (final child in node.children) {
          if (child.header) {
            for (final cell in child.children) {
              spans.add(
                StyledSpan(cell.start, cell.end, SourceToken.tableHeader),
              );
            }
          }
          visit(child);
        }

      case MdTableRow():
        for (final child in node.children) {
          visit(child);
        }

      case MdTableCell():
        for (final child in node.children) {
          visit(child);
        }

      case MdFootnoteDefinition():
        // [^label]:
        final colon = text.indexOf(']:', node.start);
        final markerEnd = colon != -1 && colon + 2 <= node.end
            ? colon + 2
            : node.start;
        if (markerEnd > node.start) {
          spans.add(StyledSpan(node.start, markerEnd, SourceToken.footnote));
        }
        for (final child in node.children) {
          visit(child);
        }

      case MdText():
      case MdHardBreak():
      case MdSoftBreak():
        break;
    }
  }

  visit(parsed.root);
  return spans;
}

void _extractQuoteMarkers(
  String text,
  int start,
  int end,
  List<StyledSpan> spans,
) {
  var lineStart = start;
  while (lineStart < end) {
    var lineEnd = text.indexOf('\n', lineStart);
    if (lineEnd == -1 || lineEnd > end) lineEnd = end;

    var i = lineStart;
    while (i < lineEnd &&
        (text[i] == ' ' || text[i] == '\t' || text[i] == '>')) {
      i++;
    }
    if (i > lineStart && text.substring(lineStart, i).contains('>')) {
      spans.add(StyledSpan(lineStart, i, SourceToken.quoteMarker));
    }

    lineStart = lineEnd + 1;
  }
}
