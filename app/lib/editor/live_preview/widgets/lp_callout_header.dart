// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';

import '../../../reading/callout_styles.dart';
import 'lp_widget_host.dart';

/// Callout header widget for Live Preview with icon, title, and fold chevron.
class LpCalloutHeaderWidget extends StatelessWidget {
  const LpCalloutHeaderWidget({
    super.key,
    required this.start,
    required this.end,
    required this.type,
    this.title,
    required this.fold,
    required this.host,
  });

  final int start;
  final int end;
  final String type;
  final String? title;
  final String fold;
  final LpWidgetHost host;

  @override
  Widget build(BuildContext context) {
    final style = calloutStyleFor(type);
    final isFoldable = fold != 'none';
    final initialCollapsed = fold == 'collapsed';
    final isToggled = host.foldedCallouts.contains(start);
    final isCollapsed = isFoldable
        ? (initialCollapsed ? !isToggled : isToggled)
        : false;

    final displayTitle = (title != null && title!.isNotEmpty)
        ? title!
        : (type.isNotEmpty
              ? '${type[0].toUpperCase()}${type.substring(1)}'
              : 'Note');

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => host.selectOffset(start),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: style.color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border(left: BorderSide(color: style.color, width: 4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(style.icon, size: 18, color: style.color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                displayTitle,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: style.color,
                ),
              ),
            ),
            if (isFoldable)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  host.onToggleCallout?.call(start);
                },
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    isCollapsed ? Icons.chevron_right : Icons.expand_more,
                    size: 18,
                    color: style.color,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
