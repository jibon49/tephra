// © 2026 Tephra. All rights reserved.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';

import '../core/providers.dart';
import 'link_navigator.dart';

/// Provider for [LinkNavigator].
final linkNavigatorProvider = Provider<LinkNavigator>((ref) {
  return LinkNavigator(ref);
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
