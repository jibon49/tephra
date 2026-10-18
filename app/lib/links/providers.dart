// © 2026 Tephra. All rights reserved.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/tephra_index.dart';

import '../core/providers.dart';
import 'link_navigator.dart';
import 'unlinked_mention_linker.dart';

export 'link_navigator.dart';
export 'link_rename_service.dart';
export 'unlinked_mention_linker.dart';

/// Provider for [LinkNavigator].
final linkNavigatorProvider = Provider<LinkNavigator>((ref) {
  return LinkNavigator(ref);
});

/// Provider for [UnlinkedMentionLinker].
final unlinkedMentionLinkerProvider = Provider<UnlinkedMentionLinker>((ref) {
  return UnlinkedMentionLinker(ref);
});

/// FutureProvider resolving a link from a note to a vault path.
/// Invalidates whenever index changes occur.
final linkResolutionProvider =
    FutureProvider.family<VaultPath?, (VaultPath from, String target)>((
      ref,
      arg,
    ) async {
      ref.watch(indexChangesProvider);
      final index = await ref.watch(noteIndexProvider.future);
      return index.resolveLink(arg.$2, from: arg.$1);
    });

/// Backlinks targeting [path], refreshed on index changes.
final backlinksProvider = FutureProvider.family<List<LinkRecord>, VaultPath>((
  ref,
  path,
) async {
  ref.watch(indexChangesProvider);
  final index = await ref.watch(noteIndexProvider.future);
  return index.backlinks(path);
});

/// Outgoing links from [path], refreshed on index changes.
final outgoingLinksProvider =
    FutureProvider.family<List<LinkRecord>, VaultPath>((ref, path) async {
      ref.watch(indexChangesProvider);
      final index = await ref.watch(noteIndexProvider.future);
      return index.outgoing(path);
    });

/// Unlinked mentions of [path], refreshed on index changes.
final unlinkedMentionsProvider =
    FutureProvider.family<List<UnlinkedMention>, VaultPath>((ref, path) async {
      ref.watch(indexChangesProvider);
      final index = await ref.watch(noteIndexProvider.future);
      return index.unlinkedMentions(path);
    });
