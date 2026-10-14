// © 2026 Tephra. All rights reserved.

import '../frontmatter.dart';
import '../line_index.dart';
import '../nodes.dart';
import '../note_models.dart';
import '../parser_options.dart';
import 'block_node.dart';
import 'block_starts.dart';
import 'finalize.dart';
import 'html_block_rules.dart';
import 'line_cursor.dart';
import 'table_rules.dart';

/// The result of running the block-level parser.
final class BlockParseResult {
  BlockParseResult({
    required this.root,
    required this.definitions,
    required this.blockIds,
    this.frontmatter,
  });

  final MdDocument root;
  final Map<String, LinkDefinition> definitions;
  final List<BlockRef> blockIds;
  final FrontmatterSplit? frontmatter;
}

/// Parses [text] into block AST nodes and extracts definitions and block IDs.
BlockParseResult parseBlocks(
  String text, {
  ParserOptions options = const ParserOptions(),
}) {
  FrontmatterSplit? frontmatter;
  var startOffset = 0;

  if (options.obsidian) {
    frontmatter = splitFrontmatter(text);
    if (frontmatter != null) {
      startOffset = frontmatter.bodyStart;
    }
  }

  final lineIndex = LineIndex(text);
  final lineCount = lineIndex.lineCount;
  final numLines = text.endsWith('\n') ? lineCount - 1 : lineCount;
  final startLine = startOffset >= text.length
      ? numLines
      : (startOffset == 0 ? 0 : lineIndex.lineOf(startOffset));

  final root = BlockNode(type: BlockType.document, start: 0, end: text.length);

  final definitions = <String, LinkDefinition>{};
  final blockIds = <BlockRef>[];

  for (var line = startLine; line < numLines; line++) {
    final lineStart = lineIndex.lineStart(line);
    final lineEnd = lineIndex.lineEnd(line);
    final cursor = LineCursor(text, lineStart, lineEnd);

    _processLine(
      root: root,
      cursor: cursor,
      options: options,
      fullText: text,
      definitions: definitions,
    );
  }

  // Close all remaining open blocks
  _closeAll(root);

  final doc = finalizeTree(
    root: root,
    fullText: text,
    options: options,
    definitions: definitions,
    blockIds: blockIds,
    frontmatter: frontmatter,
  );

  return BlockParseResult(
    root: doc,
    definitions: definitions,
    blockIds: blockIds,
    frontmatter: frontmatter,
  );
}

void _processLine({
  required BlockNode root,
  required LineCursor cursor,
  required ParserOptions options,
  required String fullText,
  required Map<String, LinkDefinition> definitions,
}) {
  // Set lastLineBlank on all currently open blocks if line is blank
  if (cursor.blank) {
    _updateLastLineBlank(_getOpenChain(root), true);
  }

  // 1. Try to continue open blocks from root down to deepest open descendant.
  final chain = _getOpenChain(root);
  var lastMatchedIdx = 0; // root (document) always matches
  var allMatched = true;

  for (var i = 1; i < chain.length; i++) {
    final block = chain[i];
    final res = _continueBlock(block, cursor, options);
    if (res == _ContinueResult.matched) {
      lastMatchedIdx = i;
    } else if (res == _ContinueResult.closed) {
      _closeAll(block);
      _updateLastLineBlank(_getOpenChain(root), cursor.blank);
      return;
    } else {
      allMatched = false;
      break;
    }
  }

  var container = chain[lastMatchedIdx];
  final tip = chain.last;

  // 2. Check if tip is a leaf that consumes the raw line directly (fenced code, html, math, comment).
  final tipIsRaw =
      tip.isOpen &&
      (tip.type == BlockType.codeBlock ||
          tip.type == BlockType.htmlBlock ||
          tip.type == BlockType.mathBlock ||
          tip.type == BlockType.commentBlock);

  if (tipIsRaw && allMatched) {
    _addLineToLeaf(tip, cursor, fullText);
    _updateLastLineBlank(chain, cursor.blank);
    return;
  }

  // 3. Try block starts loop.
  var startMatched = false;
  var leafStarted = false;

  while (true) {
    final containerTip = _deepestOpen(container);
    final res = checkBlockStart(
      cursor: cursor,
      container: container,
      options: options,
      fullText: fullText,
      definitions: definitions,
      tipIsParagraph: tip.isOpen && tip.type == BlockType.paragraph,
    );

    if (res is MatchedStart) {
      startMatched = true;
      if (res.replaceParagraph) {
        // e.g. setext heading or table replacing single-segment paragraph
        _replaceChild(containerTip.parent ?? container, containerTip, res.node);
        leafStarted = true;
        break;
      }

      var target = res.targetParent ?? container;
      while (target.type == BlockType.list &&
          res.node.type != BlockType.listItem) {
        _closeAll(target);
        target = target.parent ?? root;
      }
      while (target.type == BlockType.paragraph) {
        _closeAll(target);
        target = target.parent ?? root;
      }
      // Close open blocks deeper than target
      _closeDeeperThan(root, target);

      target.addChild(res.node);
      res.node.updateEnd(cursor.lineEnd);

      if (res.isContainer) {
        container = _deepestOpen(res.node);
        // Continue loop to see if nested container or leaf starts inside
      } else {
        leafStarted = true;
        break;
      }
    } else {
      break;
    }
  }

  // 4. After block starts:
  if (!leafStarted) {
    // Check lazy continuation:
    // If not all matched, and no block start matched, and tip was a paragraph, and line is not blank.
    if (!allMatched &&
        !startMatched &&
        tip.isOpen &&
        tip.type == BlockType.paragraph &&
        !cursor.blank) {
      // Lazy paragraph continuation: add line to that paragraph!
      cursor.advanceToNextNonSpace();
      tip.segments.add((cursor.offset, cursor.lineEnd));
      tip.updateEnd(cursor.lineEnd);
    } else {
      // Close unmatched blocks
      _closeDeeperThan(root, container);

      final curTip = _deepestOpen(container);
      if (curTip.isOpen && curTip.type == BlockType.table) {
        if (!cursor.blank) {
          _addTableRow(curTip, cursor);
        } else {
          curTip.isOpen = false;
        }
      } else if (curTip.isOpen &&
          (curTip.type == BlockType.codeBlock ||
              curTip.type == BlockType.htmlBlock ||
              curTip.type == BlockType.mathBlock ||
              curTip.type == BlockType.commentBlock)) {
        _addLineToLeaf(curTip, cursor, fullText);
      } else if (!cursor.blank) {
        if (curTip.isOpen && curTip.type == BlockType.paragraph) {
          cursor.advanceToNextNonSpace();
          curTip.segments.add((cursor.offset, cursor.lineEnd));
          curTip.updateEnd(cursor.lineEnd);
        } else {
          // Start paragraph
          cursor.advanceToNextNonSpace();
          final para = BlockNode(
            type: BlockType.paragraph,
            start: cursor.offset,
            end: cursor.lineEnd,
          );
          para.segments.add((cursor.offset, cursor.lineEnd));
          curTip.addChild(para);
        }
      }
    }
  }

  // 5. Update lastLineBlank
  final finalChain = _getOpenChain(root);
  _updateLastLineBlank(finalChain, cursor.blank);
}

