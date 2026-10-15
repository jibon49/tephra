// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';

/// Checkbox input for boolean properties.
/// Commits immediately on tap.
class CheckboxValueField extends StatelessWidget {
  const CheckboxValueField({
    super.key,
    required this.value,
    required this.onCommit,
  });

  final Object? value;
  final ValueChanged<bool> onCommit;

  @override
  Widget build(BuildContext context) {
    final bool isChecked = value is bool
        ? (value as bool)
        : (value == 'true' || value == 'yes');

    return Align(
      alignment: Alignment.centerLeft,
      child: Checkbox(
        value: isChecked,
        onChanged: (bool? val) {
          onCommit(val ?? false);
        },
      ),
    );
  }
}
