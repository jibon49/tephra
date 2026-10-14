// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/tephra_index.dart';
import 'package:tephra_markdown/tephra_markdown.dart';

import '../../outline/outline_tree.dart';

/// Range within a note text to be embedded or transcluded.
final class EmbedSlice {
  const EmbedSlice({required this.start, required this.end});

  final int start;
  final int end;

  String substringOf(String text) => text.substring(start, end);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmbedSlice &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          end == other.end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'EmbedSlice($start, $end)';
}

/// Computes the [EmbedSlice] to transclude for a note according to [heading] or [blockRef].
///
/// - No heading/block: whole note after frontmatter to the end.
/// - Heading: section of the matching heading (including the heading line). Returns null if not found.
/// - Block: owning block range of the matching block ID (case-insensitive). Returns null if not found.
EmbedSlice? sliceForEmbed(
  String text,
  ParsedNote parsed, {
  String? heading,
  String? blockRef,
}) {
  if (heading != null && heading.isNotEmpty) {
    final headingRecords = <HeadingRecord>[];
    for (final h in parsed.headings) {
      headingRecords.add(
        HeadingRecord(
          path: VaultPath('dummy.md'),
          level: h.level,
          text: extractHeadingText(h),
          start: h.start,
          end: h.end,
          line: parsed.lines.lineOf(h.start),
          ordinal: headingRecords.length,
        ),
      );
    }

    final match = findHeading(headingRecords, heading);
    if (match == null) return null;

    final (s, e) = sectionRange(headingRecords, match, text.length);
    return EmbedSlice(start: s, end: e);
  }

  if (blockRef != null && blockRef.isNotEmpty) {
    final targetId =
        (blockRef.startsWith('^') ? blockRef.substring(1) : blockRef)
            .toLowerCase();

    BlockRef? foundRef;
    for (final ref in parsed.blockIds) {
      if (ref.id.toLowerCase() == targetId) {
        foundRef = ref;
        break;
      }
    }

    if (foundRef == null) return null;

    final owner = _findBlockOwner(foundRef, parsed);
    return EmbedSlice(start: owner.start, end: owner.end);
  }

  for (final child in parsed.root.children) {
    if (child is! MdFrontmatter) {
      return EmbedSlice(start: child.start, end: text.length);
    }
  }

  return EmbedSlice(start: 0, end: text.length);
}

({int start, int end}) _findBlockOwner(BlockRef ref, ParsedNote parsed) {
  MdListItem? listItemAncestor;
  MdNode? innermost;

  void search(MdNode node, [MdListItem? currentListItem]) {
    final nextItem = node is MdListItem ? node : currentListItem;
    if (node.start <= ref.start && node.end >= ref.end) {
      if (node is MdListItem) {
        listItemAncestor = node;
      } else if (node is MdParagraph || node is MdHeading) {
        innermost = node;
      }
      for (final child in node.children) {
        search(child, nextItem);
      }
    }
  }

  search(parsed.root);

  if (listItemAncestor != null) {
    return (start: listItemAncestor!.start, end: listItemAncestor!.end);
  }

  if (innermost != null) {
    return (start: innermost!.start, end: innermost!.end);
  }

  // Standalone on its own line directly after table, block quote, callout, or code block
  final refLine = parsed.lines.lineOf(ref.start);
  for (final node in parsed.root.children) {
    if (node is MdTable ||
        node is MdBlockQuote ||
        node is MdCallout ||
        node is MdCodeBlock) {
      final nodeEndLine = parsed.lines.lineOf(node.end);
      if (nodeEndLine == refLine - 1 || nodeEndLine == refLine) {
        return (start: node.start, end: node.end);
      }
    }
  }

  // Fallback: line containing ^id
  final lineStart = parsed.lines.lineStart(refLine);
  final lineEnd = parsed.lines.lineEnd(refLine);
  return (start: lineStart, end: lineEnd);
}
