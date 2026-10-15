// © 2026 Tephra. All rights reserved.

import 'package:tephra_markdown/tephra_markdown.dart';

import 'lp_decoration.dart';
import 'lp_options.dart';

/// Walks [parsed.root] and produces decorations with offsets `base + offset`.
List<LpDecoration> decorateChunk(
  String chunkText,
  ParsedNote parsed,
  int base,
  LpOptions options,
) {
  final decorations = <LpDecoration>[];
  final hideIntervals = <(int, int)>[];

  bool isRangeHidden(int start, int end) {
    for (final interval in hideIntervals) {
      if (start < interval.$2 && end > interval.$1) return true;
    }
    return false;
  }

  void addHide(LpHide hide) {
    if (isRangeHidden(hide.start, hide.end)) return;
    hideIntervals.add((hide.start, hide.end));
    decorations.add(hide);
  }

  // Helper for line ranges
  LpReveal lineReveal(int offset) {
    final lineNum = parsed.lines.lineOf(offset);
    final lineStart = parsed.lines.lineStart(lineNum);
    var lineEnd = (lineNum + 1 < parsed.lines.lineCount)
        ? parsed.lines.lineStart(lineNum + 1) - 1
        : chunkText.length;
    if (lineEnd > lineStart && chunkText.codeUnitAt(lineEnd - 1) == 13) {
      lineEnd--;
    }
    return LpReveal(base + lineStart, base + lineEnd);
  }

  void walk(MdNode node) {
    if (node is MdText) return;

    if (node is MdParagraph) {
      for (final child in node.children) {
        walk(child);
      }
      return;
    }

    if (node is MdHeading) {
      if (!node.isSetext) {
        // ATX heading
        var i = node.start;
        // Skip up to 3 leading spaces
        while (i < node.end && (chunkText.codeUnitAt(i) == 32)) {
          i++;
        }
        // Count # run
        while (i < node.end && chunkText.codeUnitAt(i) == 35) {
          i++;
        }
        // Skip following whitespace
        while (i < node.end &&
            (chunkText.codeUnitAt(i) == 32 || chunkText.codeUnitAt(i) == 9)) {
          i++;
        }
        final contentStart = i;

        // Check for ATX closing sequence: optional spaces followed by # run and spaces at line end
        var lineEnd = chunkText.indexOf('\n', node.start);
        if (lineEnd == -1 || lineEnd > node.end) lineEnd = node.end;
        if (lineEnd > node.start && chunkText.codeUnitAt(lineEnd - 1) == 13) {
          lineEnd--;
        }

        var closingStart = lineEnd;
        var p = lineEnd;
        while (p > contentStart &&
            (chunkText.codeUnitAt(p - 1) == 32 ||
                chunkText.codeUnitAt(p - 1) == 9)) {
          p--;
        }
        final hashEnd = p;
        while (p > contentStart && chunkText.codeUnitAt(p - 1) == 35) {
          p--;
        }
        if (p < hashEnd &&
            p > contentStart &&
            (chunkText.codeUnitAt(p - 1) == 32 ||
                chunkText.codeUnitAt(p - 1) == 9)) {
          // Valid closing sequence with space before it
          while (p > contentStart &&
              (chunkText.codeUnitAt(p - 1) == 32 ||
                  chunkText.codeUnitAt(p - 1) == 9)) {
            p--;
          }
          closingStart = p;
        }

        final hReveal = lineReveal(node.start);
        decorations.add(
          LpHide(base + node.start, base + contentStart, reveal: hReveal),
        );
        if (closingStart < lineEnd) {
          decorations.add(
            LpHide(base + closingStart, base + lineEnd, reveal: hReveal),
          );
        }
        decorations.add(
          LpStyle(
            base + contentStart,
            base + closingStart,
            LpStyleKind.heading,
            level: node.level,
          ),
        );
      } else {
        // Setext heading
        final nlIdx = chunkText.lastIndexOf('\n', node.end - 1);
        final underlineStart = nlIdx == -1 ? node.start : nlIdx + 1;
        final textEnd = nlIdx == -1 ? node.end : nlIdx;

        final startLine = parsed.lines.lineStart(
          parsed.lines.lineOf(node.start),
        );
        var endLine = node.end;
        if (endLine > startLine && chunkText.codeUnitAt(endLine - 1) == 10) {
          endLine--;
        }
        if (endLine > startLine && chunkText.codeUnitAt(endLine - 1) == 13) {
          endLine--;
        }
        final reveal = LpReveal(base + startLine, base + endLine);

        decorations.add(
          LpHide(base + underlineStart, base + node.end, reveal: reveal),
        );
        decorations.add(
          LpStyle(
            base + node.start,
            base + textEnd,
            LpStyleKind.heading,
            level: node.level,
          ),
        );
      }
      for (final child in node.children) {
        walk(child);
      }
      return;
    }

    if (node is MdStrong) {
      final reveal = LpReveal(base + node.start, base + node.end);
      decorations.add(
        LpHide(base + node.start, base + node.start + 2, reveal: reveal),
      );
      decorations.add(
        LpHide(base + node.end - 2, base + node.end, reveal: reveal),
      );
      decorations.add(
        LpStyle(base + node.start + 2, base + node.end - 2, LpStyleKind.bold),
      );
      for (final child in node.children) {
        walk(child);
      }
      return;
    }

    if (node is MdEmphasis) {
      final reveal = LpReveal(base + node.start, base + node.end);
      decorations.add(
        LpHide(base + node.start, base + node.start + 1, reveal: reveal),
      );
      decorations.add(
        LpHide(base + node.end - 1, base + node.end, reveal: reveal),
      );
      decorations.add(
        LpStyle(base + node.start + 1, base + node.end - 1, LpStyleKind.italic),
      );
      for (final child in node.children) {
        walk(child);
      }
      return;
    }

    if (node is MdStrikethrough) {
      final reveal = LpReveal(base + node.start, base + node.end);
      decorations.add(
        LpHide(base + node.start, base + node.start + 2, reveal: reveal),
      );
      decorations.add(
        LpHide(base + node.end - 2, base + node.end, reveal: reveal),
      );
      decorations.add(
        LpStyle(base + node.start + 2, base + node.end - 2, LpStyleKind.strike),
      );
      for (final child in node.children) {
        walk(child);
      }
      return;
    }

    if (node is MdHighlight) {
      final reveal = LpReveal(base + node.start, base + node.end);
      decorations.add(
        LpHide(base + node.start, base + node.start + 2, reveal: reveal),
      );
      decorations.add(
        LpHide(base + node.end - 2, base + node.end, reveal: reveal),
      );
      decorations.add(
        LpStyle(
          base + node.start + 2,
          base + node.end - 2,
          LpStyleKind.highlight,
        ),
      );
      for (final child in node.children) {
        walk(child);
      }
      return;
    }

    if (node is MdInlineCode) {
      final reveal = LpReveal(base + node.start, base + node.end);
      var n = 0;
      while (node.start + n < node.end &&
          chunkText.codeUnitAt(node.start + n) == 96) {
        n++;
      }
      decorations.add(
        LpHide(base + node.start, base + node.start + n, reveal: reveal),
      );
      decorations.add(
        LpHide(base + node.end - n, base + node.end, reveal: reveal),
      );
      decorations.add(
        LpStyle(
          base + node.start + n,
          base + node.end - n,
          LpStyleKind.inlineCode,
        ),
      );
      return;
    }

    if (node is MdWikiLink) {
      final reveal = LpReveal(base + node.start, base + node.end);
      if (node.embed) {
        decorations.add(
          LpWidget(
            base + node.start,
            base + node.end,
            LpWidgetKind.embed,
            data: {
              'target': node.target,
              'heading': node.heading,
              'blockRef': node.blockRef,
              'size': node.size != null
                  ? '${node.size!.width}x${node.size!.height}'
                  : null,
              'pdfPage': node.pdfPage,
            },
            reveal: reveal,
          ),
        );
      } else {
        decorations.add(
          LpHide(base + node.start, base + node.start + 2, reveal: reveal),
        );
        if (node.alias != null) {
          final pipeIdx = chunkText.indexOf('|', node.start + 2);
          final aliasSepEnd = (pipeIdx != -1 && pipeIdx < node.end)
              ? pipeIdx + 1
              : node.start + 2;
          decorations.add(
            LpHide(base + node.start + 2, base + aliasSepEnd, reveal: reveal),
          );
          decorations.add(
            LpHide(base + node.end - 2, base + node.end, reveal: reveal),
          );
          decorations.add(
            LpStyle(
              base + aliasSepEnd,
              base + node.end - 2,
              LpStyleKind.internalLink,
              data: node.target,
            ),
          );
        } else {
          decorations.add(
            LpHide(base + node.end - 2, base + node.end, reveal: reveal),
          );
          decorations.add(
            LpStyle(
              base + node.start + 2,
              base + node.end - 2,
              LpStyleKind.internalLink,
              data: node.target,
            ),
          );
        }
      }
      return;
    }

    if (node is MdLink) {
      final reveal = LpReveal(base + node.start, base + node.end);
      if (node.image) {
        decorations.add(
          LpWidget(
            base + node.start,
            base + node.end,
            LpWidgetKind.image,
            data: {'url': node.url, 'alt': node.title},
            reveal: reveal,
          ),
        );
      } else {
        addHide(
          LpHide(base + node.start, base + node.start + 1, reveal: reveal),
        );
        final closeBracketIdx = chunkText.indexOf('](', node.start);
        final int textEnd;
        final int hideStart;
        if (closeBracketIdx != -1 && closeBracketIdx < node.end) {
          textEnd = closeBracketIdx;
          hideStart = closeBracketIdx;
        } else {
          final refIdx = chunkText.indexOf('][', node.start);
          if (refIdx != -1 && refIdx < node.end) {
            textEnd = refIdx;
            hideStart = refIdx;
          } else {
            textEnd = node.end - 1;
            hideStart = node.end - 1;
          }
        }
        addHide(LpHide(base + hideStart, base + node.end, reveal: reveal));
        final isInternal =
            !node.url.startsWith('http://') &&
            !node.url.startsWith('https://') &&
            !node.url.startsWith('mailto:');
        if (textEnd > node.start + 1) {
          decorations.add(
            LpStyle(
              base + node.start + 1,
              base + textEnd,
              isInternal ? LpStyleKind.internalLink : LpStyleKind.externalLink,
              data: node.url,
            ),
          );
        }
        for (final child in node.children) {
          walk(child);
        }
      }
      return;
    }

    if (node is MdAutolink) {
      final reveal = LpReveal(base + node.start, base + node.end);
      final hasOpen = chunkText.codeUnitAt(node.start) == 60; // '<'
      final hasClose = chunkText.codeUnitAt(node.end - 1) == 62; // '>'
      if (hasOpen) {
        decorations.add(
          LpHide(base + node.start, base + node.start + 1, reveal: reveal),
        );
      }
      if (hasClose) {
        decorations.add(
          LpHide(base + node.end - 1, base + node.end, reveal: reveal),
        );
      }
      final s = hasOpen ? node.start + 1 : node.start;
      final e = hasClose ? node.end - 1 : node.end;
      decorations.add(
        LpStyle(base + s, base + e, LpStyleKind.externalLink, data: node.url),
      );
      return;
    }

    if (node is MdTag) {
      decorations.add(
        LpStyle(
          base + node.start,
          base + node.end,
          LpStyleKind.tag,
          data: node.name,
        ),
      );
      return;
    }

    if (node is MdBlockId) {
      decorations.add(
        LpStyle(base + node.start, base + node.end, LpStyleKind.blockId),
      );
      return;
    }

    if (node is MdFootnoteRef) {
      decorations.add(
        LpStyle(base + node.start, base + node.end, LpStyleKind.footnoteRef),
      );
      return;
    }

    if (node is MdInlineMath) {
      decorations.add(
        LpWidget(
          base + node.start,
          base + node.end,
          LpWidgetKind.inlineMath,
          data: {'tex': node.tex},
          reveal: LpReveal(base + node.start, base + node.end),
        ),
      );
      return;
    }

    if (node is MdCommentInline || node is MdCommentBlock) {
      decorations.add(
        LpStyle(base + node.start, base + node.end, LpStyleKind.comment),
      );
      return;
    }

    if (node is MdListItem) {
      if (node.task == null) {
        // Bullet replace char
        var i = node.start;
        while (i < node.end &&
            (chunkText.codeUnitAt(i) == 32 || chunkText.codeUnitAt(i) == 9)) {
          i++;
        }
        if (i < node.end) {
          final c = chunkText.codeUnitAt(i);
          if (c == 45 || c == 42 || c == 43) {
            decorations.add(LpReplaceChar(base + i, base + i + 1, '•'));
          }
        }
      } else {
        // Task list item
        var i = node.start;
        while (i < node.end &&
            (chunkText.codeUnitAt(i) == 32 || chunkText.codeUnitAt(i) == 9)) {
          i++;
        }
        final bulletStart = i;
        final boxStart = chunkText.indexOf('[', bulletStart);
        if (boxStart != -1 && boxStart + 3 <= node.end) {
          final boxEnd = boxStart + 3;
          final reveal = LpReveal(base + boxStart, base + boxEnd);
          decorations.add(
            LpHide(base + bulletStart, base + bulletStart + 1, reveal: reveal),
          );
          decorations.add(
            LpWidget(
              base + boxStart,
              base + boxEnd,
              LpWidgetKind.checkbox,
              data: {'status': node.task!.char},
              reveal: reveal,
            ),
          );
          if (node.task!.isDone) {
            var textStart = boxEnd;
            if (textStart < node.end && chunkText.codeUnitAt(textStart) == 32) {
              textStart++;
            }
            var textEnd = chunkText.indexOf('\n', textStart);
            if (textEnd == -1 || textEnd > node.end) textEnd = node.end;
            if (textEnd > textStart &&
                chunkText.codeUnitAt(textEnd - 1) == 13) {
              textEnd--;
            }
            if (textEnd > textStart) {
              decorations.add(
                LpStyle(base + textStart, base + textEnd, LpStyleKind.taskDone),
              );
            }
          }
        }
      }
      for (final child in node.children) {
        walk(child);
      }
      return;
    }

    if (node is MdBlockQuote && node is! MdCallout) {
      // Per line: hide '>' and one following space; style quoteLine
      var lineStart = node.start;
      while (lineStart < node.end) {
        var lineEnd = chunkText.indexOf('\n', lineStart);
        final nextLineStart = (lineEnd == -1) ? node.end : lineEnd + 1;
        if (lineEnd == -1 || lineEnd > node.end) lineEnd = node.end;
        if (lineEnd > lineStart && chunkText.codeUnitAt(lineEnd - 1) == 13) {
          lineEnd--;
        }

        var i = lineStart;
        while (i < lineEnd) {
          while (i < lineEnd &&
              (chunkText.codeUnitAt(i) == 32 || chunkText.codeUnitAt(i) == 9)) {
            i++;
          }
          if (i < lineEnd && chunkText.codeUnitAt(i) == 62) {
            // '>'
            final markerStart = i;
            final markerEnd =
                (i + 1 < lineEnd && chunkText.codeUnitAt(i + 1) == 32)
                ? i + 2
                : i + 1;
            if (!isRangeHidden(base + markerStart, base + markerEnd)) {
              final reveal = lineReveal(lineStart);
              addHide(
                LpHide(base + markerStart, base + markerEnd, reveal: reveal),
              );
              if (markerEnd < lineEnd) {
                decorations.add(
                  LpStyle(
                    base + markerEnd,
                    base + lineEnd,
                    LpStyleKind.quoteLine,
                  ),
                );
              }
              break;
            }
            i = markerEnd;
          } else {
            break;
          }
        }
        lineStart = nextLineStart;
      }
      for (final child in node.children) {
        walk(child);
      }
      return;
    }

    if (node is MdCallout) {
      final calloutReveal = LpReveal(base + node.start, base + node.end);
      var firstLineEnd = chunkText.indexOf('\n', node.start);
      if (firstLineEnd == -1 || firstLineEnd > node.end) {
        firstLineEnd = node.end;
      }
      var cleanFirstEnd = firstLineEnd;
      if (cleanFirstEnd > node.start &&
          chunkText.codeUnitAt(cleanFirstEnd - 1) == 13) {
        cleanFirstEnd--;
      }

      decorations.add(
        LpWidget(
          base + node.start,
          base + cleanFirstEnd,
          LpWidgetKind.calloutHeader,
          data: {
            'type': node.type,
            'title': node.title,
            'fold': node.fold.name,
          },
          reveal: calloutReveal,
        ),
      );
      decorations.add(
        LpStyle(
          base + node.start,
          base + cleanFirstEnd,
          LpStyleKind.calloutLine,
          data: node.type,
        ),
      );

      var lineStart = (firstLineEnd < node.end) ? firstLineEnd + 1 : node.end;
      while (lineStart < node.end) {
        var lineEnd = chunkText.indexOf('\n', lineStart);
        final nextLineStart = (lineEnd == -1) ? node.end : lineEnd + 1;
        if (lineEnd == -1 || lineEnd > node.end) lineEnd = node.end;
        if (lineEnd > lineStart && chunkText.codeUnitAt(lineEnd - 1) == 13) {
          lineEnd--;
        }

        var i = lineStart;
        while (i < lineEnd) {
          while (i < lineEnd &&
              (chunkText.codeUnitAt(i) == 32 || chunkText.codeUnitAt(i) == 9)) {
            i++;
          }
          if (i < lineEnd && chunkText.codeUnitAt(i) == 62) {
            // '>'
            final markerStart = i;
            final markerEnd =
                (i + 1 < lineEnd && chunkText.codeUnitAt(i + 1) == 32)
                ? i + 2
                : i + 1;
            if (!isRangeHidden(base + markerStart, base + markerEnd)) {
              addHide(
                LpHide(
                  base + markerStart,
                  base + markerEnd,
                  reveal: calloutReveal,
                ),
              );
              break;
            }
            i = markerEnd;
          } else {
            break;
          }
        }
        decorations.add(
          LpStyle(
            base + lineStart,
            base + lineEnd,
            LpStyleKind.calloutLine,
            data: node.type,
          ),
        );
        lineStart = nextLineStart;
      }

      for (final child in node.children) {
        walk(child);
      }
      return;
    }

    if (node is MdCodeBlock) {
      if (node.fenced && node.language == 'query') {
        decorations.add(
          LpWidget(
            base + node.start,
            base + node.end,
            LpWidgetKind.queryBlock,
            data: {'query': node.code},
            reveal: LpReveal(base + node.start, base + node.end),
          ),
        );
      } else {
        var lineStart = node.start;
        while (lineStart < node.end) {
          var lineEnd = chunkText.indexOf('\n', lineStart);
          final nextLineStart = (lineEnd == -1) ? node.end : lineEnd + 1;
          if (lineEnd == -1 || lineEnd > node.end) lineEnd = node.end;
          if (lineEnd > lineStart && chunkText.codeUnitAt(lineEnd - 1) == 13) {
            lineEnd--;
          }
          decorations.add(
            LpStyle(base + lineStart, base + lineEnd, LpStyleKind.codeLine),
          );
          lineStart = nextLineStart;
        }
      }
      return;
    }

    if (node is MdMathBlock) {
      decorations.add(
        LpWidget(
          base + node.start,
          base + node.end,
          LpWidgetKind.mathBlock,
          data: {'tex': node.tex},
          reveal: LpReveal(base + node.start, base + node.end),
        ),
      );
      return;
    }

    if (node is MdTable) {
      final cellRanges = <List<List<int>>>[];
      for (final row in node.children) {
        final rowCells = <List<int>>[];
        for (final cell in row.children) {
          rowCells.add([base + cell.start, base + cell.end]);
        }
        cellRanges.add(rowCells);
      }
      decorations.add(
        LpWidget(
          base + node.start,
          base + node.end,
          LpWidgetKind.table,
          data: {
            'cellRanges': cellRanges,
            'aligns': node.aligns.map((a) => a.name).toList(),
          },
          reveal: LpReveal(base + node.start, base + node.end),
        ),
      );
      return;
    }

    if (node is MdThematicBreak) {
      var lineEnd = chunkText.indexOf('\n', node.start);
      if (lineEnd == -1 || lineEnd > node.end) lineEnd = node.end;
      if (lineEnd > node.start && chunkText.codeUnitAt(lineEnd - 1) == 13) {
        lineEnd--;
      }
      final reveal = lineReveal(node.start);
      decorations.add(
        LpWidget(
          base + node.start,
          base + lineEnd,
          LpWidgetKind.horizontalRule,
          reveal: reveal,
        ),
      );
      return;
    }

    if (node is MdFrontmatter) {
      final reveal = LpReveal(base + node.start, base + node.end);
      if (options.hideFrontmatter) {
        decorations.add(
          LpHide(base + node.start, base + node.end, reveal: reveal),
        );
      } else {
        decorations.add(
          LpStyle(base + node.start, base + node.end, LpStyleKind.comment),
        );
      }
      return;
    }

    // Default: recurse on children
    for (final child in node.children) {
      walk(child);
    }
  }

  for (final child in parsed.root.children) {
    walk(child);
  }

  // Sort by start ascending, then end ascending with deterministic tie-breaker
  decorations.sort(compareDecorations);

  return decorations;
}
