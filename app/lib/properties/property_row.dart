// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'property_type.dart';
import 'widgets/checkbox_value_field.dart';
import 'widgets/chips_value_field.dart';
import 'widgets/date_value_field.dart';
import 'widgets/datetime_value_field.dart';
import 'widgets/number_value_field.dart';
import 'widgets/text_value_field.dart';

/// Single row in the properties panel representing one frontmatter key-value pair.
class PropertyRow extends StatefulWidget {
  const PropertyRow({
    super.key,
    required this.index,
    required this.propertyKey,
    required this.value,
    required this.type,
    required this.existingKeys,
    required this.onRenameKey,
    required this.onSetValue,
    required this.onRemoveKey,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onChangeType,
    required this.onEditAsYaml,
    this.suggestionsFetcher,
  });

  final int index;
  final String propertyKey;
  final Object? value;
  final PropertyType type;
  final List<String> existingKeys;
  final void Function(String oldKey, String newKey) onRenameKey;
  final void Function(Object? newValue) onSetValue;
  final VoidCallback onRemoveKey;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final void Function(PropertyType newType) onChangeType;
  final VoidCallback onEditAsYaml;
  final Future<List<String>> Function()? suggestionsFetcher;

  @override
  State<PropertyRow> createState() => _PropertyRowState();
}

class _PropertyRowState extends State<PropertyRow> {
  late final TextEditingController _keyController;
  late final FocusNode _keyFocusNode;
  String? _keyError;

  @override
  void initState() {
    super.initState();
    _keyController = TextEditingController(text: widget.propertyKey);
    _keyFocusNode = FocusNode();
    _keyFocusNode.addListener(_onKeyFocusChange);
  }

