// © 2026 Tephra. All rights reserved.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';

import '../core/providers.dart';
import '../vault/providers.dart';

final class SwitcherItem {
  SwitcherItem({
    required this.path,
    String? primary,
    String? secondary,
    String? primaryLower,
    String? pathLower,
    String? stem,
    String? folder,
    String? stemLower,
    this.isAlias = false,
    this.isAttachment = false,
    this.isHeading = false,
    this.heading,
  }) : primary = primary ?? stem ?? '',
       secondary = secondary ?? folder ?? '',
       primaryLower =
           primaryLower ?? stemLower ?? (primary ?? stem ?? '').toLowerCase(),
       pathLower = pathLower ?? path.value.toLowerCase();

  final VaultPath path;
  final String primary;
  final String secondary;
  final String primaryLower;
  final String pathLower;
  final bool isAlias;
  final bool isAttachment;
  final bool isHeading;
  final String? heading;

  String get stem => primary;
  String get folder => secondary;
  String get stemLower => primaryLower;
}

final switcherItemsProvider = FutureProvider<List<SwitcherItem>>((ref) async {
  ref.watch(indexChangesProvider);
  final showAttachments = ref.watch(
    appSettingsProvider.select((s) => s.switcherShowAttachments),
  );
  final session = ref.watch(vaultSessionProvider);
  if (session == null) return const [];

  try {
    final index = await ref.watch(noteIndexProvider.future);
    final files = await index.allFiles();
    final aliases = await index.allAliases();

    final items = <SwitcherItem>[];
    for (final f in files) {
      if (f.isNote) {
        final p = f.path;
        final folder = p.parent?.value ?? '';
        items.add(
          SwitcherItem(
            path: p,
            primary: p.stem,
            secondary: folder,
            primaryLower: p.stem.toLowerCase(),
            pathLower: p.value.toLowerCase(),
          ),
        );
      } else if (showAttachments) {
        final p = f.path;
        final folder = p.parent?.value ?? '';
        items.add(
          SwitcherItem(
            path: p,
            primary: p.name,
            secondary: folder,
            primaryLower: p.name.toLowerCase(),
            pathLower: p.value.toLowerCase(),
            isAttachment: true,
          ),
        );
      }
    }

    for (final a in aliases) {
      final p = a.path;
      items.add(
        SwitcherItem(
          path: p,
          primary: a.alias,
          secondary: '→ ${p.stem}',
          primaryLower: a.alias.toLowerCase(),
          pathLower: p.value.toLowerCase(),
          isAlias: true,
        ),
      );
    }
    return items;
  } catch (_) {
    final fs = session.fs;
    final entries = await fs.list(folder: VaultPath.root, recursive: true);
    final items = <SwitcherItem>[];
    for (final entry in entries) {
      if (!entry.isFolder) {
        if (entry.path.isMarkdown) {
          final p = entry.path;
          final folder = p.parent?.value ?? '';
          items.add(
            SwitcherItem(
              path: p,
              primary: p.stem,
              secondary: folder,
              primaryLower: p.stem.toLowerCase(),
              pathLower: p.value.toLowerCase(),
            ),
          );
        } else if (showAttachments) {
          final p = entry.path;
          final folder = p.parent?.value ?? '';
          items.add(
            SwitcherItem(
              path: p,
              primary: p.name,
              secondary: folder,
              primaryLower: p.name.toLowerCase(),
              pathLower: p.value.toLowerCase(),
              isAttachment: true,
            ),
          );
        }
      }
    }
    return items;
  }
});

final quickSwitcherItemsProvider = switcherItemsProvider;

final switcherHeadingsProvider = FutureProvider<List<SwitcherItem>>((
  ref,
) async {
  ref.watch(indexChangesProvider);
  final session = ref.watch(vaultSessionProvider);
  if (session == null) return const [];

  try {
    final index = await ref.watch(noteIndexProvider.future);
    final headings = await index.allHeadings();
    return headings.map((h) {
      final p = h.path;
      final text = h.text;
      return SwitcherItem(
        path: p,
        primary: text,
        secondary: p.stem,
        primaryLower: text.toLowerCase(),
        pathLower: p.value.toLowerCase(),
        isHeading: true,
        heading: text,
      );
    }).toList();
  } catch (_) {
    return const [];
  }
});
