// © 2026 Tephra. All rights reserved.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';

/// Active highlight path currently showing search highlights.
final activeSearchHighlightNoteProvider =
    NotifierProvider<ActiveHighlightNoteNotifier, VaultPath?>(
      ActiveHighlightNoteNotifier.new,
    );

class ActiveHighlightNoteNotifier extends Notifier<VaultPath?> {
  @override
  VaultPath? build() => null;

  void setPath(VaultPath? path) => state = path;
}

/// Manages map of active highlights per note.
class SearchHighlightsStateNotifier
    extends Notifier<Map<VaultPath, List<(int, int)>>> {
  @override
  Map<VaultPath, List<(int, int)>> build() => const {};

  void setHighlights(VaultPath path, List<(int, int)> ranges) {
    state = {path: ranges};
  }

  void clear(VaultPath path) {
    if (state.containsKey(path)) {
      state = const {};
    }
  }
}

/// Provides underlying map of highlights.
final searchHighlightsMapProvider =
    NotifierProvider<
      SearchHighlightsStateNotifier,
      Map<VaultPath, List<(int, int)>>
    >(SearchHighlightsStateNotifier.new);

/// Provides in-note search highlight ranges `[(start, end)]` for [path].
final searchHighlightsProvider = Provider.family<List<(int, int)>, VaultPath>((
  ref,
  path,
) {
  final map = ref.watch(searchHighlightsMapProvider);
  return map[path] ?? const [];
});

/// Sets [ranges] on [path], clearing any previous highlights from another note.
void setNoteSearchHighlights(
  WidgetRef ref,
  VaultPath path,
  List<(int, int)> ranges,
) {
  final prev = ref.read(activeSearchHighlightNoteProvider);
  if (prev != null && prev != path) {
    ref.read(searchHighlightsMapProvider.notifier).clear(prev);
  }
  ref.read(searchHighlightsMapProvider.notifier).setHighlights(path, ranges);
  ref.read(activeSearchHighlightNoteProvider.notifier).setPath(path);
}

/// Clears highlights for [path] on edit.
void clearNoteSearchHighlights(WidgetRef ref, VaultPath path) {
  ref.read(searchHighlightsMapProvider.notifier).clear(path);
  if (ref.read(activeSearchHighlightNoteProvider) == path) {
    ref.read(activeSearchHighlightNoteProvider.notifier).setPath(null);
  }
}
