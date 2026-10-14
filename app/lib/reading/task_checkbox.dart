// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:tephra_markdown/tephra_markdown.dart';

/// Interactive task list checkbox supporting standard Obsidian task statuses.
class TaskCheckbox extends StatelessWidget {
  const TaskCheckbox({
    super.key,
    required this.status,
    this.onChanged,
    this.readOnly = false,
  });

  final TaskStatus status;
  final ValueChanged<String>? onChanged;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final char = status.char;
    final isDone = status.isDone;

    Widget content;
    BoxDecoration decoration;

    if (isDone) {
      decoration = BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(4),
      );
      content = const Icon(Icons.check, size: 14, color: Colors.white);
    } else {
      decoration = BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: theme.colorScheme.outline, width: 1.5),
      );

      switch (char) {
        case ' ':
          content = const SizedBox.shrink();
        case '/':
          content = Center(
            child: Container(
              width: 8,
              height: 14,
              color: theme.colorScheme.primary,
            ),
          );
        case '-':
          content = Icon(
            Icons.remove,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
          );
        case '>':
          content = Icon(
            Icons.chevron_right,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          );
        case '<':
          content = Icon(
            Icons.chevron_left,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          );
        case '?':
          content = Center(
            child: Text(
              '?',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        case '!':
          content = Center(
            child: Text(
              '!',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.error,
              ),
            ),
          );
        default:
          content = Center(
            child: Text(
              char,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
      }
    }

    final box = Container(
      width: 20,
      height: 20,
      decoration: decoration,
      child: content,
    );

    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: readOnly || onChanged == null
          ? null
          : () {
              final newStatus = char == ' ' ? 'x' : ' ';
              onChanged!(newStatus);
            },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        child: Center(child: box),
      ),
    );
  }
}
