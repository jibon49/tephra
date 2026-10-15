// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';

/// Value field for [PropertyType.datetime].
/// Displays `YYYY-MM-DDTHH:mm` with date and time pickers.
/// Clear button clears value.
class DateTimeValueField extends StatefulWidget {
  const DateTimeValueField({
    super.key,
    required this.value,
    required this.onCommit,
  });

  final Object? value;
  final ValueChanged<String?> onCommit;

  @override
  State<DateTimeValueField> createState() => _DateTimeValueFieldState();
}

class _DateTimeValueFieldState extends State<DateTimeValueField> {
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
  void didUpdateWidget(DateTimeValueField oldWidget) {
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

    if (_isValidDateTime(text)) {
      if (text != _lastCommittedValue) {
        _lastCommittedValue = text;
        widget.onCommit(text);
      }
    } else {
      _controller.text = _lastCommittedValue ?? '';
    }
  }

  bool _isValidDateTime(String s) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})')
        .firstMatch(s);
    if (match == null) return false;
    final parsed = DateTime.tryParse(s);
    return parsed != null;
  }

  String _formatDateTime(DateTime d, TimeOfDay t) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final h = t.hour.toString().padLeft(2, '0');
    final min = t.minute.toString().padLeft(2, '0');
    return '$y-$m-${day}T$h:$min';
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    DateTime initialDate = now;
    TimeOfDay initialTime = TimeOfDay.fromDateTime(now);

    if (widget.value != null) {
      final parsed = DateTime.tryParse(widget.value.toString());
      if (parsed != null) {
        initialDate = parsed;
        initialTime = TimeOfDay.fromDateTime(parsed);
      }
    }

    final datePicked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );

    if (datePicked == null || !mounted) return;

    final timePicked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (timePicked == null || !mounted) return;

    final formatted = _formatDateTime(datePicked, timePicked);
    _controller.text = formatted;
    _lastCommittedValue = formatted;
    widget.onCommit(formatted);
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
              hintText: 'YYYY-MM-DDTHH:mm',
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
          icon: const Icon(Icons.access_time, size: 16),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          splashRadius: 16,
          onPressed: _pickDateTime,
        ),
      ],
    );
  }
}
