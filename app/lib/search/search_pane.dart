// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_search/tephra_search.dart';

import '../editor/providers.dart';
import '../l10n/app_localizations.dart';
import '../workspace/providers.dart';
import 'copy_results.dart';
import 'providers.dart';
import 'search_controller.dart';
import 'search_highlights.dart';

/// Desktop & tablet search pane displayed inside the left sidebar.
class SearchPane extends ConsumerStatefulWidget {
  const SearchPane({super.key, this.autofocus = false, this.initialQuery});

  final bool autofocus;
  final String? initialQuery;

  @override
  ConsumerState<SearchPane> createState() => _SearchPaneState();
}

class _SearchPaneState extends ConsumerState<SearchPane> {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;
  final Set<VaultPath> _collapsedNotes = {};
  bool _showHistory = false;

  @override
  void initState() {
    super.initState();
    final initial =
        widget.initialQuery ?? ref.read(searchControllerProvider).query;
    _textController = TextEditingController(text: initial);
    _focusNode = FocusNode();

    _focusNode.addListener(_onFocusChange);
    _textController.addListener(_onTextChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _textController.removeListener(_onTextChange);
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _showHistory = _focusNode.hasFocus && _textController.text.trim().isEmpty;
    });
  }

  void _onTextChange() {
    final hasText = _textController.text.trim().isNotEmpty;
    if (_showHistory && hasText) {
      setState(() => _showHistory = false);
    } else if (!_showHistory && !hasText && _focusNode.hasFocus) {
      setState(() => _showHistory = true);
    }
  }

  void _submitQuery(String q) {
    final trimmed = q.trim();
    if (trimmed.isNotEmpty) {
      ref.read(searchHistoryProvider.notifier).addQuery(trimmed);
      ref.read(searchControllerProvider.notifier).setQuery(trimmed);
    }
  }

  void _openResult(SearchResult res, {SearchMatch? specificMatch}) {
    final query = _textController.text.trim();
    if (query.isNotEmpty) {
      ref.read(searchHistoryProvider.notifier).addQuery(query);
    }

    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    ref.read(workspaceProvider.notifier).openPath(res.path, newTab: isCtrl);

    // Collect highlight ranges
    final ranges = res.matches
        .where((m) => !m.inFileName)
        .map((m) => (m.start, m.end))
        .toList();

    if (specificMatch != null && !specificMatch.inFileName) {
      ranges.removeWhere(
        (r) => r.$1 == specificMatch.start && r.$2 == specificMatch.end,
      );
      ranges.insert(0, (specificMatch.start, specificMatch.end));
    }

    setNoteSearchHighlights(ref, res.path, ranges);

    // Select in editor if editor is open
    if (specificMatch != null && !specificMatch.inFileName) {
      final editor = ref.read(activeEditorProvider);
      if (editor != null && editor.path == res.path) {
        editor.select(specificMatch.start, specificMatch.end);
        editor.revealOffset(specificMatch.start);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final searchState = ref.watch(searchControllerProvider);
    final searchCtrl = ref.read(searchControllerProvider.notifier);
    final historyAsync = ref.watch(searchHistoryProvider);

    // Sync external query changes if controller changed externally
    if (searchState.query != _textController.text && !_focusNode.hasFocus) {
      _textController.text = searchState.query;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top search input row
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: TextField(
            controller: _textController,
            focusNode: _focusNode,
            autofocus: widget.autofocus,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l10n.searchFieldHint,
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _textController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _textController.clear();
                        searchCtrl.setQuery('');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 8,
                horizontal: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            onChanged: (val) => searchCtrl.setQuery(val),
            onSubmitted: _submitQuery,
          ),
        ),

        // Controls bar: Match case, Sort, Collapse, Overflow
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              // Match case toggle
              IconButton(
                icon: const Text(
                  'Aa',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                tooltip: l10n.searchMatchCase,
                isSelected: searchState.matchCase,
                style: IconButton.styleFrom(
                  backgroundColor: searchState.matchCase
                      ? theme.colorScheme.primaryContainer
                      : null,
                ),
                onPressed: () =>
                    searchCtrl.setMatchCase(!searchState.matchCase),
              ),

              // Sort menu
              PopupMenuButton<SearchSort>(
                icon: const Icon(Icons.sort, size: 20),
                tooltip: _sortLabel(l10n, searchState.sort),
                initialValue: searchState.sort,
                onSelected: searchCtrl.setSort,
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: SearchSort.fileNameAsc,
                    child: Text(l10n.searchSortFileNameAsc),
                  ),
                  PopupMenuItem(
                    value: SearchSort.fileNameDesc,
                    child: Text(l10n.searchSortFileNameDesc),
                  ),
                  PopupMenuItem(
                    value: SearchSort.modifiedDesc,
                    child: Text(l10n.searchSortModifiedDesc),
                  ),
                  PopupMenuItem(
                    value: SearchSort.modifiedAsc,
                    child: Text(l10n.searchSortModifiedAsc),
                  ),
                  PopupMenuItem(
                    value: SearchSort.createdDesc,
                    child: Text(l10n.searchSortCreatedDesc),
                  ),
                  PopupMenuItem(
                    value: SearchSort.createdAsc,
                    child: Text(l10n.searchSortCreatedAsc),
                  ),
                ],
              ),

              // Collapse / Expand toggle
              IconButton(
                icon: Icon(
                  searchState.collapseAll
                      ? Icons.unfold_more
                      : Icons.unfold_less,
                  size: 20,
                ),
                tooltip: searchState.collapseAll
                    ? l10n.searchExpandAll
                    : l10n.searchCollapseAll,
                onPressed: () {
                  final next = !searchState.collapseAll;
                  searchCtrl.setCollapseAll(next);
                  setState(() => _collapsedNotes.clear());
                },
              ),

              const Spacer(),

              // Overflow menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'copy',
                    enabled: searchState.results.isNotEmpty,
                    child: Text(l10n.searchCopyResults),
                  ),
                  PopupMenuItem(
                    value: 'bookmark',
                    enabled: false,
                    child: Text(l10n.searchBookmarkThis),
                  ),
                ],
                onSelected: (val) {
                  if (val == 'copy') {
                    copyResultsToClipboard(context, ref, searchState.results);
                  }
                },
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // Result count / status header
        if (searchState.error != null)
          Container(
            padding: const EdgeInsets.all(8),
            color: theme.colorScheme.errorContainer.withAlpha(50),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 16,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    searchState.error!,
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (searchState.query.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Text(
                  l10n.searchResultCount(searchState.results.length),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (searchState.elapsedMs != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    '(${searchState.elapsedMs} ms)',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
                const Spacer(),
                if (searchState.running)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),

        // Main content: History OR Results
        Expanded(
          child: _showHistory
              ? _buildHistoryList(l10n, historyAsync.value ?? const [])
              : _buildResultsList(l10n, theme, searchState),
        ),
      ],
    );
  }

  Widget _buildHistoryList(AppLocalizations l10n, List<String> queries) {
    if (queries.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Text(
            l10n.searchHistoryTitle,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: queries.length,
            itemBuilder: (context, idx) {
              final q = queries[idx];
              return ListTile(
                dense: true,
                leading: const Icon(Icons.history, size: 18),
                title: Text(q, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () {
                  _textController.text = q;
                  _focusNode.unfocus();
                  _submitQuery(q);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResultsList(
    AppLocalizations l10n,
    ThemeData theme,
    SearchState searchState,
  ) {
    if (!searchState.running &&
        searchState.error == null &&
        searchState.query.trim().isNotEmpty &&
        searchState.results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            l10n.searchNoResults,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    final results = searchState.results;

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, idx) {
        final res = results[idx];
        final isCollapsed = searchState.collapseAll
            ? !_collapsedNotes.contains(res.path)
            : _collapsedNotes.contains(res.path);

        return _buildNoteGroup(l10n, theme, res, isCollapsed);
      },
    );
  }

  Widget _buildNoteGroup(
    AppLocalizations l10n,
    ThemeData theme,
    SearchResult res,
    bool isCollapsed,
  ) {
    final parentFolder = res.path.parent?.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Note Title Row
        InkWell(
          onTap: () => _openResult(res),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    isCollapsed ? Icons.chevron_right : Icons.expand_more,
                    size: 18,
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                  onPressed: () {
                    setState(() {
                      if (_collapsedNotes.contains(res.path)) {
                        _collapsedNotes.remove(res.path);
                      } else {
                        _collapsedNotes.add(res.path);
                      }
                    });
                  },
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        res.path.stem,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (parentFolder != null && parentFolder.isNotEmpty)
                        Text(
                          parentFolder,
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.outline,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${res.matches.length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Matches list
        if (!isCollapsed)
          Padding(
            padding: const EdgeInsets.only(left: 28, right: 8, bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: res.matches.map((m) {
                return InkWell(
                  onTap: () => _openResult(res, specificMatch: m),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 3,
                      horizontal: 4,
                    ),
                    child: _buildMatchSnippet(l10n, theme, m),
                  ),
                );
              }).toList(),
            ),
          ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildMatchSnippet(
    AppLocalizations l10n,
    ThemeData theme,
    SearchMatch m,
  ) {
    if (m.inFileName) {
      return Text(
        l10n.searchMatchedFileName,
        style: TextStyle(
          fontStyle: FontStyle.italic,
          fontSize: 12,
          color: theme.colorScheme.outline,
        ),
      );
    }

    final snippet = m.snippet;
    final start = m.snippetStart.clamp(0, snippet.length);
    final end = m.snippetEnd.clamp(start, snippet.length);

    final before = snippet.substring(0, start);
    final match = snippet.substring(start, end);
    final after = snippet.substring(end);

    return RichText(
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
        children: [
          TextSpan(text: before),
          TextSpan(
            text: match,
            style: TextStyle(
              backgroundColor: theme.colorScheme.primaryContainer.withAlpha(
                180,
              ),
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(text: after),
        ],
      ),
    );
  }

  String _sortLabel(AppLocalizations l10n, SearchSort sort) {
    switch (sort) {
      case SearchSort.fileNameAsc:
        return l10n.searchSortFileNameAsc;
      case SearchSort.fileNameDesc:
        return l10n.searchSortFileNameDesc;
      case SearchSort.modifiedDesc:
        return l10n.searchSortModifiedDesc;
      case SearchSort.modifiedAsc:
        return l10n.searchSortModifiedAsc;
      case SearchSort.createdDesc:
        return l10n.searchSortCreatedDesc;
      case SearchSort.createdAsc:
        return l10n.searchSortCreatedAsc;
    }
  }
}
