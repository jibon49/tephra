// © 2026 Tephra. All rights reserved.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';

import '../core/providers.dart';
import '../vault/providers.dart';
import 'bookmark.dart';
import 'bookmarks_store.dart';

/// Notifier exposing the list of bookmarks and coordinating mutations with [BookmarksStore].
class BookmarksNotifier extends AsyncNotifier<List<Bookmark>> {
  BookmarksStore? _store;

  BookmarksStore? get store => _store;

  @override
  Future<List<Bookmark>> build() async {
    final session = ref.watch(vaultSessionProvider);
    if (session == null) return const [];

    final store = BookmarksStore(session.fs);
    await store.load();
    _store = store;
    return store.items;
  }

  Future<void> add(Bookmark bookmark, {GroupBookmark? into}) async {
    if (_store == null) return;
    await _store!.add(bookmark, into: into);
    state = AsyncData(List<Bookmark>.of(_store!.items));
  }

  Future<void> remove(Bookmark bookmark) async {
    if (_store == null) return;
    await _store!.remove(bookmark);
    state = AsyncData(List<Bookmark>.of(_store!.items));
  }

  Future<void> rename(Bookmark bookmark, String? newTitle) async {
    if (_store == null) return;
    await _store!.rename(bookmark, newTitle);
    state = AsyncData(List<Bookmark>.of(_store!.items));
  }

  Future<void> move(
    Bookmark bookmark,
    GroupBookmark? newParent,
    int targetIndex,
  ) async {
    if (_store == null) return;
    await _store!.move(bookmark, newParent, targetIndex);
    state = AsyncData(List<Bookmark>.of(_store!.items));
  }

  bool isBookmarked(VaultPath path, [String? subpath]) {
    return _store?.isBookmarked(path, subpath) ?? false;
  }

  Future<void> retarget(
    Map<VaultPath, VaultPath> moves, {
    (VaultPath from, VaultPath to)? folderMove,
  }) async {
    if (_store == null) return;
    await _store!.retarget(moves, folderMove: folderMove);
    state = AsyncData(List<Bookmark>.of(_store!.items));
  }

  Future<String?> rawJson() => _store?.rawJson() ?? Future.value(null);

  Future<void> restoreJson(String jsonText) async {
    if (_store == null) return;
    await _store!.restoreJson(jsonText);
    state = AsyncData(List<Bookmark>.of(_store!.items));
  }
}

/// Provider for bookmark list and mutations.
final bookmarksProvider =
    AsyncNotifierProvider<BookmarksNotifier, List<Bookmark>>(
      BookmarksNotifier.new,
    );

/// Provider exposing the set of all indexed file paths (for checking missing targets).
final indexedPathsProvider = FutureProvider<Set<String>>((ref) async {
  ref.watch(indexChangesProvider);
  try {
    final index = await ref.watch(noteIndexProvider.future);
    final files = await index.allFiles();
    return files.map((p) => p.path.value).toSet();
  } catch (_) {
    return const {};
  }
});
