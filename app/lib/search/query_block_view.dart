// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_index/tephra_index.dart';
import 'package:tephra_search/tephra_search.dart';

import '../core/providers.dart';
import '../l10n/app_localizations.dart';
import '../workspace/providers.dart';
import 'providers.dart';
import 'search_highlights.dart';
import 'search_screen.dart';

/// Embedded query block widget rendering results of a ` ```query ` fenced code block.
class QueryBlockView extends ConsumerStatefulWidget {
  const QueryBlockView({super.key, required this.query});

  final String query;

  @override
  ConsumerState<QueryBlockView> createState() => _QueryBlockViewState();
}

class _QueryBlockViewState extends ConsumerState<QueryBlockView> {
  CancelToken? _cancelToken;
  StreamSubscription<SearchResult>? _searchSub;
  StreamSubscription<IndexEvent>? _indexSub;
  Timer? _indexDebounce;

  List<SearchResult>? _results;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _runQuery();
    _subscribeIndex();
  }

  @override
  void didUpdateWidget(QueryBlockView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != oldWidget.query) {
      _runQuery();
    }
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    _searchSub?.cancel();
    _indexSub?.cancel();
    _indexDebounce?.cancel();
    super.dispose();
  }

  void _subscribeIndex() {
    final index = ref.read(noteIndexProvider).value;
    if (index != null) {
      _indexSub?.cancel();
      _indexSub = index.changes.listen((_) {
        _indexDebounce?.cancel();
        _indexDebounce = Timer(const Duration(milliseconds: 500), () {
          if (mounted) {
            _runQuery();
          }
        });
      });
    }
  }

  void _runQuery() {
    _cancelToken?.cancel();
    _searchSub?.cancel();

    final q = widget.query.trim();
    if (q.isEmpty) {
      setState(() {
        _results = const [];
        _error = null;
        _loading = false;
      });
      return;
    }

    SearchExpr expr;
    try {
      expr = SearchParser.parse(q);
    } catch (e) {
      setState(() {
        _results = null;
        _error = e.toString();
        _loading = false;
      });
      return;
    }

    final token = CancelToken();
    _cancelToken = token;
    final accumulated = <SearchResult>[];

    setState(() {
      _loading = true;
      _error = null;
    });

    final runner = ref.read(searchRunnerProvider);
    if (runner == null) {
      setState(() {
        _loading = false;
        _error = 'Search engine not available';
      });
      return;
    }

    final stream = runner(
      expr,
      cancel: token,
      sort: SearchSort.fileNameAsc,
      matchCase: false,
    );

    _searchSub = stream.listen(
      (res) {
        if (!token.isCancelled) {
          accumulated.add(res);
          setState(() {
            _results = List.unmodifiable(accumulated);
          });
        }
      },
      onError: (Object err) {
        if (!token.isCancelled) {
          setState(() {
            _loading = false;
            _error = err.toString();
          });
        }
      },
      onDone: () {
        if (!token.isCancelled) {
          setState(() {
            _loading = false;
            _results = List.unmodifiable(accumulated);
          });
        }
      },
      cancelOnError: false,
    );
  }

  void _openInSearchPane() {
    final q = widget.query.trim();
    final width = MediaQuery.sizeOf(context).width;

    if (width >= 840) {
      // Desktop: select search tab in left sidebar
      ref.read(searchControllerProvider.notifier).setQuery(q);
      ref.read(activeLeftSidebarPanelProvider.notifier).select('search');
    } else {
      // Phone: push full-screen SearchScreen
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => SearchScreen(initialQuery: q)),
      );
    }
  }

  void _openNote(SearchResult res) {
    ref.read(workspaceProvider.notifier).openPath(res.path);
    final ranges = res.matches
        .where((m) => !m.inFileName)
        .map((m) => (m.start, m.end))
        .toList();
    setNoteSearchHighlights(ref, res.path, ranges);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // If syntax or execution error -> render red-bordered box
    if (_error != null) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.error, width: 1.5),
          borderRadius: BorderRadius.circular(6),
          color: theme.colorScheme.errorContainer.withAlpha(40),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _error!,
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      );
    }

    final results = _results ?? const [];
    final totalCount = results.length;
    final displayResults = results.take(50).toList();
    final hasMore = totalCount > 50;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor.withAlpha(60), width: 1),
        borderRadius: BorderRadius.circular(6),
        color: theme.colorScheme.surfaceContainerLow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withAlpha(60),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(5),
              ),
            ),
            child: Row(
              children: [
                Text(
                  l10n.queryBlockHeader(totalCount),
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_loading) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.open_in_new, size: 16),
                  tooltip: l10n.searchTabTitle,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                  onPressed: _openInSearchPane,
                ),
              ],
            ),
          ),

          // Results list (up to 50 notes)
          if (results.isEmpty && !_loading)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.searchNoResults,
                style: TextStyle(
                  color: theme.colorScheme.outline,
                  fontSize: 13,
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayResults.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, idx) {
                final res = displayResults[idx];
                final snippets = res.matches
                    .where((m) => !m.inFileName)
                    .take(3)
                    .toList();

                return InkWell(
                  onTap: () => _openNote(res),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          res.path.stem,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        if (snippets.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4, left: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: snippets.map((m) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Text(
                                    m.snippet.trim(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),

          // Show all button if > 50
          if (hasMore)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Center(
                child: TextButton(
                  onPressed: _openInSearchPane,
                  child: Text(l10n.queryBlockShowAll(totalCount)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
