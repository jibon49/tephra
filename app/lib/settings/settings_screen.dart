// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';

import '../commands/shortcut_codec.dart';
import '../core/providers.dart';
import '../l10n/app_localizations.dart';
import '../stickies/providers.dart';
import '../stickies/windows/accelerator.dart';
import '../sync_ui/providers.dart';
import '../sync_ui/settings/sync_settings_screen.dart';
import '../sync_ui/setup/sync_setup_wizard.dart';
import '../vault/note_tools/template_picker.dart';
import '../vault/providers.dart';
import 'hotkeys_screen.dart';
import 'shortcut_recorder_dialog.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const String routeName = '/settings';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final appSettings = ref.watch(appSettingsProvider);
    final vaultSettings = ref.watch(vaultSettingsProvider);
    final clock = ref.watch(clockProvider);

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
          SwitchListTile(
            title: Text(l10n.settingEditorFoldHeadings),
            value: vaultSettings.editorSettings.foldHeadings,
            onChanged: (val) {
              ref
                  .read(vaultSettingsProvider.notifier)
                  .update(
                    (s) =>
                        s.copyWith(editor: {...s.editor, 'foldHeadings': val}),
                  );
            },
          ),
          SwitchListTile(
            title: Text(l10n.settingEditorFoldIndent),
            value: vaultSettings.editorSettings.foldIndent,
            onChanged: (val) {
              ref
                  .read(vaultSettingsProvider.notifier)
                  .update(
                    (s) => s.copyWith(editor: {...s.editor, 'foldIndent': val}),
                  );
            },
          ),
          ListTile(
            title: Text(l10n.settingEditorPropertiesInDocument),
            trailing: DropdownButton<String>(
              value: vaultSettings.propertiesInDocument,
              onChanged: (val) {
                if (val != null) {
                  ref
                      .read(vaultSettingsProvider.notifier)
                      .update(
                        (s) => s.copyWith(
                          editor: {...s.editor, 'propertiesInDocument': val},
                        ),
                      );
                }
              },
              items: [
                DropdownMenuItem(
                  value: 'visible',
                  child: Text(l10n.propertiesInDocumentVisible),
                ),
                DropdownMenuItem(
                  value: 'hidden',
                  child: Text(l10n.propertiesInDocumentHidden),
                ),
                DropdownMenuItem(
                  value: 'source',
                  child: Text(l10n.propertiesInDocumentSource),
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

          // --- Daily notes ---
          _SectionHeader(title: l10n.settingsDailyNotes),
          SwitchListTile(
            title: Text(l10n.settingsDailyNotes),
            value: vaultSettings.corePluginsSettings.dailyNotes,
            onChanged: (val) {
              ref.read(vaultSettingsProvider.notifier).update((s) {
                final plugins = Map<String, Object?>.from(s.corePlugins);
                plugins['dailyNotes'] = val;
                return s.copyWith(corePlugins: plugins);
              });
            },
          ),
          if (vaultSettings.corePluginsSettings.dailyNotes) ...[
            _FormatSettingTile(
              title: l10n.settingDailyFormat,
              initialValue: vaultSettings.dailyNotesSettings.format,
              validator: (f) =>
                  validateMomentFormat(f, forFileName: true, requireDate: true),
              onSaved: (f) {
                ref.read(vaultSettingsProvider.notifier).update((s) {
                  final m = Map<String, Object?>.from(s.dailyNotes);
                  m['format'] = f;
                  return s.copyWith(dailyNotes: m);
                });
              },
              clock: clock,
            ),
            _PathPickerTile(
              title: l10n.settingDailyFolder,
              initialValue: vaultSettings.dailyNotesSettings.folder,
              icon: Icons.folder_open,
              onPick: () => _pickFolderDialog(context, ref),
              onSaved: (f) {
                ref.read(vaultSettingsProvider.notifier).update((s) {
                  final m = Map<String, Object?>.from(s.dailyNotes);
                  m['folder'] = f;
                  return s.copyWith(dailyNotes: m);
                });
              },
            ),
            _PathPickerTile(
              title: l10n.settingDailyTemplate,
              initialValue: vaultSettings.dailyNotesSettings.template,
              icon: Icons.description_outlined,
              onPick: () => _pickTemplateDialog(context, ref),
              onSaved: (t) {
                ref.read(vaultSettingsProvider.notifier).update((s) {
                  final m = Map<String, Object?>.from(s.dailyNotes);
                  m['template'] = t;
                  return s.copyWith(dailyNotes: m);
                });
              },
            ),
            SwitchListTile(
              title: Text(l10n.settingDailyOpenOnStartup),
              value: vaultSettings.dailyNotesSettings.openOnStartup,
              onChanged: (val) {
                ref.read(vaultSettingsProvider.notifier).update((s) {
                  final m = Map<String, Object?>.from(s.dailyNotes);
                  m['openOnStartup'] = val;
                  return s.copyWith(dailyNotes: m);
                });
              },
            ),
          ],
          const Divider(),

          // --- Templates ---
          _SectionHeader(title: l10n.settingsTemplates),
          SwitchListTile(
            title: Text(l10n.settingsTemplates),
            value: vaultSettings.corePluginsSettings.templates,
            onChanged: (val) {
              ref.read(vaultSettingsProvider.notifier).update((s) {
                final plugins = Map<String, Object?>.from(s.corePlugins);
                plugins['templates'] = val;
                return s.copyWith(corePlugins: plugins);
              });
            },
          ),
          if (vaultSettings.corePluginsSettings.templates) ...[
            _PathPickerTile(
              title: l10n.settingTemplatesFolder,
              initialValue: vaultSettings.templatesSettings.folder,
              icon: Icons.folder_open,
              onPick: () => _pickFolderDialog(context, ref),
              onSaved: (f) {
                ref.read(vaultSettingsProvider.notifier).update((s) {
                  final m = Map<String, Object?>.from(s.templates);
                  m['folder'] = f;
                  return s.copyWith(templates: m);
                });
              },
            ),
            _FormatSettingTile(
              title: l10n.settingTemplatesDateFormat,
              initialValue: vaultSettings.templatesSettings.dateFormat,
              validator: (f) => validateMomentFormat(f),
              onSaved: (f) {
                ref.read(vaultSettingsProvider.notifier).update((s) {
                  final m = Map<String, Object?>.from(s.templates);
                  m['dateFormat'] = f;
                  return s.copyWith(templates: m);
                });
              },
              clock: clock,
            ),
            _FormatSettingTile(
              title: l10n.settingTemplatesTimeFormat,
              initialValue: vaultSettings.templatesSettings.timeFormat,
              validator: (f) => validateMomentFormat(f),
              onSaved: (f) {
                ref.read(vaultSettingsProvider.notifier).update((s) {
                  final m = Map<String, Object?>.from(s.templates);
                  m['timeFormat'] = f;
                  return s.copyWith(templates: m);
                });
              },
              clock: clock,
            ),
          ],
          const Divider(),

          // --- Unique note creator ---
          _SectionHeader(title: l10n.settingsUniqueNote),
          SwitchListTile(
            title: Text(l10n.settingsUniqueNote),
            value: vaultSettings.corePluginsSettings.uniqueNoteCreator,
            onChanged: (val) {
              ref.read(vaultSettingsProvider.notifier).update((s) {
                final plugins = Map<String, Object?>.from(s.corePlugins);
                plugins['uniqueNoteCreator'] = val;
                return s.copyWith(corePlugins: plugins);
              });
            },
          ),
          if (vaultSettings.corePluginsSettings.uniqueNoteCreator) ...[
            _FormatSettingTile(
              title: l10n.settingUniquePrefix,
              initialValue: vaultSettings.uniqueNoteSettings.prefixFormat,
              validator: (f) => validateMomentFormat(f, forFileName: true),
              onSaved: (f) {
                ref.read(vaultSettingsProvider.notifier).update((s) {
                  final m = Map<String, Object?>.from(s.uniqueNote);
                  m['prefixFormat'] = f;
                  return s.copyWith(uniqueNote: m);
                });
              },
              clock: clock,
            ),
            _PathPickerTile(
              title: l10n.settingDailyFolder,
              initialValue: vaultSettings.uniqueNoteSettings.folder,
              icon: Icons.folder_open,
              onPick: () => _pickFolderDialog(context, ref),
              onSaved: (f) {
                ref.read(vaultSettingsProvider.notifier).update((s) {
                  final m = Map<String, Object?>.from(s.uniqueNote);
                  m['folder'] = f;
                  return s.copyWith(uniqueNote: m);
                });
              },
            ),
            _PathPickerTile(
              title: l10n.settingDailyTemplate,
              initialValue: vaultSettings.uniqueNoteSettings.template,
              icon: Icons.description_outlined,
              onPick: () => _pickTemplateDialog(context, ref),
              onSaved: (t) {
                ref.read(vaultSettingsProvider.notifier).update((s) {
                  final m = Map<String, Object?>.from(s.uniqueNote);
                  m['template'] = t;
                  return s.copyWith(uniqueNote: m);
                });
              },
            ),
          ],
          const Divider(),

          // --- Sync & backup ---
          const _SyncSettingsSection(),

          // --- Sticky notes (Windows) ---
          const _StickySettingsSection(),

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

class _FormatSettingTile extends StatefulWidget {
  const _FormatSettingTile({
    required this.title,
    required this.initialValue,
    required this.validator,
    required this.onSaved,
    required this.clock,
  });

  final String title;
  final String initialValue;
  final MomentFormatError? Function(String format) validator;
  final ValueChanged<String> onSaved;
  final Clock clock;

  @override
  State<_FormatSettingTile> createState() => _FormatSettingTileState();
}

class _FormatSettingTileState extends State<_FormatSettingTile> {
  late final TextEditingController _controller;
  String? _errorText;
  String _preview = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _updateState(widget.initialValue);
  }

  @override
  void didUpdateWidget(_FormatSettingTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue &&
        widget.initialValue != _controller.text) {
      _controller.text = widget.initialValue;
      _updateState(widget.initialValue);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateState(String format) {
    final err = widget.validator(format);
    setState(() {
      if (err != null) {
        _errorText = 'Invalid format ($err)';
        _preview = '';
      } else {
        _errorText = null;
        _preview = formatMoment(widget.clock.now(), format);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      title: Text(widget.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              isDense: true,
              border: const OutlineInputBorder(),
              errorText: _errorText,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
            onChanged: (val) {
              final trimmed = val.trim();
              _updateState(trimmed);
              if (widget.validator(trimmed) == null) {
                widget.onSaved(trimmed);
              }
            },
          ),
          if (_errorText == null && _preview.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              l10n.settingFormatPreview(_preview),
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: Theme.of(context).hintColor),
            ),
          ],
        ],
      ),
    );
  }
}

class _PathPickerTile extends StatefulWidget {
  const _PathPickerTile({
    required this.title,
    required this.initialValue,
    required this.onSaved,
    required this.onPick,
    required this.icon,
  });

  final String title;
  final String initialValue;
  final ValueChanged<String> onSaved;
  final Future<String?> Function() onPick;
  final IconData icon;

  @override
  State<_PathPickerTile> createState() => _PathPickerTileState();
}

class _PathPickerTileState extends State<_PathPickerTile> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(_PathPickerTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue &&
        widget.initialValue != _controller.text) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(widget.title),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                onSubmitted: (val) => widget.onSaved(val.trim()),
                onChanged: (val) => widget.onSaved(val.trim()),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(widget.icon),
              onPressed: () async {
                final picked = await widget.onPick();
                if (picked != null) {
                  _controller.text = picked;
                  widget.onSaved(picked);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

Future<String?> _pickFolderDialog(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final index = await ref.read(noteIndexProvider.future);
  final all = await index.allFiles();
  final folderSet = <String>{''};
  for (final f in all) {
    var p = f.path.parent;
    while (p != null && p != VaultPath.root) {
      folderSet.add(p.value);
      p = p.parent;
    }
  }
  final folders = folderSet.toList()..sort();

  if (!context.mounted) return null;
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Select folder'),
      content: SizedBox(
        width: 400,
        height: 300,
        child: ListView.builder(
          itemCount: folders.length,
          itemBuilder: (ctx, i) {
            final f = folders[i];
            final label = f.isEmpty ? '/ (Vault root)' : f;
            return ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(label),
              onTap: () => Navigator.of(ctx).pop(f),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(null),
          child: Text(l10n.commonCancel),
        ),
      ],
    ),
  );
}

Future<String?> _pickTemplateDialog(BuildContext context, WidgetRef ref) async {
  final index = await ref.read(noteIndexProvider.future);
  final all = await index.allFiles();
  final mdFiles = all
      .map((f) => f.path)
      .where((p) => p.value.toLowerCase().endsWith('.md'))
      .toList();
  if (!context.mounted) return null;
  final chosen = await showTemplatePicker(context, templates: mdFiles);
  return chosen?.value;
}

class _SyncSettingsSection extends ConsumerWidget {
  const _SyncSettingsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (kIsWeb) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: l10n.syncSettingsTitle),
          ListTile(
            leading: const Icon(Icons.cloud_off_outlined),
            title: Text(l10n.syncNotAvailableOnWeb),
          ),
          const Divider(),
        ],
      );
    }

    final session = ref.watch(vaultSessionProvider);
    if (session == null) {
      return const SizedBox.shrink();
    }

    final syncConfigAsync = ref.watch(
      isSyncConfiguredProvider((
        vaultId: session.vaultId,
        localVaultRootPath: session.rootDir,
      )),
    );

    final isConfigured = syncConfigAsync.value ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: l10n.syncSettingsTitle),
        if (!isConfigured) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.cloud_sync_outlined,
                          color: Colors.blue,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n.syncSettingsTitle,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.syncSetupSignInExplain,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.sync),
                      label: Text(l10n.syncSetupAction),
                      onPressed: () async {
                        await showSyncSetupWizard(
                          context,
                          vaultId: session.vaultId,
                          localVaultRootPath: session.rootDir,
                        );
                        ref.invalidate(
                          isSyncConfiguredProvider((
                            vaultId: session.vaultId,
                            localVaultRootPath: session.rootDir,
                          )),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ] else ...[
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: Text(l10n.syncSettingsConfigureButton),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SyncSettingsScreen(vaultId: session.vaultId),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.cloud_done_outlined, color: Colors.green),
            title: Text(l10n.syncSettingsConfiguredStatus),
            subtitle: Text(session.name),
            trailing: OutlinedButton(
              onPressed: () async {
                final alsoSignOut = ValueNotifier<bool>(false);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(l10n.syncDisconnect),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l10n.syncDisconnectConfirm),
                        const SizedBox(height: 16),
                        ValueListenableBuilder<bool>(
                          valueListenable: alsoSignOut,
                          builder: (context, val, _) {
                            return CheckboxListTile(
                              value: val,
                              title: Text(l10n.syncDisconnectAlsoSignOut),
                              controlAffinity: ListTileControlAffinity.leading,
                              onChanged: (newVal) =>
                                  alsoSignOut.value = newVal ?? false,
                            );
                          },
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: Text(l10n.commonCancel),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: Text(l10n.syncDisconnect),
                      ),
                    ],
                  ),
                );

                if (confirmed == true && context.mounted) {
                  final service = ref.read(
                    syncSetupServiceProvider((
                      vaultId: session.vaultId,
                      localVaultRootPath: session.rootDir,
                    )),
                  );
                  await service.disconnect(signOutGoogle: alsoSignOut.value);
                  ref.invalidate(
                    isSyncConfiguredProvider((
                      vaultId: session.vaultId,
                      localVaultRootPath: session.rootDir,
                    )),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.syncDisconnectSuccess)),
                    );
                  }
                }
              },
              child: Text(l10n.syncDisconnect),
            ),
          ),
        ],
        const Divider(),
      ],
    );
  }
}

