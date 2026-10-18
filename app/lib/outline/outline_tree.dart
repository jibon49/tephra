// © 2026 Tephra. All rights reserved.

import 'package:tephra_markdown/tephra_markdown.dart';

/// Represents a single node in the document outline tree.
final class OutlineNode {
  OutlineNode({
    required this.heading,
    required this.text,
    this.headingIndex = -1,
    this.depth = 0,
    List<OutlineNode>? children,
  }) : children = children ?? [];

  /// The underlying Markdown heading AST node.
  final MdHeading heading;

  /// Visible plain-text content of the heading.
  final String text;

  /// 0-based index of this heading in the document's [ParsedNote.headings] list.
  final int headingIndex;

  /// Depth in the outline tree (0 for root headings).
  final int depth;

  /// Child headings nested under this heading.
  final List<OutlineNode> children;
}

/// Builds an outline hierarchy from a document's list of [headings].
///
/// Parent = nearest previous heading with a lower level.
/// A heading with no such previous heading is a root (e.g. `### A` before any `#` is a root).
List<OutlineNode> buildOutline(List<MdHeading> headings) {
  final roots = <OutlineNode>[];
  final stack = <OutlineNode>[];

  for (var i = 0; i < headings.length; i++) {
    final heading = headings[i];
    final text = extractHeadingText(heading);

    while (stack.isNotEmpty && stack.last.heading.level >= heading.level) {
      stack.removeLast();
    }

    final depth = stack.length;
    final node = OutlineNode(
      heading: heading,
      text: text,
      headingIndex: i,
      depth: depth,
    );

    if (stack.isEmpty) {
      roots.add(node);
    } else {
      stack.last.children.add(node);
    }

    stack.add(node);
  }

  return roots;
}

/// Extracts plain-text representation from an [MdHeading]'s inline children.
String extractHeadingText(MdHeading h) {
  final buffer = StringBuffer();
  for (final child in h.children) {
    if (child is MdBlockId) continue;
    buffer.write(_visibleText(child));
  }
  return buffer.toString().trim();
}

String _visibleText(MdNode node) {
  if (node is MdBlockId) return '';
  if (node is MdText) return node.text;
  if (node is MdInlineCode) return node.code;
  if (node is MdInlineMath) return node.tex;
  if (node is MdWikiLink) return node.alias ?? node.target;
  if (node is MdTag) return '#${node.name}';
  if (node.children.isNotEmpty) {
    return node.children.map(_visibleText).join();
  }
  return '';
}
