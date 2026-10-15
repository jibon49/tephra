// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';

import 'lp_widget_host.dart';

/// A 1 dp divider horizontal rule widget for Live Preview.
class LpRuleWidget extends StatelessWidget {
  const LpRuleWidget({
    super.key,
    required this.start,
    required this.end,
    required this.host,
  });

  final int start;
  final int end;
  final LpWidgetHost host;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => host.selectOffset(start),
      child: Container(
        height: 16,
        alignment: Alignment.center,
        child: const Divider(height: 1, thickness: 1),
      ),
    );
  }
}
