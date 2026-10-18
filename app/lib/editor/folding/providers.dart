// © 2026 Tephra. All rights reserved.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';

import '../../settings/providers.dart';
import '../../vault/providers.dart';
import '../../workspace/providers.dart';
import '../../workspace/tab_content.dart';
import 'fold_controller.dart';
import 'fold_store.dart';

/// Provider for [FoldStore] accessing `.tephra/workspace.json`.
final foldStoreProvider = Provider<FoldStore>((ref) {
  final fs = ref.watch(vaultFsProvider);
  final deviceId = ref.watch(appSettingsProvider).deviceId;
  return FoldStore(fs: fs, deviceId: deviceId);
});

/// Provider for [FoldController] per editor tab.
final foldControllerProvider = Provider.family<FoldController, String>((
  ref,
  tabId,
) {
  final store = ref.watch(foldStoreProvider);
  final ws = ref.read(workspaceProvider);
  final tab = ws.findTab(tabId);
  final fileContent = tab?.content as FileTabContent?;
  final path = fileContent?.path ?? VaultPath('untitled.md');
  final settings = ref.read(vaultSettingsProvider);

  final controller = FoldController(
    tabId: tabId,
    path: path,
    foldStore: store,
    foldHeadings: settings.foldHeadings,
    foldIndent: settings.foldIndent,
  );

  ref.onDispose(() {
    controller.dispose();
  });

  return controller;
});
