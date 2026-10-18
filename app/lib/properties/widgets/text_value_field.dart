// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';

/// Single-line text input for string properties.
/// Commits on blur or Enter/Done. Empty text commits `null`.
class TextValueField extends StatefulWidget {
  const TextValueField({
    super.key,
    required this.value,
    required this.onCommit,
  });

  final Object? value;
  final ValueChanged<String?> onCommit;

  @override
  State<TextValueField> createState() => _TextValueFieldState();
}

class _TextValueFieldState extends State<TextValueField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  String? _lastCommittedValue;

  @override
  void initState() {
    super.initState();
    _lastCommittedValue = widget.value?.toString();
    _controller = TextEditingController(text: _lastCommittedValue ?? '');
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(TextValueField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentStr = widget.value?.toString();
    if (widget.value != oldWidget.value && currentStr != _controller.text) {
      _lastCommittedValue = currentStr;
      if (!_focusNode.hasFocus) {
        _controller.text = currentStr ?? '';
      }
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      _commit();
    }
  }

  void _commit() {
    final text = _controller.text;
    final String? newValue = text.isEmpty ? null : text;
    if (newValue != _lastCommittedValue) {
      _lastCommittedValue = newValue;
      widget.onCommit(newValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      maxLines: 1,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _commit(),
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: InputBorder.none,
      ),
    );
  }
}
