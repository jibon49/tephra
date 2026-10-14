// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../commands/shortcut_codec.dart';
import '../l10n/app_localizations.dart';

Future<SingleActivator?> showShortcutRecorderDialog(
  BuildContext context,
) async {
  return showDialog<SingleActivator>(
    context: context,
    builder: (context) => const ShortcutRecorderDialog(),
  );
}

class ShortcutRecorderDialog extends StatefulWidget {
  const ShortcutRecorderDialog({super.key});

  @override
  State<ShortcutRecorderDialog> createState() => _ShortcutRecorderDialogState();
}

class _ShortcutRecorderDialogState extends State<ShortcutRecorderDialog> {
  final _focusNode = FocusNode();
  String? _preview;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  bool _isModifierKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.control ||
        key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight ||
        key == LogicalKeyboardKey.shift ||
        key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.alt ||
        key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight ||
        key == LogicalKeyboardKey.meta ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight;
  }

  bool _isFunctionKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.f1 ||
        key == LogicalKeyboardKey.f2 ||
        key == LogicalKeyboardKey.f3 ||
        key == LogicalKeyboardKey.f4 ||
        key == LogicalKeyboardKey.f5 ||
        key == LogicalKeyboardKey.f6 ||
        key == LogicalKeyboardKey.f7 ||
        key == LogicalKeyboardKey.f8 ||
        key == LogicalKeyboardKey.f9 ||
        key == LogicalKeyboardKey.f10 ||
        key == LogicalKeyboardKey.f11 ||
        key == LogicalKeyboardKey.f12;
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop(null);
      return KeyEventResult.handled;
    }

    if (_isModifierKey(key)) {
      return KeyEventResult.handled;
    }

    final isCtrl =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.logicalKeysPressed.contains(
          LogicalKeyboardKey.controlLeft,
        ) ||
        HardwareKeyboard.instance.logicalKeysPressed.contains(
          LogicalKeyboardKey.controlRight,
        );
    final isAlt =
        HardwareKeyboard.instance.isAltPressed ||
        HardwareKeyboard.instance.logicalKeysPressed.contains(
          LogicalKeyboardKey.altLeft,
        ) ||
        HardwareKeyboard.instance.logicalKeysPressed.contains(
          LogicalKeyboardKey.altRight,
        );
    final isShift =
        HardwareKeyboard.instance.isShiftPressed ||
        HardwareKeyboard.instance.logicalKeysPressed.contains(
          LogicalKeyboardKey.shiftLeft,
        ) ||
        HardwareKeyboard.instance.logicalKeysPressed.contains(
          LogicalKeyboardKey.shiftRight,
        );
    final isMeta =
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.logicalKeysPressed.contains(
          LogicalKeyboardKey.metaLeft,
        ) ||
        HardwareKeyboard.instance.logicalKeysPressed.contains(
          LogicalKeyboardKey.metaRight,
        );

    final hasModifier = isCtrl || isAlt || isShift || isMeta;
    final isFn = _isFunctionKey(key);

    if (!hasModifier && !isFn) {
      // Must have at least 1 modifier unless function key
      return KeyEventResult.handled;
    }

    final activator = SingleActivator(
      key,
      control: isCtrl,
      alt: isAlt,
      shift: isShift,
      meta: isMeta,
    );

    setState(() {
      _preview = formatShortcut(activator);
    });

    Navigator.of(context).pop(activator);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: AlertDialog(
        title: Text(l10n.hotkeysAdd),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.hotkeysPressKeys),
            const SizedBox(height: 16),
            if (_preview != null)
              Chip(label: Text(_preview!))
            else
              Text(
                'e.g. Ctrl+Shift+K or F2',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: Theme.of(context).hintColor),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
        ],
      ),
    );
  }
}
