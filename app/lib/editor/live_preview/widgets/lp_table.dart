// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:tephra_markdown/tephra_markdown.dart';

import '../../../reading/reading_table.dart';
import 'lp_widget_host.dart';

/// Table widget for Live Preview with cell tap callbacks.
class LpTableWidget extends StatelessWidget {
  const LpTableWidget({
    super.key,
    required this.start,
    required this.end,
    required this.data,
    required this.slice,
    required this.host,
  });

  final int start;
  final int end;
  final Map<String, Object?> data;
  final String slice;
  final LpWidgetHost host;

  @override
  Widget build(BuildContext context) {
    final parsed = MarkdownParser.parse(slice);
    MdTable? tableNode;
    for (final child in parsed.root.children) {
      if (child is MdTable) {
        tableNode = child;
        break;
      }
    }

    if (tableNode == null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => host.selectOffset(start),
        child: Text(slice),
      );
    }

    final cellRanges = data['cellRanges'] as List?;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => host.selectOffset(start),
      child: TableView(
        node: tableNode,
        onCellTap: (r, c) {
          if (cellRanges != null && r < cellRanges.length) {
            final row = cellRanges[r] as List?;
            if (row != null && c < row.length) {
              final cell = row[c] as List?;
              if (cell != null && cell.isNotEmpty) {
                host.selectOffset(cell[0] as int);
                return;
              }
            }
          }
          host.selectOffset(start);
        },
      ),
    );
  }
}
