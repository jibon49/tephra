// © 2026 Tephra. All rights reserved.

import 'dart:math';

import 'package:tephra_index/tephra_index.dart';
import 'package:tephra_markdown/tephra_markdown.dart';

enum BlockKind { paragraph, listItem, quote, callout, table, code, math }

final class BlockCandidate {
  const BlockCandidate({
    required this.start,
    required this.end,
    required this.line,
    required this.kind,
    this.existingId,
    required this.preview,
  });

  final int start;
  final int end;
  final int line;
  final BlockKind kind;
  final String? existingId;
  final String preview;

  @override
  String toString() =>
      'BlockCandidate($kind, line: $line, id: $existingId, preview: "$preview")';
}

/// Lists all candidate blocks in [parsed] suitable for Obsidian block linking.
List<BlockCandidate> listBlockCandidates(String text, ParsedNote parsed) {
  final candidates = <BlockCandidate>[];

  // Map candidate starts to existing block ids
  final blockOwnerStarts = <int, String>{};
  for (final ref in parsed.blockIds) {
    final owner = _findBlockOwner(ref, parsed);
    blockOwnerStarts[owner.start] = ref.id;
  }

  void processNode(
    MdNode node, {
    bool insideListItem = false,
    bool insideQuote = false,
    bool insideCallout = false,
  }) {
    if (node is MdParagraph) {
      if (!insideListItem && !insideQuote && !insideCallout) {
        final content = text.substring(node.start, node.end).trim();
        if (content.isNotEmpty) {
          final line = parsed.lines.lineOf(node.start);
          final existingId = blockOwnerStarts[node.start];
          final preview = _makePreview(text.substring(node.start, node.end));
          candidates.add(
            BlockCandidate(
              start: node.start,
              end: node.end,
              line: line,
              kind: BlockKind.paragraph,
              existingId: existingId,
              preview: preview,
            ),
          );
        }
      }
      return;
    }

    if (node is MdListItem) {
      // Range is the item's own first paragraph only
      var end = node.end;
      for (final child in node.children) {
        if (child is MdParagraph) {
          end = child.end;
          break;
        }
      }
      final line = parsed.lines.lineOf(node.start);
      final existingId = blockOwnerStarts[node.start];
      final preview = _makePreview(text.substring(node.start, end));
      candidates.add(
        BlockCandidate(
          start: node.start,
          end: end,
          line: line,
          kind: BlockKind.listItem,
          existingId: existingId,
          preview: preview,
        ),
      );

      for (final child in node.children) {
        processNode(
          child,
          insideListItem: true,
          insideQuote: insideQuote,
          insideCallout: insideCallout,
        );
      }
      return;
    }

    if (node is MdCallout) {
      final line = parsed.lines.lineOf(node.start);
      final existingId = blockOwnerStarts[node.start];
      final preview = _makePreview(text.substring(node.start, node.end));
      candidates.add(
        BlockCandidate(
          start: node.start,
          end: node.end,
          line: line,
          kind: BlockKind.callout,
          existingId: existingId,
          preview: preview,
        ),
      );
      // Children inside callout are not top-level block candidates
      for (final child in node.children) {
        processNode(
          child,
          insideListItem: insideListItem,
          insideQuote: insideQuote,
          insideCallout: true,
        );
      }
      return;
    }

    if (node is MdBlockQuote) {
      final line = parsed.lines.lineOf(node.start);
      final existingId = blockOwnerStarts[node.start];
      final preview = _makePreview(text.substring(node.start, node.end));
      candidates.add(
        BlockCandidate(
          start: node.start,
          end: node.end,
          line: line,
          kind: BlockKind.quote,
          existingId: existingId,
          preview: preview,
        ),
      );
      for (final child in node.children) {
        processNode(
          child,
          insideListItem: insideListItem,
          insideQuote: true,
          insideCallout: insideCallout,
        );
      }
      return;
    }

    if (node is MdTable) {
      final line = parsed.lines.lineOf(node.start);
      final existingId = blockOwnerStarts[node.start];
      final preview = _makePreview(text.substring(node.start, node.end));
      candidates.add(
        BlockCandidate(
          start: node.start,
          end: node.end,
          line: line,
          kind: BlockKind.table,
          existingId: existingId,
          preview: preview,
        ),
      );
      return;
    }

    if (node is MdCodeBlock) {
      final line = parsed.lines.lineOf(node.start);
      final existingId = blockOwnerStarts[node.start];
      final preview = _makePreview(text.substring(node.start, node.end));
      candidates.add(
        BlockCandidate(
          start: node.start,
          end: node.end,
          line: line,
          kind: BlockKind.code,
          existingId: existingId,
          preview: preview,
        ),
      );
      return;
    }

    if (node is MdMathBlock) {
      final line = parsed.lines.lineOf(node.start);
      final existingId = blockOwnerStarts[node.start];
      final preview = _makePreview(text.substring(node.start, node.end));
      candidates.add(
        BlockCandidate(
          start: node.start,
          end: node.end,
          line: line,
          kind: BlockKind.math,
          existingId: existingId,
          preview: preview,
        ),
      );
      return;
    }

    for (final child in node.children) {
      processNode(
        child,
        insideListItem: insideListItem,
        insideQuote: insideQuote,
        insideCallout: insideCallout,
      );
    }
  }

  processNode(parsed.root);
  return candidates;
}

