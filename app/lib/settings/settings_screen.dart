// © 2026 Tephra. All rights reserved.

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../l10n/app_localizations.dart';
import 'hotkeys_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const String routeName = '/settings';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final appSettings = ref.watch(appSettingsProvider);
    final vaultSettings = ref.watch(vaultSettingsProvider);

    final isAndroid = !kIsWeb && Platform.isAndroid;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // --- Appearance ---
          _SectionHeader(title: l10n.settingsAppearance),
          ListTile(
            title: Text(l10n.settingsTheme),
            trailing: DropdownButton<String>(
              value: appSettings.themeMode,
              onChanged: (val) {
                if (val != null) {
                  ref
                      .read(appSettingsProvider.notifier)
                      .update((s) => s.copyWith(themeMode: val));
                }
              },
              items: const [
                DropdownMenuItem(value: 'system', child: Text('System')),
                DropdownMenuItem(value: 'light', child: Text('Light')),
                DropdownMenuItem(value: 'dark', child: Text('Dark')),
              ],
            ),
          ),
          ListTile(
            title: Text(l10n.settingsFontSize),
            subtitle: Slider(
              min: 12,
              max: 32,
              divisions: 20,
              value: vaultSettings.fontSize.clamp(12.0, 32.0),
              label: '${vaultSettings.fontSize.round()} pt',
              onChanged: (val) {
                ref
                    .read(vaultSettingsProvider.notifier)
                    .update((s) => s.copyWith(fontSize: val));
              },
            ),
            trailing: Text('${vaultSettings.fontSize.round()} pt'),
          ),
          const Divider(),

          // --- Editor ---
          _SectionHeader(title: l10n.settingsEditor),
          SwitchListTile(
            title: Text(l10n.settingsUseTab),
            value: vaultSettings.useTab,
            onChanged: (val) {
              ref
                  .read(vaultSettingsProvider.notifier)
                  .update((s) => s.copyWith(useTab: val));
            },
          ),
          ListTile(
            title: Text(l10n.settingsTabSize),
            trailing: DropdownButton<int>(
              value: [2, 4, 8].contains(vaultSettings.tabSize)
                  ? vaultSettings.tabSize
                  : 4,
              onChanged: (val) {
                if (val != null) {
                  ref
                      .read(vaultSettingsProvider.notifier)
                      .update((s) => s.copyWith(tabSize: val));
                }
              },
              items: const [
                DropdownMenuItem(value: 2, child: Text('2 spaces')),
                DropdownMenuItem(value: 4, child: Text('4 spaces')),
                DropdownMenuItem(value: 8, child: Text('8 spaces')),
              ],
            ),
          ),
          SwitchListTile(
            title: Text(l10n.settingsReadableLineLength),
            value: vaultSettings.readableLineLength,
            onChanged: (val) {
              ref
                  .read(vaultSettingsProvider.notifier)
                  .update((s) => s.copyWith(readableLineLength: val));
            },
          ),
          ListTile(
            title: Text(l10n.settingsDefaultViewMode),
            trailing: DropdownButton<String>(
              value: vaultSettings.defaultViewMode,
              onChanged: (val) {
                if (val != null) {
                  ref
                      .read(vaultSettingsProvider.notifier)
                      .update((s) => s.copyWith(defaultViewMode: val));
                }
              },
              items: [
                DropdownMenuItem(
                  value: 'reading',
                  child: Text(l10n.modeReading),
                ),
                DropdownMenuItem(value: 'source', child: Text(l10n.modeSource)),
              ],
            ),
          ),
          ListTile(
            title: Text(l10n.settingEditorDefaultEditingMode),
            trailing: DropdownButton<String>(
              value: vaultSettings.editorSettings.defaultEditingMode,
              onChanged: (val) {
                if (val != null) {
                  ref
                      .read(vaultSettingsProvider.notifier)
                      .update(
                        (s) => s.copyWith(
                          editor: {...s.editor, 'defaultEditingMode': val},
                        ),
                      );
                }
              },
              items: [
                DropdownMenuItem(
                  value: 'livePreview',
                  child: Text(l10n.editingModeLivePreview),
                ),
                DropdownMenuItem(
                  value: 'source',
                  child: Text(l10n.editingModeSource),
                ),
              ],
            ),
          ),
          const Divider(),

          // --- Files ---
          _SectionHeader(title: l10n.settingsFiles),
          ListTile(
            title: Text(l10n.settingsAttachmentFolder),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.settingsAttachmentFolderHelp,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: Theme.of(context).hintColor),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: vaultSettings.attachmentFolder,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onFieldSubmitted: (val) {
                    ref
                        .read(vaultSettingsProvider.notifier)
                        .update(
                          (s) => s.copyWith(attachmentFolder: val.trim()),
                        );
                  },
                ),
              ],
            ),
          ),
          ListTile(
            title: Text(l10n.settingsNewNoteLocation),
            trailing: DropdownButton<String>(
              value: vaultSettings.newFileLocation,
              onChanged: (val) {
                if (val != null) {
                  ref
                      .read(vaultSettingsProvider.notifier)
                      .update((s) => s.copyWith(newFileLocation: val));
                }
              },
              items: const [
                DropdownMenuItem(value: 'root', child: Text('Vault root')),
                DropdownMenuItem(
                  value: 'current',
                  child: Text('Same folder as current note'),
                ),
                DropdownMenuItem(
                  value: 'folder',
                  child: Text('Specified folder below'),
                ),
              ],
            ),
          ),
          if (vaultSettings.newFileLocation == 'folder')
            ListTile(
              title: Text(l10n.settingsNewNoteFolder),
              subtitle: TextFormField(
                initialValue: vaultSettings.newFileFolder,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onFieldSubmitted: (val) {
                  ref
                      .read(vaultSettingsProvider.notifier)
                      .update((s) => s.copyWith(newFileFolder: val.trim()));
                },
              ),
            ),
          ListTile(
            title: Text(l10n.settingsTrashMode),
            trailing: DropdownButton<String>(
              value: vaultSettings.trashMode,
              onChanged: (val) {
                if (val != null) {
                  ref
                      .read(vaultSettingsProvider.notifier)
                      .update((s) => s.copyWith(trashMode: val));
                }
              },
              items: [
                if (!isAndroid)
                  const DropdownMenuItem(
                    value: 'system',
                    child: Text('System Recycle Bin'),
                  ),
                const DropdownMenuItem(
                  value: 'vaultTrash',
                  child: Text('Move to .trash/ folder'),
                ),
                const DropdownMenuItem(
                  value: 'permanent',
                  child: Text('Delete permanently'),
                ),
              ],
            ),
          ),
          SwitchListTile(
            title: Text(l10n.settingsShowHidden),
            value: vaultSettings.showHidden,
            onChanged: (val) {
              ref
                  .read(vaultSettingsProvider.notifier)
                  .update((s) => s.copyWith(showHidden: val));
            },
          ),
          const Divider(),

          // --- Files & links ---
          _SectionHeader(title: l10n.settingsFilesAndLinks),
          ListTile(
            title: Text(l10n.settingsNewLinkFormat),
            trailing: DropdownButton<String>(
              value: vaultSettings.newLinkFormat,
              onChanged: (val) {
                if (val != null) {
                  ref
                      .read(vaultSettingsProvider.notifier)
                      .update((s) => s.copyWith(newLinkFormat: val));
                }
              },
              items: [
                DropdownMenuItem(
                  value: 'shortest',
                  child: Text(l10n.settingsNewLinkFormatShortest),
                ),
                DropdownMenuItem(
                  value: 'relative',
                  child: Text(l10n.settingsNewLinkFormatRelative),
                ),
                DropdownMenuItem(
                  value: 'absolute',
                  child: Text(l10n.settingsNewLinkFormatAbsolute),
                ),
              ],
            ),
          ),
          SwitchListTile(
            title: Text(l10n.settingsUseWikilinks),
            value: !vaultSettings.useMarkdownLinks,
            onChanged: (val) {
              ref
                  .read(vaultSettingsProvider.notifier)
                  .update((s) => s.copyWith(useMarkdownLinks: !val));
            },
          ),
          SwitchListTile(
            title: Text(l10n.settingsAlwaysUpdateLinks),
            value: vaultSettings.alwaysUpdateLinks,
            onChanged: (val) {
              ref
                  .read(vaultSettingsProvider.notifier)
                  .update((s) => s.copyWith(alwaysUpdateLinks: val));
            },
          ),
          ListTile(
            title: Text(l10n.settingsExcludedFolders),
            subtitle: vaultSettings.excludedFolders.isEmpty
                ? Text(l10n.settingsExcludedFoldersEmpty)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final folder in vaultSettings.excludedFolders)
                        Row(
                          children: [
                            Expanded(child: Text(folder)),
                            IconButton(
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                size: 20,
                              ),
                              onPressed: () =>
                                  _removeExcludedFolder(context, ref, folder),
                            ),
                          ],
                        ),
                    ],
                  ),
            trailing: IconButton(
              icon: const Icon(Icons.add),
              tooltip: l10n.settingsExcludedFoldersAdd,
              onPressed: () => _addExcludedFolder(context, ref),
            ),
          ),
          const Divider(),

          // --- Hotkeys ---
          _SectionHeader(title: l10n.settingsHotkeys),
          ListTile(
            title: Text(l10n.hotkeysTitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const HotkeysScreen()),
              );
            },
          ),
          const Divider(),

          // --- About ---
          _SectionHeader(title: l10n.settingsAbout),
          const ListTile(
            title: Text('Tephra'),
            subtitle: Text(
              'Version ${String.fromEnvironment('TEPHRA_VERSION', defaultValue: '0.1.0')}',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateExcludedFolders(
    BuildContext context,
    WidgetRef ref,
    List<String> updated,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.rebuildIndexConfirmTitle),
        content: Text(l10n.excludedFoldersRebuildPrompt),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.commonOk),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      ref
          .read(vaultSettingsProvider.notifier)
          .update((s) => s.copyWith(excludedFolders: updated));
      ref.invalidate(noteIndexProvider);
      final index = await ref.read(noteIndexProvider.future);
      await index.rebuild();
    }
  }

  Future<void> _addExcludedFolder(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    final folder = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settingsExcludedFoldersAdd),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'folder/name'),
          onSubmitted: (val) => Navigator.of(ctx).pop(val.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(l10n.commonOk),
          ),
        ],
      ),
    );

    if (folder != null && folder.isNotEmpty && context.mounted) {
      final current = ref.read(vaultSettingsProvider).excludedFolders;
      if (!current.contains(folder)) {
        await _updateExcludedFolders(context, ref, [...current, folder]);
      }
    }
  }

  Future<void> _removeExcludedFolder(
    BuildContext context,
    WidgetRef ref,
    String folder,
  ) async {
    final current = ref.read(vaultSettingsProvider).excludedFolders;
    final updated = current.where((f) => f != folder).toList();
    await _updateExcludedFolders(context, ref, updated);
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
