// © 2026 Tephra. All rights reserved.

import '../frontmatter.dart';
import '../inline/inline_parser.dart';
import '../nodes.dart';
import '../note_models.dart';
import '../parser_options.dart';
import '../util/offset_map.dart';
import 'block_node.dart';
import 'link_definitions.dart';

final RegExp _calloutRegex = RegExp(
  r'^\[!([A-Za-z0-9-]+)\]([+-])?(?:[ \t]+(.*))?$',
);
final RegExp _blockIdRegex = RegExp(r'(?:^|[ \t])\^([A-Za-z0-9-]+)[ \t]*$');

/// Converts a mutable builder [BlockNode] tree into an immutable [MdDocument].
MdDocument finalizeTree({
  required BlockNode root,
  required String fullText,
  required ParserOptions options,
  required Map<String, LinkDefinition> definitions,
  required List<BlockRef> blockIds,
  FrontmatterSplit? frontmatter,
}) {
  // Pre-pass: extract all link definitions across the whole document
  // before any inline parsing so forward references resolve.
  _collectAllDefinitions(root, fullText, definitions);

  final ctx = InlineContext(options: options, definitions: definitions);

  final docChildren = <MdNode>[];
  if (options.obsidian && frontmatter != null) {
    docChildren.add(
      MdFrontmatter(
        frontmatter.start,
        frontmatter.end,
        yaml: frontmatter.yaml,
        contentStart: frontmatter.contentStart,
      ),
    );
  }

  BlockNode? prevSibling;
  for (final child in root.children) {
    final finalized = _finalizeBlock(
      node: child,
      parent: root,
      prevSibling: prevSibling,
      fullText: fullText,
      options: options,
      ctx: ctx,
      blockIds: blockIds,
    );
    if (finalized != null) {
      docChildren.add(finalized);
      prevSibling = child;
    }
  }

  final docEnd = docChildren.isNotEmpty
      ? docChildren.last.end
      : (frontmatter?.end ?? fullText.length);
  return MdDocument(0, docEnd, children: docChildren);
}

void _collectAllDefinitions(
  BlockNode node,
  String fullText,
  Map<String, LinkDefinition> definitions,
) {
  if (node.type == BlockType.paragraph) {
    extractLinkDefinitions(
      text: fullText,
      segments: node.segments,
      definitions: definitions,
    );
  }
  for (final child in node.children) {
    _collectAllDefinitions(child, fullText, definitions);
  }
}

