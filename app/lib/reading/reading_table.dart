// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:tephra_markdown/tephra_markdown.dart';

import 'inline_text.dart';
import 'reading_scope.dart';

/// Renders a GitHub-flavored Markdown table.
class TableView extends StatelessWidget {
  const TableView({super.key, required this.node, this.onCellTap});

  final MdTable node;
  final void Function(int row, int col)? onCellTap;

  @override
  Widget build(BuildContext context) {
    final scope = ReadingScope.maybeOf(context);
    final theme = Theme.of(context);
    final styles = scope?.styles;
    final borderColor = styles?.tableBorder ?? theme.colorScheme.outlineVariant;

    int columnCount = node.aligns.length;
    for (final row in node.children) {
      if (row.children.length > columnCount) {
        columnCount = row.children.length;
      }
    }
    if (columnCount == 0) {
      columnCount = 1;
    }

    final rows = <TableRow>[];

    for (var r = 0; r < node.children.length; r++) {
      final row = node.children[r];
      final isHeader = row.header;
      final cells = <Widget>[];

      for (int i = 0; i < columnCount; i++) {
        final align = i < node.aligns.length ? node.aligns[i] : TableAlign.none;
        final textAlign = switch (align) {
          TableAlign.center => TextAlign.center,
          TableAlign.right => TextAlign.end,
          _ => TextAlign.start,
        };

        final TextStyle? cellStyle = isHeader
            ? (styles?.body ?? theme.textTheme.bodyMedium)?.copyWith(
                fontWeight: FontWeight.bold,
              )
            : styles?.body;

        Widget cellContent;
        if (i < row.children.length) {
          final cell = row.children[i];
          cellContent = ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: InlineText(
                nodes: cell.children,
                style: cellStyle,
                textAlign: textAlign,
              ),
            ),
          );
        } else {
          cellContent = ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: SizedBox.shrink(),
            ),
          );
        }

        if (onCellTap != null) {
          final rowIndex = r;
          final colIndex = i;
          cellContent = GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onCellTap!(rowIndex, colIndex),
            child: cellContent,
          );
        }

        cells.add(cellContent);
      }

      rows.add(
        TableRow(
          decoration: isHeader
              ? BoxDecoration(color: theme.colorScheme.surfaceContainerHighest)
              : null,
          children: cells,
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          border: TableBorder.all(color: borderColor, width: 1),
          children: rows,
        ),
      ),
    );
  }
}
