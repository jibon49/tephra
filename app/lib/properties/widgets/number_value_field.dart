// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Numeric input for number properties.
/// Validates input as int or double. Shows red border and error message on invalid input.
/// Empty text commits `null`.
class NumberValueField extends StatefulWidget {
  const NumberValueField({
    super.key,
    required this.value,
    required this.onCommit,
  });

  final Object? value;
  final ValueChanged<num?> onCommit;

  @override
  State<NumberValueField> createState() => _NumberValueFieldState();
}

class _NumberValueFieldState extends State<NumberValueField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  String? _errorMessage;
  num? _lastCommittedValue;

  @override
  void initState() {
    super.initState();
    if (widget.value is num) {
      _lastCommittedValue = widget.value as num;
    } else if (widget.value != null) {
      _lastCommittedValue = num.tryParse(widget.value.toString().trim());
    }
    _controller = TextEditingController(
      text: _lastCommittedValue?.toString() ?? '',
    );
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(NumberValueField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      num? newNum;
      if (widget.value is num) {
        newNum = widget.value as num;
      } else if (widget.value != null) {
        newNum = num.tryParse(widget.value.toString().trim());
      }
      _lastCommittedValue = newNum;
      if (!_focusNode.hasFocus) {
        _errorMessage = null;
        _controller.text = newNum?.toString() ?? '';
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
    final text = _controller.text.trim();
    if (text.isEmpty) {
      if (_errorMessage != null) {
        setState(() => _errorMessage = null);
      }
      if (_lastCommittedValue != null) {
        _lastCommittedValue = null;
        widget.onCommit(null);
      }
      return;
    }

    final parsedNum = num.tryParse(text);
    if (parsedNum == null) {
      final l10n = AppLocalizations.of(context);
      setState(() {
        _errorMessage = l10n.propertiesInvalidNumber;
      });
      return;
    }

    // Determine if it should be an int or a double
    final num finalVal = (!text.contains('.') && parsedNum is int)
        ? parsedNum
        : (parsedNum == parsedNum.roundToDouble() && !text.contains('.')
              ? parsedNum.toInt()
              : parsedNum.toDouble());

    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
    if (finalVal != _lastCommittedValue) {
      _lastCommittedValue = finalVal;
      widget.onCommit(finalVal);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasError = _errorMessage != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          maxLines: 1,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _commit(),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 8,
            ),
            border: hasError
                ? const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.red),
                  )
                : InputBorder.none,
            enabledBorder: hasError
                ? const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.red),
                  )
                : InputBorder.none,
            focusedBorder: hasError
                ? const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.red, width: 1.5),
                  )
                : null,
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 4),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 11),
            ),
          ),
      ],
    );
  }
}
