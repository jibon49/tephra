// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../search/providers.dart';
import '../vault/providers.dart';
import 'board/board_controller.dart';
import 'data/open_note_bridge.dart';
import 'data/sticky_repository.dart';
import 'model/sticky.dart';
import 'model/sticky_color.dart';

/// State of all active and archived stickies in the open vault.
final class StickiesState {
  const StickiesState({this.all = const [], this.archived = const []});

  /// Active sticky notes (not archived).
  final List<Sticky> all;

  /// Archived sticky notes.
  final List<Sticky> archived;

  /// Filters active stickies by [color].
  List<Sticky> byColor(StickyColor color) =>
      all.where((s) => s.meta.color == color).toList();

  /// Filters active stickies containing [tag].
  List<Sticky> byTag(String tag) =>
      all.where((s) => s.tags.contains(tag)).toList();
}

/// Riverpod Notifier broadcasting current stickies state.
final class StickiesNotifier extends Notifier<StickiesState> {
  @override
  StickiesState build() {
    final repo = ref.watch(stickyRepositoryProvider);
    final sub = repo.changes.listen((_) {
      state = StickiesState(all: repo.all, archived: repo.archived);
    });
    ref.onDispose(sub.cancel);
    return StickiesState(all: repo.all, archived: repo.archived);
  }
}

/// Provider supplying the [OpenNoteBridge] for the open vault.
final openNoteBridgeProvider = Provider<OpenNoteBridge>((ref) {
  final store = ref.watch(noteDocumentStoreProvider);
  final bridge = AppOpenNoteBridge(store);
  ref.onDispose(bridge.dispose);
  return bridge;
});

/// Provider supplying the [StickyRepository] instance for the open vault.
final stickyRepositoryProvider = Provider<StickyRepository>((ref) {
  final fs = ref.watch(vaultFsProvider);
  final search = ref.watch(searchEngineProvider);
  final vaultSettings = ref.watch(vaultSettingsProvider);
  final clock = ref.watch(clockProvider);
  final openNotes = ref.watch(openNoteBridgeProvider);

  final repo = StickyRepository(
    fs: fs,
    search: search,
    settings: StickySettingsView.fromVaultSettings(vaultSettings),
    openNotes: openNotes,
    clock: clock,
  );
  unawaited(repo.start());
  ref.onDispose(() => unawaited(repo.dispose()));
  return repo;
});

/// Provider exposing [StickiesState] with all/archived stickies and filter helpers.
final stickiesProvider = NotifierProvider<StickiesNotifier, StickiesState>(
  StickiesNotifier.new,
);

/// Provider supplying the [BoardController] and [BoardState] for the open vault.
final boardControllerProvider = NotifierProvider<BoardController, BoardState>(
  BoardController.new,
);
