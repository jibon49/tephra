// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_markdown/tephra_markdown.dart';
import 'package:tephra_search/tephra_search.dart';
import 'package:yaml/yaml.dart';

import '../core/providers.dart';
import '../editor/editor_controller.dart';
import '../l10n/app_localizations.dart';
import '../tags/providers.dart';
import 'frontmatter_editor.dart';
import 'property_row.dart';
import 'property_type.dart';
import 'property_type_registry.dart';
import 'property_value_codec.dart';
import 'providers.dart';
import 'raw_yaml_editor.dart';

/// Panel shown above the note in Live Preview displaying frontmatter properties.
class PropertiesPanel extends ConsumerStatefulWidget {
  const PropertiesPanel({super.key, required this.controller});

  final EditorController controller;

  @override
  ConsumerState<PropertiesPanel> createState() => _PropertiesPanelState();
}

class _PropertiesPanelState extends ConsumerState<PropertiesPanel> {
  bool _collapsed = false;
  bool _isEditingAsYaml = false;
  bool _isAddingProperty = false;

  Map<String, Object?> _properties = {};
  bool _isYamlValid = true;
  String? _yamlError;
  String _rawYaml = '';

  StreamSubscription<EditorEdit>? _editsSub;
  Timer? _debounceTimer;

  final TextEditingController _newKeyController = TextEditingController();
  final FocusNode _newKeyFocusNode = FocusNode();
  String? _newKeyError;

