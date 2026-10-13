// © 2026 Tephra. All rights reserved.

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import 'hotkeys_screen.dart';
import 'providers.dart';

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