String _makePreview(String raw) {
  // Replace ^id if present
  var s = raw.replaceAll(RegExp(r'\^[a-zA-Z0-9_\-]+'), '');
  // Replace newlines with spaces
  s = s.replaceAll(RegExp(r'\r?\n'), ' ').trim();
  if (s.length > 120) {
    s = s.substring(0, 120);
  }
  return s;
}

({int start, int end}) _findBlockOwner(BlockRef ref, ParsedNote parsed) {
  MdNode? innermost;
  void search(MdNode node) {
    if (node.start <= ref.start && node.end >= ref.end) {
      if (node is MdParagraph || node is MdListItem || node is MdHeading) {
        innermost = node;
      }
      for (final child in node.children) {
        search(child);
      }
    }
  }

  search(parsed.root);
  if (innermost != null) {
    return (start: innermost!.start, end: innermost!.end);
  }

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

  final lineStart = parsed.lines.lineStart(refLine);
  final lineEnd = parsed.lines.lineEnd(refLine);
  return (start: lineStart, end: lineEnd);
}

/// Generates a random alphanumeric block ID of length 6 (or 7 after 20 clashes).
String generateBlockId(Random rng, Set<String> takenLowercase) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  var clashes = 0;
  while (true) {
    final len = clashes >= 20 ? 7 : 6;
    final sb = StringBuffer();
    for (var i = 0; i < len; i++) {
      sb.write(chars[rng.nextInt(chars.length)]);
    }
    final id = sb.toString();
    if (!takenLowercase.contains(id.toLowerCase())) {
      return id;
    }
    clashes++;
  }
}

/// Builds the [TextEdit] needed to append `^$id` to [c] in [text].
TextEdit blockIdEdit(String text, BlockCandidate c, String id) {
  var e = c.end;
  while (e > c.start &&
      (text.codeUnitAt(e - 1) == 0x0A ||
          text.codeUnitAt(e - 1) == 0x20 ||
          text.codeUnitAt(e - 1) == 0x09)) {
    e--;
  }

  switch (c.kind) {
    case BlockKind.paragraph:
    case BlockKind.listItem:
    case BlockKind.quote:
    case BlockKind.callout:
      return TextEdit(e, e, ' ^$id');
    case BlockKind.table:
    case BlockKind.code:
    case BlockKind.math:
      return TextEdit(e, e, '\n^$id');
  }
}
