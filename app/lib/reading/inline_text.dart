// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:tephra_markdown/tephra_markdown.dart';

import 'reading_scope.dart';

/// Renders a list of inline Markdown nodes as rich text.
class InlineText extends StatelessWidget {
  const InlineText({
    super.key,
    required this.nodes,
    this.style,
    this.textAlign,
  });

  InlineText.fromNode(MdNode node, {super.key, this.style, this.textAlign})
    : nodes = node.children;

  final List<MdNode> nodes;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final scope = ReadingScope.maybeOf(context);
    final baseStyle =
        style ?? scope?.styles.body ?? Theme.of(context).textTheme.bodyLarge;

    final spans = _buildSpans(context, nodes, scope, baseStyle);

    return Text.rich(
      TextSpan(style: baseStyle, children: spans),
      textAlign: textAlign,
    );
  }

  List<InlineSpan> _buildSpans(
    BuildContext context,
    List<MdNode> nodes,
    ReadingScope? scope,
    TextStyle? parentStyle,
  ) {
    final spans = <InlineSpan>[];
    final styles = scope?.styles;

    for (final node in nodes) {
      if (node is MdText) {
        spans.add(TextSpan(text: node.text));
      } else if (node is MdEmphasis) {
        spans.add(
          TextSpan(
            style: const TextStyle(fontStyle: FontStyle.italic),
            children: _buildSpans(context, node.children, scope, parentStyle),
          ),
        );
      } else if (node is MdStrong) {
        spans.add(
          TextSpan(
            style: const TextStyle(fontWeight: FontWeight.bold),
            children: _buildSpans(context, node.children, scope, parentStyle),
          ),
        );
      } else if (node is MdStrikethrough) {
        spans.add(
          TextSpan(
            style: const TextStyle(decoration: TextDecoration.lineThrough),
            children: _buildSpans(context, node.children, scope, parentStyle),
          ),
        );
      } else if (node is MdHighlight) {
        spans.add(
          TextSpan(
            style: TextStyle(
              backgroundColor:
                  styles?.highlightBackground ?? const Color(0xAAFFEB3B),
            ),
            children: _buildSpans(context, node.children, scope, parentStyle),
          ),
        );
      } else if (node is MdInlineCode) {
        spans.add(
          TextSpan(
            text: node.code,
            style:
                styles?.mono.copyWith(backgroundColor: styles.codeBackground) ??
                const TextStyle(fontFamily: 'monospace'),
          ),
        );
      } else if (node is MdHardBreak) {
        spans.add(const TextSpan(text: '\n'));
      } else if (node is MdSoftBreak) {
        spans.add(const TextSpan(text: ' '));
      } else if (node is MdFootnoteRef) {
        final num = scope?.footnoteNumbers[node.label];
        final labelText = num != null ? '[$num]' : '[^${node.label}]';
        spans.add(
          TextSpan(
            text: labelText,
            style: TextStyle(
              fontSize: (parentStyle?.fontSize ?? 14.0) * 0.8,
              color: styles?.linkColor,
            ),
          ),
        );
      } else if (node is MdInlineFootnote) {
        final label = 'inline-${node.start}';
        final num = scope?.footnoteNumbers[label];
        final labelText = num != null ? '[$num]' : '[^inline]';
        spans.add(
          TextSpan(
            text: labelText,
            style: TextStyle(
              fontSize: (parentStyle?.fontSize ?? 14.0) * 0.8,
              color: styles?.linkColor,
            ),
          ),
        );
      } else if (node is MdLink) {
        spans.add(
          TextSpan(
            style: TextStyle(
              color: styles?.linkColor,
              decoration: TextDecoration.underline,
            ),
            children: _buildSpans(context, node.children, scope, parentStyle),
          ),
        );
      } else if (node is MdWikiLink) {
        final linkLabel =
            node.alias ??
            (node.heading != null
                ? '${node.target}#${node.heading}'
                : (node.blockRef != null
                      ? '${node.target}#^${node.blockRef}'
                      : node.target));
        spans.add(
          TextSpan(
            text: linkLabel,
            style: TextStyle(
              color: styles?.linkColor,
              decoration: TextDecoration.underline,
            ),
          ),
        );
      } else if (node is MdAutolink) {
        spans.add(
          TextSpan(
            text: node.url,
            style: TextStyle(
              color: styles?.linkColor,
              decoration: TextDecoration.underline,
            ),
          ),
        );
      } else if (node is MdTag) {
        spans.add(
          TextSpan(
            text: '#${node.name}',
            style: TextStyle(
              backgroundColor: styles?.tagBackground,
              color: styles?.linkColor,
            ),
          ),
        );
      } else if (node is MdInlineMath) {
        spans.add(
          TextSpan(
            text: node.tex,
            style: styles?.mono ?? const TextStyle(fontFamily: 'monospace'),
          ),
        );
      } else if (node is MdHtmlInline) {
        spans.add(
          TextSpan(
            text: node.html,
            style: styles?.mono ?? const TextStyle(fontFamily: 'monospace'),
          ),
        );
      } else if (node is MdCommentInline || node is MdBlockId) {
        // Comments and trailing block IDs are not rendered inline in reading view
      } else if (node.children.isNotEmpty) {
        spans.addAll(_buildSpans(context, node.children, scope, parentStyle));
      }
    }

    return spans;
  }
}
