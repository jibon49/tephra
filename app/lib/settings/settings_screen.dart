// © 2026 Tephra. All rights reserved.

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';

import '../core/providers.dart';
import '../l10n/app_localizations.dart';
import '../vault/note_tools/template_picker.dart';
import 'hotkeys_screen.dart';

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

          // --- Sync (Debug) ---
          if (kDebugMode) ...[
            const _SectionHeader(title: 'Sync (Debug)'),
            Consumer(
              builder: (context, ref, _) {
                return ListTile(
                  title: const Text('Test Google sign-in'),
                  subtitle: const Text('Connects to Google Drive using OAuth'),
                  trailing: ElevatedButton(
                    onPressed: () async {
                      try {
                        final auth = ref.read(googleAuthServiceProvider);
                        final account = await auth.signInInteractive();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Signed in as: ${account.email}'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Sign-in failed: $e')),
                          );
                        }
                      }
                    },
                    child: const Text('Sign in'),
                  ),
                );
              },
            ),
            const Divider(),
          ],

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
