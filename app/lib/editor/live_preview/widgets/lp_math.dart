// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';

import 'lp_widget_host.dart';

/// Monospace tinted TeX math box for Live Preview.
class LpMathWidget extends StatelessWidget {
  const LpMathWidget({
    super.key,
    required this.start,
    required this.end,
    required this.tex,
    required this.isBlock,
    required this.host,
  });

  final int start;
  final int end;
  final String tex;
  final bool isBlock;
  final LpWidgetHost host;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final monoStyle = TextStyle(
      fontFamily: 'monospace',
      color: theme.colorScheme.onSurface,
    );

    if (isBlock) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => host.selectOffset(start),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(6),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(tex, style: monoStyle),
          ),
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => host.selectOffset(start),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(tex, style: monoStyle),
      ),
    );
  }
}