enum _ContinueResult { matched, notMatched, closed }

_ContinueResult _continueBlock(
  BlockNode block,
  LineCursor cursor,
  ParserOptions options,
) {
  switch (block.type) {
    case BlockType.document:
      return _ContinueResult.matched;

    case BlockType.blockQuote:
      if (cursor.indent <= 3 &&
          !cursor.blank &&
          cursor.text.codeUnitAt(cursor.nextNonSpaceOffset) == 0x3E) {
        cursor.advanceToNextNonSpace();
        cursor.advanceOffset(1); // consume '>'
        if (!cursor.isEol && (cursor.peek() == 0x20 || cursor.peek() == 0x09)) {
          cursor.advanceColumns(1);
        }
        return _ContinueResult.matched;
      }
      return _ContinueResult.notMatched;

    case BlockType.list:
      return _ContinueResult.matched;

    case BlockType.listItem:
      if (cursor.blank) {
        if (block.children.isEmpty) {
          return _ContinueResult.notMatched;
        }
        return _ContinueResult.matched;
      }
      // Content column is markerOffsetColumn + padding
      final requiredCol =
          block.markerOffsetColumn + (block.markerLength + block.padding);
      final neededIndent = requiredCol - cursor.column;
      if (neededIndent <= 0 || cursor.indent >= neededIndent) {
        if (neededIndent > 0) {
          cursor.advanceColumns(neededIndent);
        }
        return _ContinueResult.matched;
      }
      return _ContinueResult.notMatched;

    case BlockType.footnote:
      if (cursor.blank) {
        return _ContinueResult.matched;
      }
      if (cursor.indent >= 4) {
        cursor.advanceColumns(4);
        return _ContinueResult.matched;
      }
      return _ContinueResult.notMatched;

    case BlockType.codeBlock:
      if (block.isFenced) {
        // Check closing fence
        if (cursor.indent <= 3 && !cursor.blank) {
          final rest = cursor.text
              .substring(cursor.nextNonSpaceOffset, cursor.lineEnd)
              .trim();
          final fenceChar = block.fenceChar!;
          final fenceLen = block.fenceLength;
          var len = 0;
          while (len < rest.length && rest.codeUnitAt(len) == fenceChar) {
            len++;
          }
          if (len >= fenceLen && len == rest.length) {
            block.updateEnd(cursor.lineEnd);
            return _ContinueResult.closed;
          }
        }
        var toConsume = block.fenceIndent;
        while (toConsume > 0 && !cursor.isEol && cursor.peek() == 0x20) {
          cursor.advanceColumns(1);
          toConsume--;
        }
        return _ContinueResult.matched;
      } else {
        // Indented code
        if (cursor.indent >= 4) {
          cursor.advanceColumns(4);
          return _ContinueResult.matched;
        } else if (cursor.blank) {
          cursor.advanceToNextNonSpace();
          return _ContinueResult.matched;
        } else {
          return _ContinueResult.notMatched;
        }
      }

    case BlockType.htmlBlock:
      if (block.htmlType >= 1 && block.htmlType <= 5) {
        return _ContinueResult.matched;
      } else {
        if (cursor.blank) {
          return _ContinueResult.notMatched;
        }
        return _ContinueResult.matched;
      }

    case BlockType.paragraph:
      if (cursor.blank) {
        return _ContinueResult.notMatched;
      }
      return _ContinueResult.matched;

    case BlockType.table:
      if (cursor.blank) {
        return _ContinueResult.notMatched;
      }
      return _ContinueResult.matched;

    case BlockType.mathBlock:
    case BlockType.commentBlock:
      return _ContinueResult.matched;

    case BlockType.heading:
    case BlockType.thematicBreak:
      return _ContinueResult.notMatched;
  }
}

