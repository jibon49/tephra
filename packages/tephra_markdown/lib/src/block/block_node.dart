// © 2026 Tephra. All rights reserved.

import '../note_models.dart';

enum BlockType {
  document,
  blockQuote,
  listItem,
  list,
  footnote,
  paragraph,
  heading,
  codeBlock,
  htmlBlock,
  thematicBreak,
  table,
  mathBlock,
  commentBlock,
}

/// Mutable builder node used during block parsing.
final class BlockNode {
  BlockNode({required this.type, required this.start, required this.end})
    : isOpen = true,
      lastLineBlank = false,
      children = [];

  final BlockType type;
  int start;
  int end;
  bool isOpen;
  bool lastLineBlank;

  BlockNode? parent;
  final List<BlockNode> children;

  // Paragraph / Heading content segments: (sourceStart, sourceEnd)
  final List<(int start, int end)> segments = [];

  // Code / Math / Comment / HTML raw string lines
  final List<String> rawLines = [];

  // CodeBlock metadata
  bool isFenced = false;
  int? fenceChar;
  int fenceLength = 0;
  int fenceOffset = 0;
  int fenceIndent = 0;
  String info = '';

  // HtmlBlock metadata
  int htmlType = 0;

  // Heading metadata
  int level = 1;
  bool isSetext = false;
  String? blockId;

  // List metadata
  bool ordered = false;
  int? bulletChar;
  int? delimiter;
  int startNumber = 1;
  bool tight = true;

  // ListItem metadata
  int markerOffset = 0;
  int markerOffsetColumn = 0;
  int padding = 0;
  TaskStatus? task;

  // Callout metadata (if blockQuote converts)
  String? calloutType;
  String? calloutTitle;
  CalloutFold calloutFold = CalloutFold.none;

  // Table metadata
  List<TableAlign> aligns = [];
  final List<List<(int start, int end)>> tableRows = [];

  // Footnote metadata
  String footnoteLabel = '';

  bool get isLeaf =>
      type == BlockType.paragraph ||
      type == BlockType.heading ||
      type == BlockType.codeBlock ||
      type == BlockType.htmlBlock ||
      type == BlockType.thematicBreak ||
      type == BlockType.table ||
      type == BlockType.mathBlock ||
      type == BlockType.commentBlock;

  bool get isContainer => !isLeaf;

  void addChild(BlockNode child) {
    child.parent = this;
    children.add(child);
  }

  void updateEnd(int newEnd) {
    if (newEnd > end) {
      end = newEnd;
    }
    parent?.updateEnd(newEnd);
  }

  /// Implements CommonMark endsWithBlankLine recursion.
  bool endsWithBlankLine() {
    if (children.isNotEmpty) {
      return children.last.endsWithBlankLine();
    }
    if (type == BlockType.codeBlock) {
      return false;
    }
    return lastLineBlank;
  }
}
