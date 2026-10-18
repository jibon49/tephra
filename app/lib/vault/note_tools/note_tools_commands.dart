import 'package:flutter/material.dart';

import '../../commands/command_registry.dart';
import '../../commands/tephra_command.dart';
import '../../core/providers.dart';
import '../../editor/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../settings/settings_screen.dart';
import '../../workspace/providers.dart';
import '../../workspace/tab_content.dart';
import 'exceptions.dart';
import 'providers.dart';
import 'template_service.dart';

void registerNoteToolsCommands(CommandRegistry registry) {
  // 1. Open today's daily note
  registry.register(
    TephraCommand(
      id: 'daily-notes.open-today',
      label: (l10n) => l10n.commandOpenToday,
      icon: Icons.calendar_today_outlined,
      defaultShortcuts: const [],
      showInMobileToolbar: false,
      isAvailable: (ref) =>
          ref.watch(vaultSettingsProvider).corePluginsSettings.dailyNotes,
      run: (ref, context) async {
        final l10n = AppLocalizations.of(context);
        final clock = ref.read(clockProvider);
        try {
          await ref.read(dailyNotesServiceProvider).openOrCreate(clock.now());
        } on DailyNotesConfigException {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.dailyFormatInvalid),
                action: SnackBarAction(
                  label: l10n.openSettings,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SettingsScreen(),
                      ),
                    );
                  },
                ),
              ),
            );
          }
        }
      },
    ),
  );

  // 2. Open previous daily note
  registry.register(
    TephraCommand(
      id: 'daily-notes.open-previous',
      label: (l10n) => l10n.commandOpenPreviousDaily,
      icon: Icons.chevron_left,
      defaultShortcuts: const [],
      showInMobileToolbar: false,
      isAvailable: (ref) =>
          ref.watch(vaultSettingsProvider).corePluginsSettings.dailyNotes,
      run: (ref, context) async {
        final l10n = AppLocalizations.of(context);
        final content = ref.read(workspaceProvider).focusedTab?.content;
        final currentPath = content is FileTabContent ? content.path : null;
        final target = await ref
            .read(dailyNotesServiceProvider)
            .neighbour(currentPath, previous: true);
        if (target == null) {
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(l10n.dailyNoNeighbour)));
          }
        } else {
          ref.read(workspaceProvider.notifier).openPath(target);
        }
      },
    ),
  );

  // 3. Open next daily note
  registry.register(
    TephraCommand(
      id: 'daily-notes.open-next',
      label: (l10n) => l10n.commandOpenNextDaily,
      icon: Icons.chevron_right,
      defaultShortcuts: const [],
      showInMobileToolbar: false,
      isAvailable: (ref) =>
          ref.watch(vaultSettingsProvider).corePluginsSettings.dailyNotes,
      run: (ref, context) async {
        final l10n = AppLocalizations.of(context);
        final content = ref.read(workspaceProvider).focusedTab?.content;
        final currentPath = content is FileTabContent ? content.path : null;
        final target = await ref
            .read(dailyNotesServiceProvider)
            .neighbour(currentPath, previous: false);
        if (target == null) {
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(l10n.dailyNoNeighbour)));
          }
        } else {
          ref.read(workspaceProvider.notifier).openPath(target);
        }
      },
    ),
  );

  // 4. Insert template
  registry.register(
    TephraCommand(
      id: 'templates.insert-template',
      label: (l10n) => l10n.commandInsertTemplate,
      icon: Icons.content_paste_outlined,
      defaultShortcuts: const [],
      showInMobileToolbar: false,
      isAvailable: (ref) =>
          ref.watch(vaultSettingsProvider).corePluginsSettings.templates,
      run: (ref, context) async {
        final editor = ref.read(activeEditorProvider);
        if (editor != null) {
          await executeInsertTemplate(
            context,
            templateService: ref.read(templateServiceProvider),
            editor: editor,
          );
        }
      },
    ),
  );

  // 5. Create unique note
  registry.register(
    TephraCommand(
      id: 'unique-note.create',
      label: (l10n) => l10n.commandCreateUniqueNote,
      icon: Icons.note_add_outlined,
      defaultShortcuts: const [],
      showInMobileToolbar: false,
      isAvailable: (ref) => ref
          .watch(vaultSettingsProvider)
          .corePluginsSettings
          .uniqueNoteCreator,
      run: (ref, context) async {
        final content = ref.read(workspaceProvider).focusedTab?.content;
        final activePath = content is FileTabContent ? content.path : null;
        try {
          await ref
              .read(uniqueNoteServiceProvider)
              .create(contextNote: activePath);
        } catch (_) {}
      },
    ),
  );
}
