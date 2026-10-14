// © 2026 Tephra. All rights reserved.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_search/tephra_search.dart';

import '../core/providers.dart';
import '../vault/providers.dart';
import 'search_controller.dart';
import 'search_history_store.dart';

/// Provides the active [SearchEngine] for the open vault session.
final searchEngineProvider = Provider<SearchEngine?>((ref) {
  final session = ref.watch(vaultSessionProvider);
  final index = ref.watch(noteIndexProvider).value;
  if (session == null || index == null) return null;
  return SearchEngine(index, session.fs);
});

/// Function signature executing a search query against an engine.
typedef SearchRunner = Stream<SearchResult> Function(
  SearchExpr expr, {
  CancelToken? cancel,
  SearchSort sort,
  bool matchCase,
});

/// Provides the active [SearchRunner] executing queries against the engine.
final searchRunnerProvider = Provider<SearchRunner?>((ref) {
  final engine = ref.watch(searchEngineProvider);
  if (engine == null) return null;
  return engine.run;
});

/// Provides the [SearchHistoryStore] instance for the open vault.
final searchHistoryStoreProvider = Provider<SearchHistoryStore?>((ref) {
  final session = ref.watch(vaultSessionProvider);
  if (session == null) return null;
  return SearchHistoryStore(session.fs);
});

/// Async notifier managing the list of recent search queries.
class SearchHistoryNotifier extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() async {
    final store = ref.watch(searchHistoryStoreProvider);
    if (store == null) return const [];
    return store.load();
  }

  Future<void> addQuery(String query) async {
    final store = ref.read(searchHistoryStoreProvider);
    if (store == null) return;
    final updated = await store.addQuery(query);
    state = AsyncData(updated);
  }

  Future<void> clear() async {
    final store = ref.read(searchHistoryStoreProvider);
    if (store == null) return;
    await store.clear();
    state = const AsyncData([]);
  }
}

/// Provides recent search history queries.
final searchHistoryProvider =
    AsyncNotifierProvider<SearchHistoryNotifier, List<String>>(
      SearchHistoryNotifier.new,
    );

/// Provides the active [SearchController] and its state.
final searchControllerProvider =
    NotifierProvider<SearchController, SearchState>(SearchController.new);

/// Identifier of the requested sidebar panel to focus (e.g. 'search').
final activeLeftSidebarPanelProvider =
    NotifierProvider<ActiveLeftSidebarNotifier, String?>(
      ActiveLeftSidebarNotifier.new,
    );

class ActiveLeftSidebarNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? panelId) => state = panelId;
}
