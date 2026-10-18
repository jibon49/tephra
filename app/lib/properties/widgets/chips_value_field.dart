// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tephra_search/tephra_search.dart';

import '../../l10n/app_localizations.dart';
import '../property_type.dart';

/// Chips-based input for list properties: [PropertyType.multitext], [PropertyType.aliases], [PropertyType.tags].
class ChipsValueField extends StatefulWidget {
  const ChipsValueField({
    super.key,
    required this.type,
    required this.value,
    required this.onCommit,
    this.suggestionsFetcher,
  });

  final PropertyType type;
  final Object? value;
  final ValueChanged<List<String>> onCommit;
  final Future<List<String>> Function()? suggestionsFetcher;

  @override
  State<ChipsValueField> createState() => _ChipsValueFieldState();
}

class _ChipsValueFieldState extends State<ChipsValueField> {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  List<String> _items = [];
  List<String> _cachedSuggestions = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _items = _parseList(widget.value);
    _loadSuggestions();
  }

  @override
  void didUpdateWidget(ChipsValueField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      setState(() {
        _items = _parseList(widget.value);
      });
    }
    if (widget.suggestionsFetcher != oldWidget.suggestionsFetcher) {
      _loadSuggestions();
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    if (widget.suggestionsFetcher == null) {
      _cachedSuggestions = const [];
      return;
    }
    try {
      final fetched = await widget.suggestionsFetcher!();
      if (mounted) {
        setState(() {
          _cachedSuggestions = fetched;
        });
      }
    } catch (_) {
      // Ignore suggestions fetch error
    }
  }

  List<String> _parseList(Object? val) {
    if (val == null) return [];
    if (val is List) {
      return val
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    final s = val.toString();
    if (widget.type == PropertyType.tags) {
      return s
          .split(RegExp(r'[\s,]+'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return s
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  String? _normalizeTag(String input) {
    var tag = input.trim();
    while (tag.startsWith('#')) {
      tag = tag.substring(1);
    }
    tag = tag.replaceAll(RegExp(r'\s+'), '-');
    tag = tag.replaceAll(RegExp(r'[^\p{L}\p{N}_\-/]', unicode: true), '');
    if (tag.isEmpty) return null;
    if (RegExp(r'^\d+$').hasMatch(tag)) return null;
    return tag;
  }

  void _addCandidate(String raw) {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }

    if (widget.type == PropertyType.tags) {
      final normalized = _normalizeTag(raw);
      if (normalized == null) {
        final l10n = AppLocalizations.of(context);
        setState(() {
          _errorMessage = l10n.propertiesInvalidTag;
        });
        return;
      }
      final updated = List<String>.of(_items)..add(normalized);
      setState(() {
        _items = updated;
      });
      widget.onCommit(updated);
    } else {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return;
      final updated = List<String>.of(_items)..add(trimmed);
      setState(() {
        _items = updated;
      });
      widget.onCommit(updated);
    }
  }

  void _removeAt(int index) {
    if (index < 0 || index >= _items.length) return;
    final updated = List<String>.of(_items)..removeAt(index);
    setState(() {
      _items = updated;
      _errorMessage = null;
    });
    widget.onCommit(updated);
  }

  Iterable<String> _filterSuggestions(TextEditingValue textValue) {
    final q = textValue.text.trim();
    if (q.isEmpty || _cachedSuggestions.isEmpty) {
      return const [];
    }

    final query = (widget.type == PropertyType.tags && q.startsWith('#'))
        ? q.substring(1)
        : q;

    final scored = <({String item, int score})>[];
    for (final candidate in _cachedSuggestions) {
      final score = FuzzyScorer.score(query, candidate);
      if (score != null) {
        scored.add((item: candidate, score: score));
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(8).map((e) => e.item);
  }

  @override
  Widget build(BuildContext context) {
    final isTag = widget.type == PropertyType.tags;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 4,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (var i = 0; i < _items.length; i++)
              Chip(
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                label: Text(
                  isTag ? '#${_items[i]}' : _items[i],
                  style: const TextStyle(fontSize: 12),
                ),
                onDeleted: () => _removeAt(i),
                deleteIconColor: Theme.of(context).colorScheme.outline,
              ),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 100, maxWidth: 220),
              child: RawAutocomplete<String>(
                textEditingController: _inputController,
                focusNode: _inputFocusNode,
                optionsBuilder: _filterSuggestions,
                onSelected: (selection) {
                  _addCandidate(selection);
                  _inputController.clear();
                },
                fieldViewBuilder:
                    (context, controller, focusNode, onFieldSubmitted) {
                      return Focus(
                        onKeyEvent: (node, event) {
                          if (event is KeyDownEvent &&
                              event.logicalKey ==
                                  LogicalKeyboardKey.backspace &&
                              controller.text.isEmpty &&
                              _items.isNotEmpty) {
                            _removeAt(_items.length - 1);
                            return KeyEventResult.handled;
                          }
                          return KeyEventResult.ignored;
                        },
                        child: TextField(
                          controller: controller,
                          focusNode: focusNode,
                          maxLines: 1,
                          textInputAction: TextInputAction.done,
                          onChanged: (text) {
                            if (text.contains(',')) {
                              final parts = text.split(',');
                              controller.clear();
                              for (final part in parts) {
                                if (part.trim().isNotEmpty) {
                                  _addCandidate(part);
                                }
                              }
                            }
                          },
                          onSubmitted: (text) {
                            if (text.isNotEmpty) {
                              _addCandidate(text);
                              controller.clear();
                            }
                          },
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 4,
                            ),
                            border: InputBorder.none,
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
                          maxHeight: 200,
                          maxWidth: 240,
                        ),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: list.length,
                          itemBuilder: (context, index) {
                            final option = list[index];
                            return ListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              title: Text(isTag ? '#$option' : option),
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
          ],
        ),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 11),
            ),
          ),
      ],
    );
  }
}