void _addLineToLeaf(BlockNode leaf, LineCursor cursor, String fullText) {
  switch (leaf.type) {
    case BlockType.codeBlock:
      leaf.rawLines.add(cursor.rest());
      if (!cursor.blank || leaf.isFenced) {
        leaf.updateEnd(cursor.lineEnd);
      }

    case BlockType.htmlBlock:
      final lineContent = cursor.text.substring(cursor.offset, cursor.lineEnd);
      leaf.rawLines.add(lineContent);
      leaf.updateEnd(cursor.lineEnd);
      if (checkHtmlBlockEnd(lineContent, leaf.htmlType)) {
        leaf.isOpen = false;
      }

    case BlockType.mathBlock:
      final line = cursor.text.substring(cursor.offset, cursor.lineEnd);
      if (line.contains(r'$$')) {
        final idx = line.indexOf(r'$$');
        final before = line.substring(0, idx).trim();
        if (before.isNotEmpty) {
          leaf.rawLines.add(before);
        }
        leaf.updateEnd(cursor.lineEnd);
        leaf.isOpen = false;
      } else {
        leaf.rawLines.add(line);
        leaf.updateEnd(cursor.lineEnd);
      }

    case BlockType.commentBlock:
      final line = cursor.text.substring(cursor.offset, cursor.lineEnd);
      if (line.contains('%%')) {
        final idx = line.indexOf('%%');
        final before = line.substring(0, idx);
        leaf.rawLines.add(before);
        leaf.updateEnd(cursor.lineEnd);
        leaf.isOpen = false;
      } else {
        leaf.rawLines.add(line);
        leaf.updateEnd(cursor.lineEnd);
      }

    default:
      break;
  }
}

void _addTableRow(BlockNode table, LineCursor cursor) {
  final line = cursor.text.substring(cursor.lineStart, cursor.lineEnd);
  final headerCount = table.tableRows.first.length;
  var cells = splitTableRow(line, cursor.lineStart);
  if (cells.length < headerCount) {
    final padded = List<(int, int)>.from(cells);
    while (padded.length < headerCount) {
      padded.add((cursor.lineEnd, cursor.lineEnd));
    }
    cells = padded;
  } else if (cells.length > headerCount) {
    cells = cells.sublist(0, headerCount);
  }
  table.tableRows.add(cells);
  table.tableRowSpans.add((cursor.lineStart, cursor.lineEnd));
  table.updateEnd(cursor.lineEnd);
}

List<BlockNode> _getOpenChain(BlockNode root) {
  final chain = <BlockNode>[root];
  var cur = root;
  while (cur.children.isNotEmpty && cur.children.last.isOpen) {
    cur = cur.children.last;
    chain.add(cur);
  }
  return chain;
}

BlockNode _deepestOpen(BlockNode node) {
  var cur = node;
  while (cur.children.isNotEmpty && cur.children.last.isOpen) {
    cur = cur.children.last;
  }
  return cur;
}

void _closeAll(BlockNode node) {
  for (final c in node.children.reversed) {
    if (c.isOpen) _closeAll(c);
  }
  node.isOpen = false;
}

void _closeDeeperThan(BlockNode root, BlockNode container) {
  final chain = _getOpenChain(root);
  final idx = chain.indexOf(container);
  if (idx != -1 && idx < chain.length - 1) {
    for (var i = chain.length - 1; i > idx; i--) {
      _closeAll(chain[i]);
    }
  }
}

void _replaceChild(BlockNode parent, BlockNode oldChild, BlockNode newChild) {
  final idx = parent.children.indexOf(oldChild);
  if (idx != -1) {
    parent.children[idx] = newChild;
    newChild.parent = parent;
  } else {
    parent.addChild(newChild);
  }
}

void _updateLastLineBlank(List<BlockNode> chain, bool isBlank) {
  for (final b in chain) {
    b.lastLineBlank = isBlank;
  }
}

extension on BlockNode {
  int get markerLength {
    if (ordered) {
      return '$startNumber'.length + 1; // e.g. "1." -> length 2
    }
    return 1; // e.g. "-"
  }
}
