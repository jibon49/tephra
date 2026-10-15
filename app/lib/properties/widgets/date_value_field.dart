// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';

/// Value field for [PropertyType.date].
/// Displays `YYYY-MM-DD` with calendar picker button and clear button.
/// Supports manual entry validated against `YYYY-MM-DD` and real calendar date.
class DateValueField extends StatefulWidget {
  const DateValueField({
    super.key,
    required this.value,
    required this.onCommit,
  });

  final Object? value;
  final ValueChanged<String?> onCommit;

  @override
  State<DateValueField> createState() => _DateValueFieldState();
}

class _DateValueFieldState extends State<DateValueField> {
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
  void didUpdateWidget(DateValueField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final str = widget.value?.toString();
    if (widget.value != oldWidget.value && str != _controller.text) {
      _lastCommittedValue = str;
      if (!_focusNode.hasFocus) {
        _controller.text = str ?? '';
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
      _commitTyped();
    }
  }

  void _commitTyped() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      if (_lastCommittedValue != null) {
        _lastCommittedValue = null;
        widget.onCommit(null);
      }
      return;
    }

    if (_isValidDate(text)) {
      if (text != _lastCommittedValue) {
        _lastCommittedValue = text;
        widget.onCommit(text);
      }
    } else {
      // Revert to last valid committed value
      _controller.text = _lastCommittedValue ?? '';
    }
  }

  bool _isValidDate(String s) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s);
    if (match == null) return false;
    final year = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final day = int.tryParse(match.group(3)!);
    if (year == null || month == null || day == null) return false;
    if (month < 1 || month > 12) return false;
    if (day < 1 || day > 31) return false;

    final parsed = DateTime.tryParse(s);
    if (parsed == null) return false;
    return parsed.year == year && parsed.month == month && parsed.day == day;
  }

  String _formatDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Future<void> _pickDate() async {
    final initialDate = widget.value != null
        ? DateTime.tryParse(widget.value.toString()) ?? DateTime.now()
        : DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      final formatted = _formatDate(picked);
      _controller.text = formatted;
      _lastCommittedValue = formatted;
      widget.onCommit(formatted);
    }
  }

  void _clear() {
    _controller.clear();
    if (_lastCommittedValue != null) {
      _lastCommittedValue = null;
      widget.onCommit(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = _controller.text.isNotEmpty;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            maxLines: 1,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _commitTyped(),
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'YYYY-MM-DD',
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: InputBorder.none,
            ),
          ),
        ),
        if (hasValue)
          IconButton(
            icon: const Icon(Icons.clear, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            splashRadius: 16,
            onPressed: _clear,
          ),
        IconButton(
          icon: const Icon(Icons.calendar_today, size: 16),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          splashRadius: 16,
          onPressed: _pickDate,
        ),
      ],
    );
  }
}
