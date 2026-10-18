// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_search/tephra_search.dart';

import '../../l10n/app_localizations.dart';

/// Shows the template picker either as a dialog (desktop/tablet) or a full-screen route (phone).
Future<VaultPath?> showTemplatePicker(
  BuildContext context, {
  required List<VaultPath> templates,
}) {
  final isPhone = MediaQuery.sizeOf(context).width < 600;

  if (isPhone) {
    return Navigator.of(context).push<VaultPath>(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          appBar: AppBar(
            title: Text(AppLocalizations.of(ctx).commandInsertTemplate),
          ),
          body: TemplatePicker(
            templates: templates,
            onSelected: (p) => Navigator.of(ctx).pop(p),
          ),
        ),
      ),
    );
  }

  return showDialog<VaultPath>(
    context: context,
    builder: (ctx) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 400),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppLocalizations.of(ctx).commandInsertTemplate,
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TemplatePicker(
                  templates: templates,
                  onSelected: (p) => Navigator.of(ctx).pop(p),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Widget presenting a searchable list of template notes.
class TemplatePicker extends StatefulWidget {
  const TemplatePicker({
    super.key,
    required this.templates,
    required this.onSelected,
  });

  final List<VaultPath> templates;
  final ValueChanged<VaultPath> onSelected;

  @override
  State<TemplatePicker> createState() => _TemplatePickerState();
}

class _TemplatePickerState extends State<TemplatePicker> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onFilterChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onFilterChanged);
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFilterChanged() {
    setState(() {
      _selectedIndex = 0;
    });
  }

  List<VaultPath> _filteredTemplates() {
    final q = _searchController.text.trim();
    if (q.isEmpty) {
      return widget.templates;
    }

    final scored = <({VaultPath path, int score})>[];
    for (final t in widget.templates) {
      final s = FuzzyScorer.score(q, t.stem);
      if (s != null && s >= 0) {
        scored.add((path: t, score: s));
      }
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.map((e) => e.path).toList();
  }

  void _onKeyEvent(KeyEvent event, List<VaultPath> items) {
    if (event is! KeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (items.isEmpty) return;
      setState(() {
        _selectedIndex = (_selectedIndex + 1) % items.length;
      });
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (items.isEmpty) return;
      setState(() {
        _selectedIndex = (_selectedIndex - 1 + items.length) % items.length;
      });
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (items.isNotEmpty &&
          _selectedIndex >= 0 &&
          _selectedIndex < items.length) {
        widget.onSelected(items[_selectedIndex]);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredTemplates();
    final theme = Theme.of(context);
    final isPhone = MediaQuery.sizeOf(context).width < 600;

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: (event) => _onKeyEvent(event, items),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            autofocus: true,
            decoration: const InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('No templates found'))
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final isSelected = index == _selectedIndex;

                      final tile = ListTile(
                        dense: !isPhone,
                        selected: isSelected,
                        selectedTileColor: theme.colorScheme.primaryContainer
                            .withValues(alpha: 0.3),
                        title: Text(item.stem),
                        subtitle: Text(
                          item.value,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.hintColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => widget.onSelected(item),
                      );

                      if (isPhone) {
                        return SizedBox(height: 48.0, child: tile);
                      }
                      return tile;
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