  @override
  void initState() {
    super.initState();
    _parseFrontmatter();
    _editsSub = widget.controller.edits.listen((_) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(
        const Duration(milliseconds: 150),
        _parseFrontmatter,
      );
    });
  }

  @override
  void didUpdateWidget(PropertiesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _editsSub?.cancel();
      _editsSub = widget.controller.edits.listen((_) {
        _debounceTimer?.cancel();
        _debounceTimer = Timer(
          const Duration(milliseconds: 150),
          _parseFrontmatter,
        );
      });
      _parseFrontmatter();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _editsSub?.cancel();
    _newKeyController.dispose();
    _newKeyFocusNode.dispose();
    super.dispose();
  }

  void _parseFrontmatter() {
    final text = widget.controller.text;
    final split = splitFrontmatter(text);
    if (split == null) {
      if (mounted) {
        setState(() {
          _properties = {};
          _isYamlValid = true;
          _yamlError = null;
          _rawYaml = '';
        });
      }
      return;
    }

    _rawYaml = split.yaml;
    try {
      final dynamic loaded = loadYaml(split.yaml);
      if (loaded == null) {
        if (mounted) {
          setState(() {
            _properties = {};
            _isYamlValid = true;
            _yamlError = null;
          });
        }
      } else if (loaded is! Map) {
        if (mounted) {
          setState(() {
            _properties = {};
            _isYamlValid = false;
            _yamlError = 'YAML frontmatter must be a mapping';
          });
        }
      } else {
        final props = FrontmatterEditor.read(text);
        if (mounted) {
          setState(() {
            _properties = props;
            _isYamlValid = true;
            _yamlError = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _properties = {};
          _isYamlValid = false;
          _yamlError = e.toString();
        });
      }
    }
  }

  PropertyType _typeFor(
    String key,
    Object? value,
    PropertyTypeRegistry? registry,
  ) {
    if (registry != null) {
      return registry.typeFor(key, value);
    }
    final lowerKey = key.toLowerCase();
    if (lowerKey == 'tags') return PropertyType.tags;
    if (lowerKey == 'aliases') return PropertyType.aliases;
    if (lowerKey == 'cssclasses') return PropertyType.multitext;

    if (value is bool) return PropertyType.checkbox;
    if (value is num) return PropertyType.number;
    if (value is List) return PropertyType.multitext;
    if (value is String) {
      final s = value.trim();
      if (RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2})?$').hasMatch(s)) {
        return PropertyType.datetime;
      }
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) {
        return PropertyType.date;
      }
    }
    return PropertyType.text;
  }

  void _onRenameKey(String oldKey, String newKey) {
    final edit = FrontmatterEditor.renameKey(
      widget.controller.text,
      oldKey,
      newKey,
    );
    if (edit != null) {
      widget.controller.applyEdits([edit]);
      _parseFrontmatter();
    }
  }

  void _onSetValue(String key, Object? newValue) {
    final edit = FrontmatterEditor.setValue(
      widget.controller.text,
      key,
      newValue,
    );
    if (edit != null) {
      widget.controller.applyEdits([edit]);
      _parseFrontmatter();
    }
  }

  void _onRemoveKey(String key) {
    final edit = FrontmatterEditor.removeKey(widget.controller.text, key);
    if (edit != null) {
      widget.controller.applyEdits([edit]);
      _parseFrontmatter();
    }
  }

  void _onMoveKey(String key, int newIndex) {
    final edit = FrontmatterEditor.moveKey(
      widget.controller.text,
      key,
      newIndex,
    );
    if (edit != null) {
      widget.controller.applyEdits([edit]);
      _parseFrontmatter();
    }
  }

  Future<void> _onChangeType(
    String key,
    Object? currentValue,
    PropertyType newType,
  ) async {
    final l10n = AppLocalizations.of(context);
    final res = PropertyValueCodec.convert(currentValue, newType);
    if (res.ok) {
      final edit = FrontmatterEditor.setValue(
        widget.controller.text,
        key,
        res.value,
      );
      if (edit != null) {
        widget.controller.applyEdits([edit]);
        _parseFrontmatter();
      }
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.propertiesConvertFailed)));
    }
    try {
      await ref
          .read(propertyTypeRegistryProvider.notifier)
          .setType(key, newType);
    } catch (_) {}
  }

  void _commitAddProperty(String rawKey) {
    final key = rawKey.trim();
    if (key.isEmpty) {
      setState(() {
        _isAddingProperty = false;
        _newKeyError = null;
        _newKeyController.clear();
      });
      return;
    }

    if (_properties.keys.any((k) => k.toLowerCase() == key.toLowerCase())) {
      final l10n = AppLocalizations.of(context);
      setState(() {
        _newKeyError = l10n.propertiesKeyExists;
      });
      return;
    }

    final registry = ref.read(propertyTypeRegistryProvider).value;
    final type = _typeFor(key, null, registry);

    Object? initialValue;
    switch (type) {
      case PropertyType.checkbox:
        initialValue = false;
        break;
      case PropertyType.multitext:
      case PropertyType.aliases:
      case PropertyType.tags:
        initialValue = const [];
        break;
      case PropertyType.text:
      case PropertyType.number:
      case PropertyType.date:
      case PropertyType.datetime:
        initialValue = null;
        break;
    }

    final edit = FrontmatterEditor.setValue(
      widget.controller.text,
      key,
      initialValue,
    );
    if (edit != null) {
      widget.controller.applyEdits([edit]);
    }

    setState(() {
      _isAddingProperty = false;
      _newKeyError = null;
      _newKeyController.clear();
    });
    _parseFrontmatter();
  }

  Widget _buildHeader(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final count = _properties.length;
    final isNarrow = MediaQuery.sizeOf(context).width < 500;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _collapsed ? Icons.chevron_right : Icons.expand_more,
              size: 20,
            ),
            splashRadius: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: () {
              setState(() {
                _collapsed = !_collapsed;
              });
            },
          ),
          Text(
            l10n.propertiesTitle,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
          const Spacer(),
          if (isNarrow)
            IconButton(
              icon: const Icon(Icons.add, size: 20),
              tooltip: l10n.propertiesAdd,
              splashRadius: 16,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: () {
                setState(() {
                  _collapsed = false;
                  _isAddingProperty = true;
                });
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _newKeyFocusNode.requestFocus();
                });
              },
            )
          else
            TextButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: Text(
                l10n.propertiesAdd,
                style: const TextStyle(fontSize: 12),
              ),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              onPressed: () {
                setState(() {
                  _collapsed = false;
                  _isAddingProperty = true;
                });
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _newKeyFocusNode.requestFocus();
                });
              },
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz, size: 18),
            splashRadius: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onSelected: (action) {
              if (action == 'yaml') {
                setState(() => _isEditingAsYaml = true);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'yaml',
                child: Text(l10n.propertiesEditAsYaml),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddPropertyRow(BuildContext context) {
    final availableKeysAsync = ref.watch(propertyKeysProvider);
    final existing = _properties.keys.map((k) => k.toLowerCase()).toSet();
    final suggestions =
        availableKeysAsync.value
            ?.map((k) => k.key)
            .where((k) => !existing.contains(k.toLowerCase()))
            .toList() ??
        const [];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          const SizedBox(width: 48),
          SizedBox(
            width: 140,
            child: RawAutocomplete<String>(
              textEditingController: _newKeyController,
              focusNode: _newKeyFocusNode,
              optionsBuilder: (textEditingValue) {
                final q = textEditingValue.text.trim();
                if (q.isEmpty) return suggestions.take(8);
                final scored = <({String item, int score})>[];
                for (final candidate in suggestions) {
                  final score = FuzzyScorer.score(q, candidate);
                  if (score != null) {
                    scored.add((item: candidate, score: score));
                  }
                }
                scored.sort((a, b) => b.score.compareTo(a.score));
                return scored.take(8).map((e) => e.item);
              },
              onSelected: (selection) {
                _commitAddProperty(selection);
              },
              fieldViewBuilder:
                  (context, controller, focusNode, onFieldSubmitted) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      maxLines: 1,
                      textInputAction: TextInputAction.done,
                      onSubmitted: _commitAddProperty,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Property name',
                        errorText: _newKeyError,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 8,
                        ),
                      ),
                    );
                  },
              optionsViewBuilder: (context, onSelected, options) {
                final list = options.toList();
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(4),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxHeight: 180,
                        maxWidth: 200,
                      ),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final option = list[index];
                          return ListTile(
                            dense: true,
                            title: Text(option),
                            onTap: () => onSelected(option),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.check, size: 18),
            splashRadius: 16,
            onPressed: () => _commitAddProperty(_newKeyController.text),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            splashRadius: 16,
            onPressed: () {
              setState(() {
                _isAddingProperty = false;
                _newKeyError = null;
                _newKeyController.clear();
              });
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final registry = ref.watch(propertyTypeRegistryProvider).value;
    final keys = _properties.keys.toList();
    final paneHeight = MediaQuery.sizeOf(context).height;
    final isDesktop = MediaQuery.sizeOf(context).width >= 600;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(context),
          if (!_collapsed) ...[
            if (!_isYamlValid || _isEditingAsYaml) ...[
              if (!_isYamlValid)
                Container(
                  color: Colors.red.withAlpha(25),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.propertiesInvalidYaml,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: RawYamlEditor(
                  initialYaml: _rawYaml,
                  errorMessage: _yamlError,
                  onApply: (newYaml) {
                    final edit = FrontmatterEditor.replaceRaw(
                      widget.controller.text,
                      newYaml,
                    );
                    if (edit != null) {
                      widget.controller.applyEdits([edit]);
                    }
                    setState(() {
                      _isEditingAsYaml = false;
                    });
                    _parseFrontmatter();
                  },
                  onRevert: () {
                    setState(() {
                      _isEditingAsYaml = false;
                    });
                    _parseFrontmatter();
                  },
                ),
              ),
            ] else ...[
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: paneHeight * 0.40),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isDesktop)
                        ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: keys.length,
                          buildDefaultDragHandles: false,
                          onReorderItem: (oldIndex, newIndex) {
                            _onMoveKey(keys[oldIndex], newIndex);
                          },
                          itemBuilder: (context, index) {
                            final key = keys[index];
                            final val = _properties[key];
                            final type = _typeFor(key, val, registry);

                            return PropertyRow(
                              key: ValueKey('prop_$key'),
                              index: index,
                              propertyKey: key,
                              value: val,
                              type: type,
                              existingKeys: keys,
                              onRenameKey: _onRenameKey,
                              onSetValue: (v) => _onSetValue(key, v),
                              onRemoveKey: () => _onRemoveKey(key),
                              onMoveUp: () {
                                if (index > 0) _onMoveKey(key, index - 1);
                              },
                              onMoveDown: () {
                                if (index < keys.length - 1) {
                                  _onMoveKey(key, index + 1);
                                }
                              },
                              onChangeType: (newType) =>
                                  _onChangeType(key, val, newType),
                              onEditAsYaml: () {
                                setState(() => _isEditingAsYaml = true);
                              },
                              suggestionsFetcher: type == PropertyType.tags
                                  ? () async {
                                      final tags = await ref.read(
                                        tagListProvider.future,
                                      );
                                      return tags.map((t) => t.tag).toList();
                                    }
                                  : () async {
                                      final idx = await ref.read(
                                        noteIndexProvider.future,
                                      );
                                      return idx.propertyValues(key);
                                    },
                            );
                          },
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: keys.length,
                          itemBuilder: (context, index) {
                            final key = keys[index];
                            final val = _properties[key];
                            final type = _typeFor(key, val, registry);

                            return PropertyRow(
                              key: ValueKey('prop_$key'),
                              index: index,
                              propertyKey: key,
                              value: val,
                              type: type,
                              existingKeys: keys,
                              onRenameKey: _onRenameKey,
                              onSetValue: (v) => _onSetValue(key, v),
                              onRemoveKey: () => _onRemoveKey(key),
                              onMoveUp: () {
                                if (index > 0) _onMoveKey(key, index - 1);
                              },
                              onMoveDown: () {
                                if (index < keys.length - 1) {
                                  _onMoveKey(key, index + 1);
                                }
                              },
                              onChangeType: (newType) =>
                                  _onChangeType(key, val, newType),
                              onEditAsYaml: () {
                                setState(() => _isEditingAsYaml = true);
                              },
                              suggestionsFetcher: type == PropertyType.tags
                                  ? () async {
                                      final tags = await ref.read(
                                        tagListProvider.future,
                                      );
                                      return tags.map((t) => t.tag).toList();
                                    }
                                  : () async {
                                      final idx = await ref.read(
                                        noteIndexProvider.future,
                                      );
                                      return idx.propertyValues(key);
                                    },
                            );
                          },
                        ),
                      if (_isAddingProperty) _buildAddPropertyRow(context),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
