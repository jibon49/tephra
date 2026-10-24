// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:tephra_markdown/tephra_markdown.dart';

/// A lightweight Markdown renderer for sticky notes used in board cards,
/// floating windows, and Android bubbles.
///
/// Frontmatter is automatically skipped. It does not depend on any vault
/// or link resolver.
class StickyMiniRenderer extends StatefulWidget {
  const StickyMiniRenderer({
    super.key,
    required this.text,
    required this.textColor,
    this.onToggleTask,
    this.maxBlocks,
  });

  /// Full note source text (frontmatter is skipped).
  final String text;

  /// Text color compliant with background contrast.
  final Color textColor;

  /// 0-based source line for task toggling. If null, checkboxes are not tappable (locked).
  final void Function(int line)? onToggleTask;

  /// Maximum number of blocks to display.
  final int? maxBlocks;

  @override
  State<StickyMiniRenderer> createState() => _StickyMiniRendererState();
}

class _StickyMiniRendererState extends State<StickyMiniRenderer> {
  late ParsedNote _parsed;

  @override
  void initState() {
    super.initState();
    _parsed = MarkdownParser.parse(widget.text);
  }

  @override
  void didUpdateWidget(StickyMiniRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _parsed = MarkdownParser.parse(widget.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Frontmatter and comment blocks are skipped.
    final blocks = _parsed.root.children
        .where((n) => n is! MdFrontmatter && n is! MdCommentBlock)
        .toList();

    final visibleBlocks = widget.maxBlocks != null
        ? blocks.take(widget.maxBlocks!).toList()
        : blocks;

    if (visibleBlocks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < visibleBlocks.length; i++) ...[
          if (i > 0) const SizedBox(height: 4),
          _buildBlock(visibleBlocks[i]),
        ],
      ],
    );
  }

  Widget _buildBlock(MdNode node) {
    if (node is MdHeading) {
      return _buildHeading(node);
    } else if (node is MdParagraph) {
      return _buildParagraph(node);
    } else if (node is MdList) {
      return _buildList(node, level: 0);
    } else if (node is MdCallout) {
      return _buildCallout(node);
    } else if (node is MdBlockQuote) {
      return _buildBlockQuote(node);
    } else if (node is MdCodeBlock) {
      return _buildCodeBlock(node);
    } else if (node is MdThematicBreak) {
      return Divider(
        color: widget.textColor.withValues(alpha: 0.25),
        height: 12,
        thickness: 1,
      );
    } else if (node is MdTable) {
      return _buildTable(node);
    } else {
      // Fallback to raw text between start and end
      final safeEnd = node.end.clamp(node.start, widget.text.length);
      final raw = safeEnd > node.start
          ? widget.text.substring(node.start, safeEnd)
          : '';
      return Text(raw, style: TextStyle(color: widget.textColor, fontSize: 13));
    }
  }

  Widget _buildHeading(MdHeading node) {
    final double fontSize;
    switch (node.level) {
      case 1:
        fontSize = 18;
      case 2:
        fontSize = 16;
      case 3:
        fontSize = 15;
      default:
        fontSize = 14;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Text.rich(
        TextSpan(
          children: _buildInlineChildren(node.children),
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: widget.textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildParagraph(MdParagraph node) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text.rich(
        TextSpan(
          children: _buildInlineChildren(node.children),
          style: TextStyle(color: widget.textColor, fontSize: 13, height: 1.35),
        ),
      ),
    );
  }

  Widget _buildList(MdList list, {required int level}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < list.children.length; i++)
          _buildListItem(
            list.children[i],
            isOrdered: list.ordered,
            index: list.startNumber + i,
            level: level,
          ),
      ],
    );
  }

  Widget _buildListItem(
    MdListItem item, {
    required bool isOrdered,
    required int index,
    required int level,
  }) {
    final line = _lineOf(widget.text, item.start);

    Widget prefixWidget;
    if (item.task != null) {
      prefixWidget = SizedBox(
        width: 20,
        height: 20,
        child: Transform.scale(
          scale: 0.8,
          child: Checkbox(
            value: item.task!.isDone,
            onChanged: widget.onToggleTask != null
                ? (_) => widget.onToggleTask!(line)
                : null,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      );
    } else {
      final prefixText = isOrdered ? '$index. ' : '• ';
      prefixWidget = Text(
        prefixText,
        style: TextStyle(
          color: widget.textColor,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      );
    }

    // Separate paragraph inline content from nested block content (e.g. sublists)
    final inlineSpans = <InlineSpan>[];
    final nestedBlocks = <Widget>[];

    for (final child in item.children) {
      if (child is MdParagraph) {
        inlineSpans.addAll(_buildInlineChildren(child.children));
      } else if (child is MdList) {
        nestedBlocks.add(_buildList(child, level: level + 1));
      } else {
        nestedBlocks.add(_buildBlock(child));
      }
    }

    return Padding(
      padding: EdgeInsets.only(left: level * 16.0, top: 1, bottom: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              prefixWidget,
              const SizedBox(width: 4),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: inlineSpans,
                    style: TextStyle(
                      color: widget.textColor,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (nestedBlocks.isNotEmpty) ...nestedBlocks,
        ],
      ),
    );
  }

  Widget _buildCallout(MdCallout node) {
    final headerTitle = node.title?.isNotEmpty == true
        ? node.title!
        : node.type.toUpperCase();

    final blockChildren = <Widget>[
      Text(
        headerTitle,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: widget.textColor,
        ),
      ),
      for (final child in node.children) _buildBlock(child),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: widget.textColor.withValues(alpha: 0.6),
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: blockChildren,
      ),
    );
  }

  Widget _buildBlockQuote(MdBlockQuote node) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: widget.textColor.withValues(alpha: 0.4),
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [for (final child in node.children) _buildBlock(child)],
      ),
    );
  }

  Widget _buildCodeBlock(MdCodeBlock node) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: widget.textColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        node.code,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: widget.textColor,
        ),
      ),
    );
  }

  Widget _buildTable(MdTable node) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in node.children)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Text(
              row.children.map(_cellText).join(' | '),
              style: TextStyle(
                color: widget.textColor,
                fontSize: 12,
                fontWeight: row.header ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
      ],
    );
  }

  String _cellText(MdTableCell cell) {
    final buffer = StringBuffer();
    void collect(MdNode n) {
      if (n is MdText) {
        buffer.write(n.text);
      } else if (n is MdInlineCode) {
        buffer.write(n.code);
      } else {
        for (final child in n.children) {
          collect(child);
        }
      }
    }

    for (final child in cell.children) {
      collect(child);
    }
    return buffer.toString().trim();
  }

  List<InlineSpan> _buildInlineChildren(List<MdNode> nodes) {
    final spans = <InlineSpan>[];
    for (final node in nodes) {
      final span = _buildInlineSpan(node);
      if (span != null) {
        spans.add(span);
      }
    }
    return spans;
  }

  InlineSpan? _buildInlineSpan(MdNode node) {
    if (node is MdText) {
      return TextSpan(text: node.text);
    } else if (node is MdStrong) {
      return TextSpan(
        children: _buildInlineChildren(node.children),
        style: const TextStyle(fontWeight: FontWeight.bold),
      );
    } else if (node is MdEmphasis) {
      return TextSpan(
        children: _buildInlineChildren(node.children),
        style: const TextStyle(fontStyle: FontStyle.italic),
      );
    } else if (node is MdStrikethrough) {
      return TextSpan(
        children: _buildInlineChildren(node.children),
        style: const TextStyle(decoration: TextDecoration.lineThrough),
      );
    } else if (node is MdHighlight) {
      return TextSpan(
        children: _buildInlineChildren(node.children),
        style: const TextStyle(backgroundColor: Color(0x66FFEB3B)),
      );
    } else if (node is MdInlineCode) {
      return TextSpan(
        text: node.code,
        style: const TextStyle(fontFamily: 'monospace'),
      );
    } else if (node is MdWikiLink) {
      if (node.embed) {
        final ext = p.extension(node.target).toLowerCase();
        final isImage = const [
          '.png',
          '.jpg',
          '.jpeg',
          '.gif',
          '.webp',
          '.bmp',
          '.svg',
        ].contains(ext);
        final prefix = isImage ? '🖼 ' : '📄 ';
        return TextSpan(text: '$prefix${node.target}');
      } else {
        final label = node.alias?.isNotEmpty == true
            ? node.alias!
            : node.target;
        return TextSpan(
          text: label,
          style: const TextStyle(decoration: TextDecoration.underline),
        );
      }
    } else if (node is MdLink) {
      if (node.image) {
        return TextSpan(text: '🖼 ${node.url}');
      } else {
        return TextSpan(
          children: _buildInlineChildren(node.children),
          style: const TextStyle(decoration: TextDecoration.underline),
        );
      }
    } else if (node is MdAutolink) {
      return TextSpan(
        text: node.url,
        style: const TextStyle(decoration: TextDecoration.underline),
      );
    } else if (node is MdTag) {
      return TextSpan(
        text: '#${node.name}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      );
    } else if (node is MdCommentInline) {
      return null; // Hidden
    } else if (node is MdInlineMath) {
      final safeEnd = node.end.clamp(node.start, widget.text.length);
      final raw = safeEnd > node.start
          ? widget.text.substring(node.start, safeEnd)
          : '\$${node.tex}\$';
      return TextSpan(text: raw);
    } else if (node is MdHardBreak) {
      return const TextSpan(text: '\n');
    } else if (node is MdSoftBreak) {
      return const TextSpan(text: ' ');
    } else if (node.children.isNotEmpty) {
      return TextSpan(children: _buildInlineChildren(node.children));
    } else {
      final safeEnd = node.end.clamp(node.start, widget.text.length);
      final raw = safeEnd > node.start
          ? widget.text.substring(node.start, safeEnd)
          : '';
      return TextSpan(text: raw);
    }
  }

  static int _lineOf(String text, int start) {
    var count = 0;
    final end = start.clamp(0, text.length);
    for (var i = 0; i < end; i++) {
      if (text.codeUnitAt(i) == 10) {
        count++;
      }
    }
    return count;
  }
}
