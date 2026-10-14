// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:tephra_markdown/tephra_markdown.dart';

import 'callout_styles.dart';
import 'inline_text.dart';
import 'reading_blocks.dart';
import 'reading_scope.dart';

/// Renders an Obsidian callout block with custom icon, accent color, and folding.
class CalloutView extends StatelessWidget {
  const CalloutView({super.key, required this.node, this.depth = 0});

  final MdCallout node;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final scope = ReadingScope.maybeOf(context);
    final style = calloutStyleFor(node.type);

    final isFoldable = node.fold != CalloutFold.none;
    final initialCollapsed = node.fold == CalloutFold.collapsed;
    final isToggled = scope?.toggledCallouts.contains(node.start) ?? false;
    final isCollapsed = isFoldable
        ? (initialCollapsed ? !isToggled : isToggled)
        : false;

    final List<MdNode> titleNodes;
    if (node.title != null) {
      titleNodes = MarkdownParser.parseInline(node.title!);
    } else {
      final capType = node.type.isNotEmpty
          ? '${node.type[0].toUpperCase()}${node.type.substring(1)}'
          : 'Note';
      titleNodes = [MdText(0, capType.length, text: capType)];
    }

    Widget titleRow = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(style.icon, size: 18, color: style.color),
        const SizedBox(width: 8),
        Expanded(
          child: InlineText(
            nodes: titleNodes,
            style: TextStyle(fontWeight: FontWeight.bold, color: style.color),
          ),
        ),
        if (isFoldable)
          Icon(
            isCollapsed ? Icons.chevron_right : Icons.expand_more,
            size: 20,
            color: style.color,
          ),
      ],
    );

    if (isFoldable) {
      titleRow = Semantics(
        button: true,
        expanded: !isCollapsed,
        child: InkWell(
          onTap: () {
            scope?.onToggleCallout?.call(node.start);
          },
          child: titleRow,
        ),
      );
    }

    return Semantics(
      label: node.type,
      child: Container(
        key: Key('callout:${node.start}'),
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: style.color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            titleRow,
            if (!isCollapsed && node.children.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...node.children.map(
                (c) => buildBlock(context, c, depth: depth + 1),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
