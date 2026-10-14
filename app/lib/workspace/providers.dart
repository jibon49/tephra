// © 2026 Tephra. All rights reserved.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';

import 'tab_content.dart';
import 'workspace_models.dart';
import 'workspace_notifier.dart';

export 'sidebar_registry.dart' show sidebarRegistryProvider;
export 'status_bar_registry.dart' show statusBarRegistryProvider;
export 'tab_status.dart' show tabDirtyProvider;
export 'view_registry.dart' show viewRegistryProvider;

final class RecentFilesNotifier extends Notifier<List<VaultPath>> {
  @override
  List<VaultPath> build() => const [];

  void add(VaultPath path) {
    final list = state.where((p) => p != path).toList();
    list.insert(0, path);
    if (list.length > 30) {
      list.removeRange(30, list.length);
    }
    state = list;
  }

  void set(List<VaultPath> paths) {
    state = paths.take(30).toList();
  }
}

final workspaceProvider = NotifierProvider<WorkspaceNotifier, WorkspaceState>(
  WorkspaceNotifier.new,
);

final activeNotePathProvider = Provider<VaultPath?>((ref) {
  final tab = ref.watch(workspaceProvider.select((w) => w.focusedTab));
  final content = tab?.content;
  return content is FileTabContent ? content.path : null;
});

final recentFilesProvider =
    NotifierProvider<RecentFilesNotifier, List<VaultPath>>(
      RecentFilesNotifier.new,
    );
