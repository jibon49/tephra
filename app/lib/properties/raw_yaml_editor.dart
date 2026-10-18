// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'properties_exceptions.dart';

/// Raw YAML text editor for invalid frontmatter or manual YAML editing.
class RawYamlEditor extends StatefulWidget {
  const RawYamlEditor({
    super.key,
    required this.initialYaml,
    required this.onApply,
    required this.onRevert,
    this.errorMessage,
  });

  final String initialYaml;
  final void Function(String newYaml) onApply;
  final VoidCallback onRevert;
  final String? errorMessage;

  @override
  State<RawYamlEditor> createState() => _RawYamlEditorState();
}

class _RawYamlEditorState extends State<RawYamlEditor> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialYaml);
    _error = widget.errorMessage;
  }

  @override
  void didUpdateWidget(RawYamlEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialYaml != oldWidget.initialYaml &&
        _controller.text == oldWidget.initialYaml) {
      _controller.text = widget.initialYaml;
    }
    if (widget.errorMessage != oldWidget.errorMessage) {
      setState(() {
        _error = widget.errorMessage;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _apply() {
    try {
      setState(() => _error = null);
      widget.onApply(_controller.text);
    } on PropertiesYamlException catch (e) {
      setState(() {
        _error = '${e.message} (line ${e.line + 1})';
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    }
  }

  void _revert() {
    setState(() {
      _controller.text = widget.initialYaml;
      _error = null;
    });
    widget.onRevert();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: _error != null
                  ? Colors.red
                  : theme.colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: TextField(
            controller: _controller,
            minLines: 6,
            maxLines: 15,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.all(8),
              border: InputBorder.none,
            ),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(onPressed: _revert, child: Text(l10n.propertiesRevert)),
            const SizedBox(width: 8),
            FilledButton(onPressed: _apply, child: Text(l10n.propertiesApply)),
          ],
        ),
      ],
    );
  }
}
