// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_index/tephra_index.dart';

import '../core/providers.dart';
import 'tag_tree.dart';

/// Tag tree sort mode notifier.
final class TagSortModeNotifier extends Notifier<TagSortMode> {
  @override
  TagSortMode build() => TagSortMode.nameAZ;

  void setMode(TagSortMode mode) => state = mode;
}

final tagSortModeProvider = NotifierProvider<TagSortModeNotifier, TagSortMode>(
  TagSortModeNotifier.new,
);

/// Whether to show nested tag tree or flat tag list.
final class TagShowNestedNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
  void setNested(bool value) => state = value;
}

final tagShowNestedProvider = NotifierProvider<TagShowNestedNotifier, bool>(
  TagShowNestedNotifier.new,
);

/// FutureProvider for the raw list of [TagCount] from the index,
/// refreshed on index changes (debounced 500 ms).
final tagListProvider = FutureProvider<List<TagCount>>((ref) async {
  final changes = ref.watch(indexChangesProvider);
  if (changes.hasValue) {
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  final index = await ref.watch(noteIndexProvider.future);
  return index.tags();
});

/// Tag nodes provider, computing either a tree or a flat list based on user settings.
final tagTreeProvider = Provider<AsyncValue<List<TagNode>>>((ref) {
  final listAsync = ref.watch(tagListProvider);
  final sortMode = ref.watch(tagSortModeProvider);
  final showNested = ref.watch(tagShowNestedProvider);

  return listAsync.whenData((tags) {
    if (showNested) {
      return buildTagTree(tags, sortMode: sortMode);
    } else {
      return buildFlatTagList(tags, sortMode: sortMode);
    }
  });
});
