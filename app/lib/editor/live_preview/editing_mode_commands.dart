// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../commands/command_registry.dart';
import '../../commands/tephra_command.dart';
import '../../workspace/providers.dart';
import '../../workspace/tab_content.dart';

/// Registers editing-mode-related commands (Live Preview vs Source mode toggle).
void registerEditingModeCommands(CommandRegistry registry) {
  registry.register(
    TephraCommand(
      id: 'editor.toggle-editing-mode',
      label: (l10n) => l10n.commandToggleEditingMode,
      icon: Icons.edit_note_outlined,
      defaultShortcuts: const [
        SingleActivator(LogicalKeyboardKey.keyE, control: true, shift: true),
      ],
      showInMobileToolbar: false,
      isAvailable: (ref) {
        final tab = ref.read(workspaceProvider).focusedTab;
        return tab != null && tab.content is FileTabContent;
      },
      run: (ref, context) {
        ref.read(workspaceProvider.notifier).toggleEditingMode();
      },
    ),
  );
}
