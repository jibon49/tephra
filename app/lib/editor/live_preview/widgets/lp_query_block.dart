// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';

import '../../../search/query_block_view.dart';
import 'lp_widget_host.dart';

/// Embedded query block widget for Live Preview with an edit button.
class LpQueryBlockWidget extends StatelessWidget {
  const LpQueryBlockWidget({
    super.key,
    required this.start,
    required this.end,
    required this.query,
    required this.host,
  });

  final int start;
  final int end;
  final String query;
  final LpWidgetHost host;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        QueryBlockView(query: query),
        Positioned(
          top: 4,
          right: 4,
          child: IconButton(
            icon: const Icon(Icons.edit, size: 16),
            tooltip: 'Edit query',
            onPressed: () => host.selectOffset(start),
          ),
        ),
      ],
    );
  }
}
