// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../model/sticky_color.dart';

/// Shows a dialog allowing the user to select a predefined or custom sticky note color.
Future<StickyColor?> showStickyColorPicker(
  BuildContext context, {
  StickyColor? initialColor,
}) {
  return showDialog<StickyColor>(
    context: context,
    builder: (context) => StickyColorPicker(initialColor: initialColor),
  );
}

/// Dialog presenting round 48dp swatches for all standard sticky colors
/// as well as a custom hex color input field.
class StickyColorPicker extends StatefulWidget {
  const StickyColorPicker({super.key, this.initialColor});

  final StickyColor? initialColor;

  @override
  State<StickyColorPicker> createState() => _StickyColorPickerState();
}

class _StickyColorPickerState extends State<StickyColorPicker> {
  bool _showCustomInput = false;
  late final TextEditingController _hexController;
  String? _hexError;

  static const List<(StickyColorName, int)> _namedColors = [
    (StickyColorName.yellow, 0xFFFFF3A3),
    (StickyColorName.pink, 0xFFFFC7DD),
    (StickyColorName.blue, 0xFFBFE3FF),
    (StickyColorName.green, 0xFFC8F2C2),
    (StickyColorName.purple, 0xFFE0CCFF),
    (StickyColorName.gray, 0xFFE3E3E3),
  ];

  @override
  void initState() {
    super.initState();
    final init = widget.initialColor;
    if (init is HexStickyColor) {
      _showCustomInput = true;
      _hexController = TextEditingController(text: init.yamlValue);
    } else {
      _hexController = TextEditingController(text: '#');
    }
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  String _colorName(AppLocalizations l10n, StickyColorName name) {
    switch (name) {
      case StickyColorName.yellow:
        return l10n.stickyColorYellow;
      case StickyColorName.pink:
        return l10n.stickyColorPink;
      case StickyColorName.blue:
        return l10n.stickyColorBlue;
      case StickyColorName.green:
        return l10n.stickyColorGreen;
      case StickyColorName.purple:
        return l10n.stickyColorPurple;
      case StickyColorName.gray:
        return l10n.stickyColorGray;
    }
  }

  void _applyCustomHex(AppLocalizations l10n) {
    final raw = _hexController.text.trim();
    final hexRegExp = RegExp(r'^#([0-9a-fA-F]{6})$');
    if (!hexRegExp.hasMatch(raw)) {
      setState(() {
        _hexError = l10n.stickyColorHexError;
      });
      return;
    }

    final parsed = StickyColor.parse(raw);
    Navigator.of(context).pop(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(l10n.stickyColorPickerTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                for (final item in _namedColors)
                  _buildSwatch(
                    label: _colorName(l10n, item.$1),
                    color: Color(item.$2),
                    isSelected:
                        widget.initialColor is NamedStickyColor &&
                        (widget.initialColor as NamedStickyColor).name ==
                            item.$1,
                    onTap: () {
                      Navigator.of(context).pop(NamedStickyColor(item.$1));
                    },
                  ),
                _buildCustomSwatch(
                  label: l10n.stickyColorCustom,
                  isSelected: _showCustomInput,
                  onTap: () {
                    setState(() {
                      _showCustomInput = true;
                    });
                  },
                ),
              ],
            ),
            if (_showCustomInput) ...[
              const SizedBox(height: 20),
              TextField(
                controller: _hexController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l10n.stickyColorCustom,
                  hintText: l10n.stickyColorHexHint,
                  errorText: _hexError,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.colorize),
                ),
                onSubmitted: (_) => _applyCustomHex(l10n),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => _applyCustomHex(l10n),
                child: Text(MaterialLocalizations.of(context).okButtonLabel),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
      ],
    );
  }

  Widget _buildSwatch({
    required String label,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Semantics(
      label: label,
      button: true,
      selected: isSelected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? Colors.black87 : Colors.black26,
              width: isSelected ? 3 : 1.5,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: isSelected
              ? const Icon(Icons.check, size: 24, color: Colors.black87)
              : null,
        ),
      ),
    );
  }

  Widget _buildCustomSwatch({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Semantics(
      label: label,
      button: true,
      selected: isSelected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const SweepGradient(
              colors: [
                Colors.red,
                Colors.orange,
                Colors.yellow,
                Colors.green,
                Colors.blue,
                Colors.purple,
                Colors.red,
              ],
            ),
            border: Border.all(
              color: isSelected ? Colors.black87 : Colors.black26,
              width: isSelected ? 3 : 1.5,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.add, size: 24, color: Colors.white),
        ),
      ),
    );
  }
}
