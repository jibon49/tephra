// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:tephra_markdown/tephra_markdown.dart';

import 'callout_view.dart';
import 'inline_builder.dart';
import 'inline_text.dart';
import 'reading_code.dart';
import 'reading_scope.dart';
import 'reading_table.dart';
import 'task_checkbox.dart';

/// Returns true if [html] contains only an HTML comment.
bool isCommentOnlyHtml(String html) {
  final trimmed = html.trim();
  return trimmed.startsWith('<!--') && trimmed.endsWith('-->');
}

/// Recursively builds a block widget corresponding to [node].
Widget buildBlock(
  BuildContext context,
  MdNode node, {
  int depth = 0,
  bool tight = false,
  TextStyle? textStyle,
}) {
  final scope = ReadingScope.maybeOf(context);
  final theme = Theme.of(context);
  final styles = scope?.styles;

  switch (node) {
    case MdDocument():
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: node.children
            .map(
              (c) => buildBlock(
                context,
                c,
                depth: depth,
                tight: tight,
                textStyle: textStyle,
              ),
            )
            .toList(),
      );

    case MdParagraph():
      if (node.children.every(isHiddenInline)) {
        return const SizedBox.shrink();
      }
      final bottomMargin = tight ? 2.0 : (styles?.paragraphBottomMargin ?? 9.6);
      return Padding(
        padding: EdgeInsets.only(bottom: bottomMargin),
        child: InlineText(
          nodes: node.children,
          style: textStyle ?? styles?.body,
        ),
      );

    case MdHeading():
      final topMargin = styles?.headingTopMargin ?? 12.8;
      final bottomMargin = styles?.headingBottomMargin ?? 6.4;
      return Semantics(
        header: true,
        child: Container(
          key: ValueKey('h:${node.start}'),
          margin: EdgeInsets.only(top: topMargin, bottom: bottomMargin),
          child: InlineText(
            nodes: node.children,
            style: styles?.heading(node.level),
          ),
        ),
      );

    case MdBlockQuote():
      return Container(
        key: Key('quote:${node.start}'),
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.only(left: 12),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              width: 3,
              color: styles?.quoteBorder ?? theme.colorScheme.outline,
            ),
          ),
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: node.children
                .map(
                  (c) => buildBlock(
                    context,
                    c,
                    depth: depth,
                    textStyle: textStyle,
                  ),
                )
                .toList(),
          ),
        ),
      );

    case MdCallout():
      return CalloutView(node: node, depth: depth);

    case MdThematicBreak():
      return const Divider(height: 24, thickness: 1);

    case MdList():
      final bulletList = const ['•', '◦', '▪'];
      final bullet = bulletList[depth % bulletList.length];
      final itemWidgets = <Widget>[];

      for (int i = 0; i < node.children.length; i++) {
        final item = node.children[i];
        final Widget marker;

        final isStruckThrough =
            item.task != null && (item.task!.isDone || item.task!.char == '-');
        final itemTextStyle = isStruckThrough
            ? (styles?.body ?? const TextStyle()).copyWith(
                decoration: TextDecoration.lineThrough,
                color: theme.colorScheme.onSurfaceVariant,
              )
            : textStyle;

        if (item.task != null) {
          final taskItem = scope?.parsed.tasks.firstWhere(
            (t) => t.statusOffset == item.task!.offset,
            orElse: () => TaskItem(
              status: item.task!,
              text: '',
              start: item.start,
              end: item.end,
              statusOffset: item.task!.offset,
              line: 0,
            ),
          );
          marker = TaskCheckbox(
            status: item.task!,
            readOnly: scope?.readOnly ?? false,
            onChanged: (newStatus) {
              if (taskItem != null) {
                scope?.onToggleTask?.call(taskItem, newStatus);
              }
            },
          );
        } else if (node.ordered) {
          marker = SizedBox(
            width: 28,
            child: Text(
              '${node.startNumber + i}.',
              textAlign: TextAlign.right,
              style: styles?.body ?? theme.textTheme.bodyMedium,
            ),
          );
        } else {
          marker = SizedBox(
            width: 28,
            child: Text(
              bullet,
              textAlign: TextAlign.center,
              style: styles?.body ?? theme.textTheme.bodyMedium,
            ),
          );
        }

        Widget itemContent = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: item.children
              .map(
                (c) => buildBlock(
                  context,
                  c,
                  depth: depth + 1,
                  tight: node.tight,
                  textStyle: itemTextStyle,
                ),
              )
              .toList(),
        );

        if (isStruckThrough) {
          itemContent = DefaultTextStyle.merge(
            style: TextStyle(
              decoration: TextDecoration.lineThrough,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            child: itemContent,
          );
        }

        final verticalPadding = node.tight ? 1.0 : 4.0;

        itemWidgets.add(
          Padding(
            padding: EdgeInsets.symmetric(vertical: verticalPadding),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                marker,
                const SizedBox(width: 8),
                Expanded(child: itemContent),
              ],
            ),
          ),
        );
      }

      return Padding(
        padding: EdgeInsets.only(left: depth > 0 ? 0 : 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: itemWidgets,
        ),
      );

    case MdListItem():
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: node.children
            .map(
              (c) => buildBlock(
                context,
                c,
                depth: depth,
                tight: tight,
                textStyle: textStyle,
              ),
            )
            .toList(),
      );

    case MdCodeBlock():
      return CodeBlockView(node: node);

    case MdTable():
      return TableView(node: node);

    case MdTableRow():
    case MdTableCell():
      return const SizedBox.shrink();

    case MdMathBlock():
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Semantics(
          label: 'Math block',
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Center(
              child: Text(
                node.tex,
                style: styles?.mono ?? const TextStyle(fontFamily: 'monospace'),
              ),
            ),
          ),
        ),
      );

    case MdHtmlBlock():
      if (isCommentOnlyHtml(node.html)) {
        return const SizedBox.shrink();
      }
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          node.html,
          style: (styles?.mono ?? const TextStyle(fontFamily: 'monospace'))
              .copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      );

    case MdFootnoteDefinition():
    case MdFrontmatter():
    case MdCommentBlock():
      return const SizedBox.shrink();

    // Inline nodes are invalid at block level
    case MdText():
    case MdEmphasis():
    case MdStrong():
    case MdStrikethrough():
    case MdHighlight():
    case MdInlineCode():
    case MdWikiLink():
    case MdLink():
    case MdAutolink():
    case MdTag():
    case MdBlockId():
    case MdInlineMath():
    case MdFootnoteRef():
    case MdInlineFootnote():
    case MdCommentInline():
    case MdHtmlInline():
    case MdHardBreak():
    case MdSoftBreak():
      assert(() {
        throw StateError('inline node at block level: $node');
      }());
      return const SizedBox.shrink();
  }
}
