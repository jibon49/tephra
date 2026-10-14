// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_index/tephra_index.dart';
import 'package:tephra_search/tephra_search.dart';

import '../core/providers.dart';
import 'providers.dart';

const _sentinel = Object();

/// State of the search controller and pane.
final class SearchState {
  const SearchState({
    this.query = '',
    this.matchCase = false,
    this.sort = SearchSort.fileNameAsc,
    this.collapseAll = false,
    this.results = const [],
    this.running = false,
    this.error,
    this.elapsedMs,
  });

  final String query;
  final bool matchCase;
  final SearchSort sort;
  final bool collapseAll;
  final List<SearchResult> results;
  final bool running;
  final String? error;
  final int? elapsedMs;

  SearchState copyWith({
    String? query,
    bool? matchCase,
    SearchSort? sort,
    bool? collapseAll,
    List<SearchResult>? results,
    bool? running,
    Object? error = _sentinel,
    Object? elapsedMs = _sentinel,
  }) {
    return SearchState(
      query: query ?? this.query,
      matchCase: matchCase ?? this.matchCase,
      sort: sort ?? this.sort,
      collapseAll: collapseAll ?? this.collapseAll,
      results: results ?? this.results,
      running: running ?? this.running,
      error: identical(error, _sentinel) ? this.error : error as String?,
      elapsedMs: identical(elapsedMs, _sentinel)
          ? this.elapsedMs
          : elapsedMs as int?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchState &&
          query == other.query &&
          matchCase == other.matchCase &&
          sort == other.sort &&
          collapseAll == other.collapseAll &&
          running == other.running &&
          error == other.error &&
          elapsedMs == other.elapsedMs &&
          _listEquals(results, other.results);

  @override
  int get hashCode => Object.hash(
    query,
    matchCase,
    sort,
    collapseAll,
    running,
    error,
    elapsedMs,
    Object.hashAll(results),
  );

  static bool _listEquals(List<SearchResult> a, List<SearchResult> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Controller executing queries against [SearchEngine], debouncing keystrokes,
/// cancelling tokens and re-running on index changes.
class SearchController extends Notifier<SearchState> {
  Timer? _debounceTimer;
  Timer? _indexDebounceTimer;
  CancelToken? _cancelToken;
  StreamSubscription<SearchResult>? _searchSub;
  StreamSubscription<IndexEvent>? _indexSub;

  @override
  SearchState build() {
    ref.onDispose(() {
      _debounceTimer?.cancel();
      _indexDebounceTimer?.cancel();
      _cancelToken?.cancel();
      _searchSub?.cancel();
      _indexSub?.cancel();
    });

    void subscribe(NoteIndex? index) {
      _indexSub?.cancel();
      if (index != null) {
        _indexSub = index.changes.listen((_) {
          if (state.query.trim().isNotEmpty) {
            _indexDebounceTimer?.cancel();
            _indexDebounceTimer = Timer(const Duration(milliseconds: 500), () {
              if (state.query.trim().isNotEmpty) {
                _executeSearch();
              }
            });
          }
        });
      }
    }

    ref.listen(noteIndexProvider, (prev, next) {
      subscribe(next.value);
    });

    subscribe(ref.read(noteIndexProvider).value);

    return const SearchState();
  }

  /// Sets the search query with 250 ms debounce.
  void setQuery(String q) {
    if (state.query == q) return;
    state = state.copyWith(query: q);

    _debounceTimer?.cancel();
    _cancelToken?.cancel();
    _searchSub?.cancel();

    final trimmed = q.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(
        results: const [],
        running: false,
        error: null,
        elapsedMs: null,
      );
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 250), _executeSearch);
  }

  /// Sets the result sorting order and re-runs immediately if query is non-empty.
  void setSort(SearchSort sort) {
    if (state.sort == sort) return;
    state = state.copyWith(sort: sort);
    if (state.query.trim().isNotEmpty) {
      _executeSearch();
    }
  }

  /// Sets the match-case flag and re-runs immediately if query is non-empty.
  void setMatchCase(bool matchCase) {
    if (state.matchCase == matchCase) return;
    state = state.copyWith(matchCase: matchCase);
    if (state.query.trim().isNotEmpty) {
      _executeSearch();
    }
  }

  /// Sets the global collapsed state of result groups.
  void setCollapseAll(bool collapseAll) {
    state = state.copyWith(collapseAll: collapseAll);
  }

  /// Toggles the global collapsed state of result groups.
  void toggleCollapseAll() {
    state = state.copyWith(collapseAll: !state.collapseAll);
  }

  /// Re-runs the current query immediately.
  void reRun() {
    if (state.query.trim().isNotEmpty) {
      _executeSearch();
    }
  }

  void _executeSearch() {
    _debounceTimer?.cancel();
    _cancelToken?.cancel();
    _searchSub?.cancel();

    final q = state.query.trim();
    if (q.isEmpty) {
      state = state.copyWith(
        results: const [],
        running: false,
        error: null,
        elapsedMs: null,
      );
      return;
    }

    SearchExpr expr;
    try {
      expr = SearchParser.parse(q);
    } on SearchSyntaxException catch (e) {
      state = state.copyWith(
        error: 'Search syntax error at character ${e.offset}',
        results: const [],
        running: false,
        elapsedMs: null,
      );
      return;
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        results: const [],
        running: false,
        elapsedMs: null,
      );
      return;
    }

    final token = CancelToken();
    _cancelToken = token;
    final accumulated = <SearchResult>[];

    state = state.copyWith(
      running: true,
      error: null,
      results: const [],
      elapsedMs: null,
    );

    final sw = Stopwatch()..start();
    final runner = ref.read(searchRunnerProvider);

    if (runner == null) {
      state = state.copyWith(
        running: false,
        error: 'Search engine not available',
      );
      return;
    }

    final stream = runner(
      expr,
      cancel: token,
      sort: state.sort,
      matchCase: state.matchCase,
    );

    _searchSub = stream.listen(
      (res) {
        if (!token.isCancelled) {
          accumulated.add(res);
          state = state.copyWith(results: List.unmodifiable(accumulated));
        }
      },
      onError: (Object err) {
        if (!token.isCancelled) {
          state = state.copyWith(error: err.toString(), running: false);
        }
      },
      onDone: () {
        if (!token.isCancelled) {
          sw.stop();
          state = state.copyWith(
            running: false,
            elapsedMs: sw.elapsedMilliseconds,
          );
        }
      },
      cancelOnError: false,
    );
  }
}
