// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'status_bar_registry.dart';

class StatusBar extends ConsumerWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allItems = ref.watch(statusBarRegistryProvider);
    final theme = Theme.of(context);

    final leftItems =
        allItems.where((i) => i.alignment == StatusBarAlignment.left).toList()
          ..sort((a, b) => a.order.compareTo(b.order));
    final rightItems =
        allItems.where((i) => i.alignment == StatusBarAlignment.right).toList()
          ..sort((a, b) => a.order.compareTo(b.order));

    return Container(
      key: const Key('desktop.statusbar'),
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
        border: Border(
          top: BorderSide(color: theme.dividerColor.withAlpha(40), width: 1),
        ),
      ),
      child: DefaultTextStyle(
        style: theme.textTheme.labelSmall ?? const TextStyle(fontSize: 11),
        child: Row(
          children: [
            for (final item in leftItems) ...[
              item.builder(context, ref),
              const SizedBox(width: 8),
            ],
            const Spacer(),
            for (final item in rightItems) ...[
              const SizedBox(width: 8),
              item.builder(context, ref),
            ],
          ],
        ),
      ),
    );
  }
}
