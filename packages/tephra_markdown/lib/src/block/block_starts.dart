// © 2026 Tephra. All rights reserved.

import '../note_models.dart';
import '../parser_options.dart';
import 'block_node.dart';
import 'html_block_rules.dart';
import 'line_cursor.dart';
import 'link_definitions.dart';
import 'list_rules.dart';
import 'table_rules.dart';

final RegExp _atxHeadingRegex = RegExp(r'^(#{1,6})(?:[ \t]+(.*)|$)');
final RegExp _footnoteStartRegex = RegExp(r'^\[\^([^\s\]]+)\]:');

/// Result of checking block starts.
sealed class BlockStartResult {}

final class MatchedStart extends BlockStartResult {
  MatchedStart(
    this.node, {
    this.isContainer = false,
    this.replaceParagraph = false,
    this.targetParent,
  });
  final BlockNode node;
  final bool isContainer;
  final bool replaceParagraph;
  final BlockNode? targetParent;
}

final class NoStart extends BlockStartResult {}

/// Tries to match a block start at [cursor].
BlockStartResult checkBlockStart({
  required LineCursor cursor,
  required BlockNode container,
  required ParserOptions options,
  required String fullText,
  required Map<String, LinkDefinition> definitions,
  bool tipIsParagraph = false,
}) {
  BlockNode? para;
  if (container.type == BlockType.paragraph && container.isOpen) {
    para = container;
  } else if (container.children.isNotEmpty &&
      container.children.last.type == BlockType.paragraph &&
      container.children.last.isOpen) {
    para = container.children.last;
  }
  final isParagraphOpen = para != null;

  // Indented code cannot start if tip is paragraph or line is blank, or indent < 4.
  // A start with indent >= 4 is never a start EXCEPT indented code.
  if (cursor.indent >= 4) {
    if (!cursor.blank && !isParagraphOpen && !tipIsParagraph) {
      final startOffset = cursor.offset;
      cursor.advanceColumns(4);
      final rawLine = cursor.rest();
      final node = BlockNode(
        type: BlockType.codeBlock,
        start: startOffset,
        end: cursor.lineEnd,
      );
      node.isFenced = false;
      node.rawLines.add(rawLine);
      return MatchedStart(node, isContainer: false);
    }
    return NoStart();
  }

  // 1. Block quote: indent <= 3 and '>'
  if (cursor.indent <= 3 && !cursor.blank) {
    final nextCu = cursor.text.codeUnitAt(cursor.nextNonSpaceOffset);
    if (nextCu == 0x3E) {
      // '>'
      final startOffset = cursor.nextNonSpaceOffset;
      cursor.advanceToNextNonSpace();
      cursor.advanceOffset(1);
      // Consume optional space or part of tab
      if (!cursor.isEol && (cursor.peek() == 0x20 || cursor.peek() == 0x09)) {
        cursor.advanceColumns(1);
      }
      final node = BlockNode(
        type: BlockType.blockQuote,
        start: startOffset,
        end: cursor.lineEnd,
      );
      return MatchedStart(node, isContainer: true);
    }
  }

  // 2. ATX heading: indent <= 3, 1-6 '#' followed by space, tab or EOL
  if (cursor.indent <= 3 && !cursor.blank) {
    final rest = cursor.text.substring(
      cursor.nextNonSpaceOffset,
      cursor.lineEnd,
    );
    final match = _atxHeadingRegex.firstMatch(rest);
    if (match != null) {
      final hashes = match.group(1)!;
      final level = hashes.length;
      final startOffset = cursor.nextNonSpaceOffset;

      var contentStart = startOffset + level;
      while (contentStart < cursor.lineEnd &&
          (cursor.text.codeUnitAt(contentStart) == 0x20 ||
              cursor.text.codeUnitAt(contentStart) == 0x09)) {
        contentStart++;
      }

      var contentEnd = cursor.lineEnd;
      while (contentEnd > contentStart &&
          (cursor.text.codeUnitAt(contentEnd - 1) == 0x20 ||
              cursor.text.codeUnitAt(contentEnd - 1) == 0x09)) {
        contentEnd--;
      }

      // Check optional closing hashes: preceded by space/tab and followed only by spaces
      var trailingHashesEnd = contentEnd;
      while (trailingHashesEnd > contentStart &&
          cursor.text.codeUnitAt(trailingHashesEnd - 1) == 0x23) {
        trailingHashesEnd--;
      }
      if (trailingHashesEnd < contentEnd) {
        // Must be preceded by space or tab or be the start
        if (trailingHashesEnd == contentStart ||
            cursor.text.codeUnitAt(trailingHashesEnd - 1) == 0x20 ||
            cursor.text.codeUnitAt(trailingHashesEnd - 1) == 0x09) {
          contentEnd = trailingHashesEnd;
          while (contentEnd > contentStart &&
              (cursor.text.codeUnitAt(contentEnd - 1) == 0x20 ||
                  cursor.text.codeUnitAt(contentEnd - 1) == 0x09)) {
            contentEnd--;
          }
        }
      }

      final node = BlockNode(
        type: BlockType.heading,
        start: startOffset,
        end: cursor.lineEnd,
      );
      node.level = level;
      node.isSetext = false;
      if (contentEnd > contentStart) {
        node.segments.add((contentStart, contentEnd));
      }
      node.isOpen = false;
      return MatchedStart(node, isContainer: false);
    }
  }

  // 3. Fenced code: indent <= 3, >= 3 '`' or '~'
  if (cursor.indent <= 3 && !cursor.blank) {
    final rest = cursor.text.substring(
      cursor.nextNonSpaceOffset,
      cursor.lineEnd,
    );
    final fenceMatch = _matchFenceOpen(rest);
    if (fenceMatch != null) {
      final node = BlockNode(
        type: BlockType.codeBlock,
        start: cursor.nextNonSpaceOffset,
        end: cursor.lineEnd,
      );
      node.isFenced = true;
      node.fenceChar = fenceMatch.char;
      node.fenceLength = fenceMatch.length;
      node.fenceIndent = cursor.indent;
      node.fenceOffset = cursor.nextNonSpaceOffset;
      node.info = fenceMatch.info;
      return MatchedStart(node, isContainer: false);
    }
  }

  // 4. Math block $$ (obsidian): cannot interrupt paragraph
  if (options.obsidian &&
      !isParagraphOpen &&
      cursor.indent <= 3 &&
      !cursor.blank) {
    final rest = cursor.text.substring(
      cursor.nextNonSpaceOffset,
      cursor.lineEnd,
    );
    if (rest.startsWith(r'$$')) {
      final inner = rest.substring(2);
      final closingIdx = inner.indexOf(r'$$');
      if (closingIdx != -1) {
        // Single-line candidate: rest after closing $$ must be blank
        final tail = inner.substring(closingIdx + 2);
        if (tail.trim().isEmpty) {
          final tex = inner.substring(0, closingIdx).trim();
          final node = BlockNode(
            type: BlockType.mathBlock,
            start: cursor.nextNonSpaceOffset,
            end: cursor.lineEnd,
          );
          node.rawLines.add(tex);
          node.isOpen = false;
          return MatchedStart(node, isContainer: false);
        }
      } else {
        // Multi-line math block
        final firstLine = inner.trim();
        final node = BlockNode(
          type: BlockType.mathBlock,
          start: cursor.nextNonSpaceOffset,
          end: cursor.lineEnd,
        );
        if (firstLine.isNotEmpty) {
          node.rawLines.add(firstLine);
        }
        return MatchedStart(node, isContainer: false);
      }
    }
  }

  // 5. Comment block %% (obsidian): cannot interrupt paragraph
  if (options.obsidian &&
      !isParagraphOpen &&
      cursor.indent <= 3 &&
      !cursor.blank) {
    final rest = cursor.text.substring(
      cursor.nextNonSpaceOffset,
      cursor.lineEnd,
    );
    if (rest.startsWith('%%')) {
      final inner = rest.substring(2);
      if (!inner.contains('%%')) {
        // Multi-line comment block
        final node = BlockNode(
          type: BlockType.commentBlock,
          start: cursor.nextNonSpaceOffset,
          end: cursor.lineEnd,
        );
        node.rawLines.add(inner);
        return MatchedStart(node, isContainer: false);
      }
    }
  }

  // 6. HTML block (types 1-7; type 7 cannot interrupt paragraph)
  final htmlType = checkHtmlBlockStart(
    cursor,
    canInterruptParagraph: !isParagraphOpen,
  );
  if (htmlType > 0) {
    final node = BlockNode(
      type: BlockType.htmlBlock,
      start: cursor.nextNonSpaceOffset,
      end: cursor.lineEnd,
    );
    node.htmlType = htmlType;
    final lineContent = cursor.text.substring(
      cursor.nextNonSpaceOffset,
      cursor.lineEnd,
    );
    node.rawLines.add(lineContent);
    if (checkHtmlBlockEnd(lineContent, htmlType)) {
      node.isOpen = false;
    }
    return MatchedStart(node, isContainer: false);
  }

  // 7. Setext heading: tip is a paragraph, indent <= 3, line is only '='s or '-'s
  if (para != null && cursor.indent <= 3 && !cursor.blank) {
    final rest = cursor.text
        .substring(cursor.nextNonSpaceOffset, cursor.lineEnd)
        .trim();
    if (_isSetextUnderline(rest)) {
      final level = rest.startsWith('=') ? 1 : 2;
      // First extract link reference definitions from paragraph
      extractLinkDefinitions(
        text: fullText,
        segments: para.segments,
        definitions: definitions,
      );
      if (para.segments.isNotEmpty) {
        para.level = level;
        para.isSetext = true;
        para.end = cursor.lineEnd;
        para.isOpen = false;
        // Turn paragraph into heading
        final heading = BlockNode(
          type: BlockType.heading,
          start: para.start,
          end: cursor.lineEnd,
        );
        heading.level = level;
        heading.isSetext = true;
        heading.segments.addAll(para.segments);
        heading.isOpen = false;
        return MatchedStart(
          heading,
          isContainer: false,
          replaceParagraph: true,
        );
      }
    }
  }

  // 8. Thematic break: indent <= 3; three or more '-', '_' or '*'
  if (cursor.indent <= 3 && !cursor.blank && isThematicBreak(cursor)) {
    final node = BlockNode(
      type: BlockType.thematicBreak,
      start: cursor.nextNonSpaceOffset,
      end: cursor.lineEnd,
    );
    node.isOpen = false;
    return MatchedStart(node, isContainer: false);
  }

  // 9. Footnote definition (obsidian): cannot interrupt paragraph
  if (options.obsidian &&
      !isParagraphOpen &&
      cursor.indent <= 3 &&
      !cursor.blank) {
    final rest = cursor.text.substring(
      cursor.nextNonSpaceOffset,
      cursor.lineEnd,
    );
    final fnMatch = _footnoteStartRegex.firstMatch(rest);
    if (fnMatch != null) {
      final label = fnMatch.group(1)!;
      final startOffset = cursor.nextNonSpaceOffset;
      cursor.advanceToNextNonSpace();
      cursor.advanceOffset(fnMatch.end);
      // Consume up to 4 columns after colon
      var spaces = 0;
      while (!cursor.isEol &&
          (cursor.peek() == 0x20 || cursor.peek() == 0x09) &&
          spaces < 4) {
        cursor.advanceColumns(1);
        spaces++;
      }

      final node = BlockNode(
        type: BlockType.footnote,
        start: startOffset,
        end: cursor.lineEnd,
      );
      node.footnoteLabel = label;
      return MatchedStart(node, isContainer: true);
    }
  }

  // 10. List item
  final listMatch = checkListMarker(
    cursor,
    canInterruptParagraph: !isParagraphOpen,
    options: options,
  );
  if (listMatch != null) {
    final itemNode = BlockNode(
      type: BlockType.listItem,
      start: listMatch.markerOffset,
      end: cursor.lineEnd,
    );
    itemNode.markerOffset = listMatch.markerOffset;
    itemNode.markerOffsetColumn = listMatch.markerOffsetColumn;
    itemNode.padding = listMatch.padding;
    itemNode.task = listMatch.task;

    // Check if container or its last child is a matching list
    BlockNode? matchingList;
    if (container.type == BlockType.list && container.isOpen) {
      if (listMatch.ordered &&
          container.ordered &&
          container.delimiter == listMatch.delimiter) {
        matchingList = container;
      } else if (!listMatch.ordered &&
          !container.ordered &&
          container.bulletChar == listMatch.bulletChar) {
        matchingList = container;
      }
    } else if (container.children.isNotEmpty) {
      final lastChild = container.children.last;
      if (lastChild.type == BlockType.list && lastChild.isOpen) {
        if (listMatch.ordered &&
            lastChild.ordered &&
            lastChild.delimiter == listMatch.delimiter) {
          matchingList = lastChild;
        } else if (!listMatch.ordered &&
            !lastChild.ordered &&
            lastChild.bulletChar == listMatch.bulletChar) {
          matchingList = lastChild;
        }
      }
    }

    if (matchingList == null) {
      final newList = BlockNode(
        type: BlockType.list,
        start: listMatch.markerOffset,
        end: cursor.lineEnd,
      );
      newList.ordered = listMatch.ordered;
      newList.bulletChar = listMatch.bulletChar;
      newList.delimiter = listMatch.delimiter;
      newList.startNumber = listMatch.startNumber;
      newList.tight = true;
      newList.addChild(itemNode);
      return MatchedStart(newList, isContainer: true);
    } else {
      return MatchedStart(
        itemNode,
        isContainer: true,
        targetParent: matchingList,
      );
    }
  }

  // 11. Indented code: handled at top of function.

  // 12. GFM table: tip is paragraph, current line is delimiter row
  if (options.gfm && para != null && !cursor.blank) {
    final lineText = cursor.text.substring(cursor.lineStart, cursor.lineEnd);
    final delimiterAligns = parseDelimiterRow(lineText, cursor.lineStart);
    if (delimiterAligns != null && para.segments.isNotEmpty) {
      // Delimiter row candidate! Check header row candidate from last segment
      final headerSeg = para.segments.last;
      final headerLine = fullText.substring(headerSeg.$1, headerSeg.$2);
      final headerCells = splitTableRow(headerLine, headerSeg.$1);

      if (headerCells.isNotEmpty &&
          headerCells.length == delimiterAligns.length) {
        // Valid table!
        final tableNode = BlockNode(
          type: BlockType.table,
          start: headerSeg.$1,
          end: cursor.lineEnd,
        );
        tableNode.aligns = delimiterAligns;
        tableNode.tableRows.add(headerCells); // header row
        tableNode.tableRowSpans.add((headerSeg.$1, headerSeg.$2));

        if (para.segments.length > 1) {
          // Earlier segments stay a paragraph
          para.segments.removeLast();
          para.isOpen = false;
          return MatchedStart(
            tableNode,
            isContainer: false,
            replaceParagraph: false,
          );
        } else {
          // Replace single-segment paragraph with table
          return MatchedStart(
            tableNode,
            isContainer: false,
            replaceParagraph: true,
          );
        }
      }
    }
  }

  return NoStart();
}

bool _isSetextUnderline(String s) {
  if (s.isEmpty) return false;
  final ch = s[0];
  if (ch != '=' && ch != '-') return false;
  for (var i = 1; i < s.length; i++) {
    if (s[i] != ch) return false;
  }
  return true;
}

final class _FenceMatch {
  _FenceMatch(this.char, this.length, this.info);
  final int char;
  final int length;
  final String info;
}

_FenceMatch? _matchFenceOpen(String s) {
  if (s.length < 3) return null;
  final ch = s.codeUnitAt(0);
  if (ch != 0x60 && ch != 0x7E) return null; // '`' or '~'

  var len = 0;
  while (len < s.length && s.codeUnitAt(len) == ch) {
    len++;
  }
  if (len < 3) return null;

  final info = s.substring(len).trim();
  if (ch == 0x60 && info.contains('`')) {
    // Backtick fence info string cannot contain backticks
    return null;
  }

  return _FenceMatch(ch, len, info);
}
