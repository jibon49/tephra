// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';

import '../../commands/command_registry.dart';
import '../../commands/tephra_command.dart';
import '../../workspace/providers.dart';
import '../providers.dart';
import 'fold_regions.dart';
import 'providers.dart';

/// Registers fold commands into [registry].
void registerFoldCommands(CommandRegistry registry) {
  registry.register(
    TephraCommand(
      id: 'editor.toggle-fold-at-cursor',
      label: (l10n) => l10n.commandToggleFold,
      icon: Icons.unfold_more,
      defaultShortcuts: const [],
      isAvailable: (ref) => ref.read(activeEditorProvider) != null,
      run: (ref, context) {
        final focusedTab = ref.read(workspaceProvider).focusedTab;
        final editor = ref.read(activeEditorProvider);
        if (focusedTab == null || editor == null) return;

        final foldController = ref.read(foldControllerProvider(focusedTab.id));
        final regions = foldController.regions;
        if (regions.isEmpty) return;

        final caretOffset = editor.selection.extentOffset;
        final lines = foldController.lines;
        final caretLine = lines.lineOf(caretOffset);

        // 1. Find innermost region whose header line contains the caret.
        FoldRegion? targetRegion;
        for (final r in regions) {
          final hLine = lines.lineOf(r.headerStart);
          if (hLine == caretLine) {
            if (targetRegion == null || r.level >= targetRegion.level) {
              targetRegion = r;
            }
          }
        }

        // 2. If none, find the nearest enclosing region.
        if (targetRegion == null) {
          for (final r in regions) {
            if (caretOffset > r.from && caretOffset <= r.to) {
              if (targetRegion == null ||
                  (r.to - r.from) < (targetRegion.to - targetRegion.from)) {
                targetRegion = r;
              }
            }
          }
        }

        if (targetRegion != null) {
          foldController.toggle(targetRegion.headerStart);
        }
      },
    ),
  );

  registry.register(
    TephraCommand(
      id: 'editor.fold-all',
      label: (l10n) => l10n.commandFoldAll,
      icon: Icons.unfold_less,
      defaultShortcuts: const [],
      isAvailable: (ref) => ref.read(activeEditorProvider) != null,
      run: (ref, context) {
        final focusedTab = ref.read(workspaceProvider).focusedTab;
        if (focusedTab != null) {
          ref.read(foldControllerProvider(focusedTab.id)).foldAll();
        }
      },
    ),
  );

  registry.register(
    TephraCommand(
      id: 'editor.unfold-all',
      label: (l10n) => l10n.commandUnfoldAll,
      icon: Icons.unfold_more,
      defaultShortcuts: const [],
      isAvailable: (ref) => ref.read(activeEditorProvider) != null,
      run: (ref, context) {
        final focusedTab = ref.read(workspaceProvider).focusedTab;
        if (focusedTab != null) {
          ref.read(foldControllerProvider(focusedTab.id)).unfoldAll();
        }
      },
    ),
  );
}