  @override
  void didUpdateWidget(PropertyRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.propertyKey != oldWidget.propertyKey) {
      if (!_keyFocusNode.hasFocus) {
        _keyController.text = widget.propertyKey;
        _keyError = null;
      }
    }
  }

  @override
  void dispose() {
    _keyFocusNode.removeListener(_onKeyFocusChange);
    _keyFocusNode.dispose();
    _keyController.dispose();
    super.dispose();
  }

  void _onKeyFocusChange() {
    if (!_keyFocusNode.hasFocus) {
      _commitRename();
    }
  }

  void _commitRename() {
    final newKey = _keyController.text.trim();
    if (newKey.isEmpty || newKey == widget.propertyKey) {
      _keyController.text = widget.propertyKey;
      if (_keyError != null) {
        setState(() => _keyError = null);
      }
      return;
    }

    // Check if newKey exists in existingKeys (case-insensitive, excluding current key)
    final conflict = widget.existingKeys.any(
      (k) =>
          k.toLowerCase() == newKey.toLowerCase() &&
          k.toLowerCase() != widget.propertyKey.toLowerCase(),
    );

    if (conflict) {
      final l10n = AppLocalizations.of(context);
      setState(() {
        _keyError = l10n.propertiesKeyExists;
        _keyController.text = widget.propertyKey;
      });
      return;
    }

    if (_keyError != null) {
      setState(() => _keyError = null);
    }
    widget.onRenameKey(widget.propertyKey, newKey);
  }

  IconData _iconForType(PropertyType type) {
    switch (type) {
      case PropertyType.text:
        return Icons.short_text;
      case PropertyType.multitext:
        return Icons.format_list_bulleted;
      case PropertyType.number:
        return Icons.pin;
      case PropertyType.checkbox:
        return Icons.check_box_outlined;
      case PropertyType.date:
        return Icons.calendar_today_outlined;
      case PropertyType.datetime:
        return Icons.access_time;
      case PropertyType.aliases:
        return Icons.alternate_email;
      case PropertyType.tags:
        return Icons.label_outline;
    }
  }

  String _labelForType(AppLocalizations l10n, PropertyType type) {
    switch (type) {
      case PropertyType.text:
        return l10n.propertyTypeText;
      case PropertyType.multitext:
        return l10n.propertyTypeMultitext;
      case PropertyType.number:
        return l10n.propertyTypeNumber;
      case PropertyType.checkbox:
        return l10n.propertyTypeCheckbox;
      case PropertyType.date:
        return l10n.propertyTypeDate;
      case PropertyType.datetime:
        return l10n.propertyTypeDatetime;
      case PropertyType.aliases:
        return l10n.propertyTypeAliases;
      case PropertyType.tags:
        return l10n.propertyTypeTags;
    }
  }

  bool _isUnsupportedValue() {
    final v = widget.value;
    if (v is Map) return true;
    switch (widget.type) {
      case PropertyType.number:
      case PropertyType.checkbox:
      case PropertyType.date:
      case PropertyType.datetime:
        if (v is List) return true;
        break;
      default:
        break;
    }
    return false;
  }

  Widget _buildValueWidget(BuildContext context) {
    if (_isUnsupportedValue()) {
      final l10n = AppLocalizations.of(context);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.value?.toString() ?? '',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          Text(
            l10n.propertiesUnsupportedValue,
            style: const TextStyle(fontSize: 11, color: Colors.orange),
          ),
        ],
      );
    }

    switch (widget.type) {
      case PropertyType.text:
        return TextValueField(value: widget.value, onCommit: widget.onSetValue);
      case PropertyType.number:
        return NumberValueField(
          value: widget.value,
          onCommit: widget.onSetValue,
        );
      case PropertyType.checkbox:
        return CheckboxValueField(
          value: widget.value,
          onCommit: widget.onSetValue,
        );
      case PropertyType.date:
        return DateValueField(value: widget.value, onCommit: widget.onSetValue);
      case PropertyType.datetime:
        return DateTimeValueField(
          value: widget.value,
          onCommit: widget.onSetValue,
        );
      case PropertyType.multitext:
      case PropertyType.aliases:
      case PropertyType.tags:
        return ChipsValueField(
          type: widget.type,
          value: widget.value,
          onCommit: widget.onSetValue,
          suggestionsFetcher: widget.type == PropertyType.aliases
              ? null
              : widget.suggestionsFetcher,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDesktop = MediaQuery.sizeOf(context).width >= 600;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Drag handle (desktop) | 48dp Menu button (phone)
          if (isDesktop)
            ReorderableDragStartListener(
              index: widget.index,
              child: const MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.drag_handle, size: 18, color: Colors.grey),
                ),
              ),
            )
          else
            SizedBox(
              height: 48,
              width: 48,
              child: Center(
                child: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  tooltip: '',
                  onSelected: (action) {
                    switch (action) {
                      case 'moveUp':
                        widget.onMoveUp();
                        break;
                      case 'moveDown':
                        widget.onMoveDown();
                        break;
                      case 'editAsYaml':
                        widget.onEditAsYaml();
                        break;
                      case 'remove':
                        widget.onRemoveKey();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'moveUp',
                      child: Text(l10n.propertiesMoveUp),
                    ),
                    PopupMenuItem(
                      value: 'moveDown',
                      child: Text(l10n.propertiesMoveDown),
                    ),
                    PopupMenuItem(
                      value: 'editAsYaml',
                      child: Text(l10n.propertiesEditAsYaml),
                    ),
                    PopupMenuItem(
                      value: 'remove',
                      child: Text(l10n.propertiesRemove),
                    ),
                  ],
                ),
              ),
            ),

          // Type icon button with popup menu to change type
          PopupMenuButton<PropertyType>(
            tooltip: l10n.propertiesChangeType,
            icon: Icon(_iconForType(widget.type), size: 18),
            onSelected: widget.onChangeType,
            itemBuilder: (context) => [
              for (final t in PropertyType.values)
                PopupMenuItem(
                  value: t,
                  child: Row(
                    children: [
                      Icon(_iconForType(t), size: 18),
                      const SizedBox(width: 8),
                      Text(_labelForType(l10n, t)),
                      if (t == widget.type) ...[
                        const Spacer(),
                        const Icon(Icons.check, size: 16),
                      ],
                    ],
                  ),
                ),
            ],
          ),

          // Key field
          SizedBox(
            width: 130,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _keyController,
                  focusNode: _keyFocusNode,
                  maxLines: 1,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _commitRename(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    border: InputBorder.none,
                  ),
                ),
                if (_keyError != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Text(
                      _keyError!,
                      style: const TextStyle(color: Colors.red, fontSize: 10),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Value widget
          Expanded(child: _buildValueWidget(context)),

          // Desktop right-click / context menu button
          if (isDesktop)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz, size: 18, color: Colors.grey),
              tooltip: '',
              onSelected: (action) {
                switch (action) {
                  case 'moveUp':
                    widget.onMoveUp();
                    break;
                  case 'moveDown':
                    widget.onMoveDown();
                    break;
                  case 'editAsYaml':
                    widget.onEditAsYaml();
                    break;
                  case 'remove':
                    widget.onRemoveKey();
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'moveUp',
                  child: Text(l10n.propertiesMoveUp),
                ),
                PopupMenuItem(
                  value: 'moveDown',
                  child: Text(l10n.propertiesMoveDown),
                ),
                PopupMenuItem(
                  value: 'editAsYaml',
                  child: Text(l10n.propertiesEditAsYaml),
                ),
                PopupMenuItem(
                  value: 'remove',
                  child: Text(l10n.propertiesRemove),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
