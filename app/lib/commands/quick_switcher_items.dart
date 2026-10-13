// © 2026 Tephra. All rights reserved.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';

import '../vault/providers.dart';

final class SwitcherItem {
  const SwitcherItem({
    required this.path,
    required this.stem,
    required this.folder,
    required this.stemLower,
    required this.pathLower,
  });

  final VaultPath path;
  final String stem;
  final String folder;
  final String stemLower;
  final String pathLower;
}

final quickSwitcherItemsProvider = FutureProvider<List<SwitcherItem>>((
  ref,
) async {
  ref.watch(vaultRevisionProvider);
  final session = ref.watch(vaultSessionProvider);
  if (session == null) return const [];

  final fs = session.fs;
  final entries = await fs.list(folder: VaultPath.root, recursive: true);
  final items = <SwitcherItem>[];

  for (final entry in entries) {
    if (!entry.isFolder && entry.path.isMarkdown) {
      final p = entry.path;
      final folder = p.parent?.value ?? '';
      items.add(
        SwitcherItem(
          path: p,
          stem: p.stem,
          folder: folder,
          stemLower: p.stem.toLowerCase(),
          pathLower: p.value.toLowerCase(),
        ),
      );
    }
  }

  return items;
});
