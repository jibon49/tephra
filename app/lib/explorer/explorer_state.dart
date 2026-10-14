// © 2026 Tephra. All rights reserved.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../settings/providers.dart';
import '../vault/providers.dart';
import 'explorer_rows.dart';
import 'explorer_sort.dart';
import 'visible_file_types.dart';

/// Manages the set of expanded folder paths in the file explorer.
final class ExplorerExpandedNotifier extends Notifier<Set<VaultPath>> {
  @override
  Set<VaultPath> build() => const {};

  void toggle(VaultPath path) {
    if (state.contains(path)) {
      state = Set<VaultPath>.unmodifiable(state.where((p) => p != path));
    } else {
      state = Set<VaultPath>.unmodifiable({...state, path});
    }
  }

  void expand(VaultPath path) {
    if (!state.contains(path)) {
      state = Set<VaultPath>.unmodifiable({...state, path});
    }
  }

  void collapse(VaultPath path) {
    if (state.contains(path)) {
      state = Set<VaultPath>.unmodifiable(state.where((p) => p != path));
    }
  }

  void expandAncestors(VaultPath path) {
    final toAdd = <VaultPath>{};
    var current = path.parent;
    while (current != null && !current.isRoot) {
      toAdd.add(current);
      current = current.parent;
    }
    if (toAdd.isNotEmpty) {
      state = Set<VaultPath>.unmodifiable({...state, ...toAdd});
    }
  }

  void collapseAll() {
    state = const {};
  }

  void retarget(VaultPath from, VaultPath to) {
    final updated = <VaultPath>{};
    for (final p in state) {
      if (p == from) {
        updated.add(to);
      } else if (p.isWithin(from)) {
        final rel = p.value.substring(from.value.length);
        updated.add(VaultPath('${to.value}$rel'));
      } else {
        updated.add(p);
      }
    }
    state = Set<VaultPath>.unmodifiable(updated);
  }
}

final explorerExpandedProvider =
    NotifierProvider<ExplorerExpandedNotifier, Set<VaultPath>>(
      ExplorerExpandedNotifier.new,
    );

/// Manages single selection in the file explorer.
final class ExplorerSelectedNotifier extends Notifier<VaultPath?> {
  @override
  VaultPath? build() => null;

  void select(VaultPath? path) {
    state = path;
  }
}

final explorerSelectedProvider =
    NotifierProvider<ExplorerSelectedNotifier, VaultPath?>(
      ExplorerSelectedNotifier.new,
    );

/// Manages inline rename mode for a specific path in the file explorer.
final class ExplorerRenamingNotifier extends Notifier<VaultPath?> {
  @override
  VaultPath? build() => null;

  void start(VaultPath path) {
    state = path;
  }

  void stop() {
    state = null;
  }
}

final explorerRenamingProvider =
    NotifierProvider<ExplorerRenamingNotifier, VaultPath?>(
      ExplorerRenamingNotifier.new,
    );

/// Provides visible, sorted children for a folder in the vault.
final explorerChildrenProvider = FutureProvider.autoDispose
    .family<List<VaultEntry>, VaultPath>((ref, folder) async {
      ref.watch(vaultRevisionProvider);
      final sortAndHidden = ref.watch(
        vaultSettingsProvider.select((s) => (s.explorerSortEnum, s.showHidden)),
      );
      final sort = sortAndHidden.$1;

      final fs = ref.watch(vaultFsProvider);
      final entries = await fs.list(folder: folder, recursive: false);
      final visible = entries.where(isVisibleInExplorer).toList();
      return sortEntries(visible, sort);
    });

/// Provides the flattened tree of explorer rows.
final explorerRowsProvider = FutureProvider.autoDispose<List<ExplorerRow>>((
  ref,
) async {
  final rootAsync = ref.watch(explorerChildrenProvider(VaultPath.root));
  final rootEntries = rootAsync.value ?? const [];

  final expanded = ref.watch(explorerExpandedProvider);
  final childrenOf = <VaultPath, List<VaultEntry>>{};

  for (final folder in expanded) {
    final childAsync = ref.watch(explorerChildrenProvider(folder));
    if (childAsync.hasValue) {
      childrenOf[folder] = childAsync.requireValue;
    }
    // If childAsync is loading or has error, folder is omitted from childrenOf,
    // so flattenTree generates a loading placeholder or handles it gracefully.
  }

  return flattenTree(rootEntries, expanded, childrenOf);
});