MdNode? _finalizeBlock({
  required BlockNode node,
  required BlockNode parent,
  required BlockNode? prevSibling,
  required String fullText,
  required ParserOptions options,
  required InlineContext ctx,
  required List<BlockRef> blockIds,
}) {
  switch (node.type) {
    case BlockType.document:
      return null;

    case BlockType.blockQuote:
      // Check Obsidian callout conversion
      if (options.obsidian && node.children.isNotEmpty) {
        final firstChild = node.children.first;
        if (firstChild.type == BlockType.paragraph &&
            firstChild.segments.isNotEmpty) {
          final firstSeg = firstChild.segments.first;
          final line = fullText.substring(firstSeg.$1, firstSeg.$2).trimRight();
          final match = _calloutRegex.firstMatch(line);
          if (match != null) {
            final type = match.group(1)!.toLowerCase();
            final foldChar = match.group(2);
            final fold = foldChar == '+'
                ? CalloutFold.expanded
                : foldChar == '-'
                ? CalloutFold.collapsed
                : CalloutFold.none;
            final rawTitle = match.group(3)?.trim();
            final title = (rawTitle != null && rawTitle.isNotEmpty)
                ? rawTitle
                : null;

            // Remove first segment from paragraph
            firstChild.segments.removeAt(0);
            if (firstChild.segments.isEmpty) {
              node.children.removeAt(0);
            } else {
              firstChild.start = firstChild.segments.first.$1;
            }

            final bodyChildren = <MdNode>[];
            BlockNode? bodyPrev;
            for (final c in node.children) {
              final fin = _finalizeBlock(
                node: c,
                parent: node,
                prevSibling: bodyPrev,
                fullText: fullText,
                options: options,
                ctx: ctx,
                blockIds: blockIds,
              );
              if (fin != null) {
                bodyChildren.add(fin);
                bodyPrev = c;
              }
            }

            return MdCallout(
              node.start,
              node.end,
              type: type,
              fold: fold,
              title: title,
              children: bodyChildren,
            );
          }
        }
      }

      final children = <MdNode>[];
      BlockNode? bqPrev;
      for (final c in node.children) {
        final fin = _finalizeBlock(
          node: c,
          parent: node,
          prevSibling: bqPrev,
          fullText: fullText,
          options: options,
          ctx: ctx,
          blockIds: blockIds,
        );
        if (fin != null) {
          children.add(fin);
          bqPrev = c;
        }
      }
      return MdBlockQuote(node.start, node.end, children: children);

    case BlockType.paragraph:
      // Extract link definitions from start of paragraph
      extractLinkDefinitions(
        text: fullText,
        segments: node.segments,
        definitions: ctx.definitions,
      );
      if (node.segments.isEmpty) return null;

      // Trim trailing spaces from the last segment
      var last = node.segments.last;
      while (last.$2 > last.$1 &&
          (fullText[last.$2 - 1] == ' ' || fullText[last.$2 - 1] == '\t')) {
        last = (last.$1, last.$2 - 1);
      }
      node.segments[node.segments.length - 1] = last;
      final nodeEnd = last.$2;

      final map = OffsetMap();
      for (final seg in node.segments) {
        map.addSegment(seg.$1, seg.$2);
      }
      final virtualText = map.buildText(fullText);

      (int, int)? blockIdRange;

      // Check block ID
      if (options.obsidian) {
        final lastSegText = fullText.substring(last.$1, last.$2);
        final match = _blockIdRegex.firstMatch(lastSegText);
        if (match != null) {
          final id = match.group(1)!;
          final caretIdx = lastSegText.lastIndexOf('^$id');
          if (caretIdx != -1) {
            final idStart = last.$1 + caretIdx;
            final idEnd = idStart + 1 + id.length;

            // Determine owner block
            int ownerStart;
            int ownerEnd;
            if (parent.type == BlockType.listItem &&
                parent.children.first == node) {
              ownerStart = parent.start;
              ownerEnd = parent.end;
            } else if (node.segments.length == 1 &&
                fullText
                        .substring(
                          node.segments.first.$1,
                          node.segments.first.$2,
                        )
                        .trim() ==
                    '^$id' &&
                prevSibling != null) {
              // Standalone ID line owning previous block
              ownerStart = prevSibling.start;
              ownerEnd = prevSibling.end;
            } else {
              ownerStart = node.start;
              ownerEnd = nodeEnd;
            }

            blockIds.add(
              BlockRef(
                id: id,
                start: ownerStart,
                end: ownerEnd,
                idStart: idStart,
                idEnd: idEnd,
              ),
            );
            final vLastStart = virtualText.length - lastSegText.length;
            final vIdStart = vLastStart + caretIdx;
            final vIdEnd = vIdStart + 1 + id.length;
            blockIdRange = (vIdStart, vIdEnd);
          }
        }
      }

      final pCtx = blockIdRange != null
          ? ctx.withBlockIdRange(blockIdRange)
          : ctx;
      final inlines = parseInlines(
        InlineSource(text: virtualText, map: map),
        pCtx,
      );
      return MdParagraph(node.start, nodeEnd, children: inlines);

    case BlockType.heading:
      String? blockId;
      (int, int)? blockIdRange;
      if (node.segments.isNotEmpty) {
        var last = node.segments.last;
        while (last.$2 > last.$1 &&
            (fullText[last.$2 - 1] == ' ' || fullText[last.$2 - 1] == '\t')) {
          last = (last.$1, last.$2 - 1);
        }
        node.segments[node.segments.length - 1] = last;

        if (options.obsidian) {
          final lastSegText = fullText.substring(last.$1, last.$2);
          final match = _blockIdRegex.firstMatch(lastSegText);
          if (match != null) {
            final id = match.group(1)!;
            final caretIdx = lastSegText.lastIndexOf('^$id');
            if (caretIdx != -1) {
              final idStart = last.$1 + caretIdx;
              final idEnd = idStart + 1 + id.length;
              blockId = id;
              blockIds.add(
                BlockRef(
                  id: id,
                  start: node.start,
                  end: node.end,
                  idStart: idStart,
                  idEnd: idEnd,
                ),
              );

              final mapTemp = OffsetMap();
              for (final seg in node.segments) {
                mapTemp.addSegment(seg.$1, seg.$2);
              }
              final vText = mapTemp.buildText(fullText);
              final vLastStart = vText.length - lastSegText.length;
              final vIdStart = vLastStart + caretIdx;
              final vIdEnd = vIdStart + 1 + id.length;
              blockIdRange = (vIdStart, vIdEnd);
            }
          }
        }
      }

      final map = OffsetMap();
      for (final seg in node.segments) {
        map.addSegment(seg.$1, seg.$2);
      }
      final virtualText = map.buildText(fullText);
      final hCtx = blockIdRange != null
          ? ctx.withBlockIdRange(blockIdRange)
          : ctx;
      final inlines = parseInlines(
        InlineSource(text: virtualText, map: map),
        hCtx,
      );
      return MdHeading(
        node.start,
        node.end,
        level: node.level,
        blockId: blockId,
        isSetext: node.isSetext,
        children: inlines,
      );

    case BlockType.codeBlock:
      if (node.isFenced) {
        final code = node.rawLines.isNotEmpty
            ? '${node.rawLines.join('\n')}\n'
            : '';
        final rawLang = node.info.split(RegExp(r'\s+')).firstOrNull;
        final lang = (rawLang != null && rawLang.isNotEmpty)
            ? decodeEscapesAndEntities(rawLang)
            : null;
        final language = (lang != null && lang.isNotEmpty) ? lang : null;
        return MdCodeBlock(
          node.start,
          node.end,
          language: language,
          info: node.info,
          code: code,
          fenced: true,
        );
      } else {
        // Indented code: strip trailing blank lines
        final lines = List<String>.from(node.rawLines);
        while (lines.isNotEmpty && lines.last.trim().isEmpty) {
          lines.removeLast();
        }
        final code = lines.isNotEmpty ? '${lines.join('\n')}\n' : '';
        return MdCodeBlock(
          node.start,
          node.end,
          language: null,
          info: '',
          code: code,
          fenced: false,
        );
      }

    case BlockType.mathBlock:
      final lines = List<String>.from(node.rawLines);
      while (lines.isNotEmpty && lines.first.trim().isEmpty) {
        lines.removeAt(0);
      }
      while (lines.isNotEmpty && lines.last.trim().isEmpty) {
        lines.removeLast();
      }
      final tex = lines.join('\n');
      return MdMathBlock(node.start, node.end, tex: tex);

    case BlockType.commentBlock:
      final text = node.rawLines.join('\n');
      return MdCommentBlock(node.start, node.end, text: text);

    case BlockType.htmlBlock:
      final html = node.rawLines.join('\n');
      return MdHtmlBlock(node.start, node.end, html: html);

    case BlockType.thematicBreak:
      return MdThematicBreak(node.start, node.end);

    case BlockType.table:
      final rows = <MdTableRow>[];
      for (var r = 0; r < node.tableRows.length; r++) {
        final rowSegments = node.tableRows[r];
        final isHeader = r == 0;
        final cells = <MdTableCell>[];
        for (final cellSeg in rowSegments) {
          if (cellSeg.$2 > cellSeg.$1) {
            final map = OffsetMap()..addSegment(cellSeg.$1, cellSeg.$2);
            final cellText = fullText.substring(cellSeg.$1, cellSeg.$2);
            final inlines = parseInlines(
              InlineSource(text: cellText, map: map),
              ctx.withInTableCell(true),
            );
            cells.add(MdTableCell(cellSeg.$1, cellSeg.$2, children: inlines));
          } else {
            cells.add(MdTableCell(cellSeg.$1, cellSeg.$2, children: const []));
          }
        }
        final rowSpan = r < node.tableRowSpans.length
            ? node.tableRowSpans[r]
            : (rowSegments.isNotEmpty
                  ? (rowSegments.first.$1, rowSegments.last.$2)
                  : (node.start, node.end));
        final rowStart = rowSpan.$1;
        final rowEnd = rowSpan.$2;
        rows.add(
          MdTableRow(rowStart, rowEnd, header: isHeader, children: cells),
        );
      }
      return MdTable(node.start, node.end, aligns: node.aligns, children: rows);

    case BlockType.list:
      final tight = _computeTight(node);
      final items = <MdListItem>[];
      BlockNode? liPrev;
      for (final c in node.children) {
        final fin = _finalizeBlock(
          node: c,
          parent: node,
          prevSibling: liPrev,
          fullText: fullText,
          options: options,
          ctx: ctx,
          blockIds: blockIds,
        );
        if (fin is MdListItem) {
          items.add(fin);
          liPrev = c;
        }
      }
      return MdList(
        node.start,
        node.end,
        ordered: node.ordered,
        startNumber: node.startNumber,
        tight: tight,
        children: items,
      );

    case BlockType.listItem:
      final children = <MdNode>[];
      BlockNode? itemPrev;
      for (final c in node.children) {
        final fin = _finalizeBlock(
          node: c,
          parent: node,
          prevSibling: itemPrev,
          fullText: fullText,
          options: options,
          ctx: ctx,
          blockIds: blockIds,
        );
        if (fin != null) {
          children.add(fin);
          itemPrev = c;
        }
      }
      return MdListItem(
        node.start,
        node.end,
        task: node.task,
        children: children,
      );

    case BlockType.footnote:
      final children = <MdNode>[];
      BlockNode? fnPrev;
      for (final c in node.children) {
        final fin = _finalizeBlock(
          node: c,
          parent: node,
          prevSibling: fnPrev,
          fullText: fullText,
          options: options,
          ctx: ctx,
          blockIds: blockIds,
        );
        if (fin != null) {
          children.add(fin);
          fnPrev = c;
        }
      }
      return MdFootnoteDefinition(
        node.start,
        node.end,
        label: node.footnoteLabel,
        children: children,
      );
  }
}

bool _computeTight(BlockNode list) {
  for (var i = 0; i < list.children.length; i++) {
    final item = list.children[i];
    if (item.endsWithBlankLine() && i < list.children.length - 1) {
      return false;
    }
    for (var j = 0; j < item.children.length - 1; j++) {
      final child = item.children[j];
      if (child.endsWithBlankLine()) {
        return false;
      }
    }
  }
  return true;
}
