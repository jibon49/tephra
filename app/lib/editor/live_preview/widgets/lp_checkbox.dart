// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:tephra_index/tephra_index.dart';

import 'lp_widget_host.dart';

/// An interactive checkbox widget for task list items in Live Preview.
class LpCheckboxWidget extends StatelessWidget {
  const LpCheckboxWidget({
    super.key,
    required this.start,
    required this.end,
    required this.status,
    required this.host,
  });

  final int start;
  final int end;
  final String status;
  final LpWidgetHost host;

  void _toggle() {
    final newStatus = status == ' ' ? 'x' : ' ';
    // The status character is at start + 1 (inside '[status]')
    host.applyEdits([TextEdit(start + 1, start + 2, newStatus)]);
  }

  @override
  Widget build(BuildContext context) {
    final isDone = status == 'x' || status == 'X';
    final isCustom = status != ' ' && !isDone;
    final isPhone = MediaQuery.of(context).size.width < 600;

    Widget core;
    if (isCustom) {
      core = Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary,
            width: 1.5,
          ),
          color: Theme.of(context).colorScheme.primaryContainer
              .withValues(alpha: 0.5),
        ),
        alignment: Alignment.center,
        child: Text(
          status,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            height: 1.0,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      );
    } else {
      core = SizedBox(
        width: 18,
        height: 18,
        child: Checkbox(
          value: isDone,
          onChanged: (_) => _toggle(),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggle,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: isPhone ? 48 : 20,
          minHeight: isPhone ? 48 : 20,
        ),
        child: Center(child: core),
      ),
    );
  }
}
