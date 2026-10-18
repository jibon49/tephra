// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bookmarks/bookmarks_pane.dart';
import '../explorer/explorer_pane.dart';
import '../links/backlinks_pane.dart';
import '../links/outgoing_links_pane.dart';
import '../outline/outline_pane.dart';
import '../search/search_pane.dart';
import '../tags/tags_pane.dart';
import 'sidebar_registry.dart';

/// Registers default sidebar panels for the workspace.
void registerBuiltinPanels(WidgetRef ref) {
  final registry = ref.read(sidebarRegistryProvider.notifier);
  registry.register(
    SidebarPanelSpec(
      id: 'explorer',
      side: SidebarSide.left,
      label: (l) => l.sidebarExplorer,
      icon: Icons.folder_outlined,
      builder: (context, ref) => const ExplorerPane(),
      order: 0,
    ),
  );
  registry.register(
    SidebarPanelSpec(
      id: 'search',
      side: SidebarSide.left,
      label: (l) => l.searchTabTitle,
      icon: Icons.search,
      builder: (context, ref) => const SearchPane(),
      order: 1,
    ),
  );
  registry.register(
    SidebarPanelSpec(
      id: 'bookmarks',
      side: SidebarSide.left,
      label: (l) => l.sidebarBookmarks,
      icon: Icons.bookmark_outline,
      builder: (context, ref) => const BookmarksPane(),
      order: 2,
    ),
  );
  registry.register(
    SidebarPanelSpec(
      id: 'backlinks',
      side: SidebarSide.right,
      label: (l) => l.sidebarBacklinks,
      icon: Icons.link,
      builder: (context, ref) => const BacklinksPane(),
      order: 0,
    ),
  );
  registry.register(
    SidebarPanelSpec(
      id: 'outgoing-links',
      side: SidebarSide.right,
      label: (l) => l.sidebarOutgoingLinks,
      icon: Icons.arrow_outward,
      builder: (context, ref) => const OutgoingLinksPane(),
      order: 1,
    ),
  );
  registry.register(
    SidebarPanelSpec(
      id: 'outline',
      side: SidebarSide.right,
      label: (l) => l.sidebarOutline,
      icon: Icons.list_alt,
      builder: (context, ref) => const OutlinePane(),
      order: 2,
    ),
  );
  registry.register(
    SidebarPanelSpec(
      id: 'tags',
      side: SidebarSide.right,
      phoneSide: SidebarSide.left,
      label: (l) => l.sidebarTags,
      icon: Icons.tag,
      builder: (context, ref) => const TagsPane(),
      order: 3,
      phoneOrder: 3,
    ),
  );
}
