// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../explorer/explorer_pane.dart';
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
}
