// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import 'workspace_models.dart';

class SplitDivider extends ConsumerWidget {
  const SplitDivider({required this.axis, super.key});

  final SplitAxis axis;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isHorizontal = axis == SplitAxis.horizontal;

    return MouseRegion(
      cursor: isHorizontal
          ? SystemMouseCursors.resizeColumn
          : SystemMouseCursors.resizeRow,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: () {
          ref.read(workspaceProvider.notifier).setSplitRatio(0.5);
        },
        onPanUpdate: (details) {
          final renderBox = context.findRenderObject() as RenderBox?;
          if (renderBox == null) return;
          final parentBox = renderBox.parent as RenderBox?;
          final size = parentBox?.size;
          if (size == null) return;

          final total = isHorizontal ? size.width : size.height;
          if (total <= 0) return;

          final currentRatio = ref.read(workspaceProvider).splitRatio;
          final delta = isHorizontal ? details.delta.dx : details.delta.dy;
          ref
              .read(workspaceProvider.notifier)
              .setSplitRatio(currentRatio + delta / total);
        },
        child: Container(
          width: isHorizontal ? 6 : double.infinity,
          height: isHorizontal ? double.infinity : 6,
          color: theme.dividerColor.withAlpha(50),
        ),
      ),
    );
  }
}