class _StickySettingsSection extends ConsumerWidget {
  const _StickySettingsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (kIsWeb || !Platform.isWindows) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final appSettings = ref.watch(appSettingsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: l10n.stickySettingsSection),
        FutureBuilder<bool>(
          future: ref.read(windowServiceProvider).isLaunchAtStartupEnabled(),
          builder: (context, snapshot) {
            final enabled = snapshot.data ?? false;
            return SwitchListTile(
              title: Text(l10n.settingsStartWithWindows),
              subtitle: Text(l10n.settingsStartWithWindowsSubtitle),
              value: enabled,
              onChanged: (val) async {
                await ref.read(windowServiceProvider).setLaunchAtStartup(val);
                (context as Element).markNeedsBuild();
              },
            );
          },
        ),
        SwitchListTile(
          title: Text(l10n.stickySettingsRestoreOnStart),
          subtitle: Text(l10n.stickySettingsRestoreOnStartSubtitle),
          value: appSettings.stickiesRestoreOnStart,
          onChanged: (val) {
            ref
                .read(appSettingsProvider.notifier)
                .update((s) => s.copyWith(stickiesRestoreOnStart: val));
          },
        ),
        ListTile(
          title: Text(l10n.stickySettingsHotkey),
          subtitle: Text(
            '${appSettings.stickyHotkey} — ${l10n.stickySettingsHotkeySubtitle}',
          ),
          trailing: TextButton.icon(
            icon: const Icon(Icons.keyboard_outlined, size: 18),
            label: Text(l10n.stickySettingsHotkeyRecord),
            onPressed: () =>
                _editHotkey(context, ref, appSettings.stickyHotkey, l10n),
          ),
        ),
        ListTile(
          title: Text(l10n.stickySettingsMaxWindows),
          trailing: DropdownButton<int>(
            value: [5, 10, 20, 50].contains(appSettings.stickiesMaxWindows)
                ? appSettings.stickiesMaxWindows
                : 20,
            onChanged: (val) {
              if (val != null) {
                ref
                    .read(appSettingsProvider.notifier)
                    .update((s) => s.copyWith(stickiesMaxWindows: val));
              }
            },
            items: const [
              DropdownMenuItem(value: 5, child: Text('5')),
              DropdownMenuItem(value: 10, child: Text('10')),
              DropdownMenuItem(value: 20, child: Text('20')),
              DropdownMenuItem(value: 50, child: Text('50')),
            ],
          ),
        ),
        ListTile(
          title: Text(l10n.stickySettingsSemanticsTitle),
          subtitle: Text(l10n.stickySettingsSemanticsHelp),
        ),
        const Divider(),
      ],
    );
  }

  Future<void> _editHotkey(
    BuildContext context,
    WidgetRef ref,
    String currentHotkey,
    AppLocalizations l10n,
  ) async {
    final controller = TextEditingController(text: currentHotkey);
    String? errorMessage;

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.stickySettingsHotkeyDialogTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                icon: const Icon(
                  Icons.fiber_manual_record,
                  color: Colors.red,
                  size: 16,
                ),
                label: Text(l10n.stickySettingsHotkeyRecord),
                onPressed: () async {
                  final recorded = await showShortcutRecorderDialog(context);
                  if (recorded != null) {
                    final str = formatShortcut(recorded);
                    controller.text = str;
                    setState(() => errorMessage = null);
                  }
                },
              ),
              const SizedBox(height: 16),
              Text(
                l10n.stickySettingsHotkeyEnterManual,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                autofocus: false,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: 'Ctrl+Alt+N',
                  errorText: errorMessage,
                ),
                onChanged: (_) {
                  if (errorMessage != null) {
                    setState(() => errorMessage = null);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                MaterialLocalizations.of(dialogContext).cancelButtonLabel,
              ),
            ),
            FilledButton(
              onPressed: () {
                try {
                  final parsed = Accelerator.parse(controller.text);
                  Navigator.of(dialogContext).pop(parsed.format());
                } catch (_) {
                  setState(() {
                    errorMessage = l10n.stickySettingsHotkeyInvalid;
                  });
                }
              },
              child: Text(
                MaterialLocalizations.of(dialogContext).saveButtonLabel,
              ),
            ),
          ],
        ),
      ),
    );

    if (result != null && result.isNotEmpty && context.mounted) {
      ref
          .read(appSettingsProvider.notifier)
          .update((s) => s.copyWith(stickyHotkey: result));
      await ref.read(globalHotkeyServiceProvider).register(result, () {
        final integration = ref.read(stickyDesktopIntegrationProvider);
        unawaited(integration?.createNewSticky());
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.stickySettingsHotkeySaved(result))),
        );
      }
    }
  }
}
