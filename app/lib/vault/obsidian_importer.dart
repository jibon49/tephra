// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:tephra/core/json_file_store.dart';
import 'package:tephra/settings/vault_settings.dart';
import 'package:tephra/settings/vault_settings_store.dart';
import 'package:tephra/vault/obsidian_hotkeys.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

final class ImportSummary {
  const ImportSummary({
    required this.foundObsidian,
    required this.imported,
    required this.skipped,
  });

  final bool foundObsidian;
  final List<String> imported;
  final List<String> skipped;
}

final class ObsidianImporter {
  ObsidianImporter(this.fs, this.clock);

  final VaultFileSystem fs;
  final Clock clock;
  final _log = Logger('obsidian_importer');

  Future<ImportSummary> run() async {
    const store = TephraJsonStore();
    final obsidianDir = VaultPath('.obsidian');
    final obsidianStat = await fs.stat(obsidianDir);

    if (obsidianStat == null) {
      await VaultSettingsStore(fs)
          .save(const VaultSettings(importedFromObsidian: false));
      return const ImportSummary(
        foundObsidian: false,
        imported: [],
        skipped: [],
      );
    }

    final imported = <String>[];
    final skipped = <String>[];

    final existingRaw = await store.readMap(
      fs,
      VaultSettingsStore.settingsPath,
    );

    var attachmentFolder = existingRaw['attachmentFolder'] as String? ?? '/';
    var newFileLocation = existingRaw['newFileLocation'] as String? ?? 'root';
    var newFileFolder = existingRaw['newFileFolder'] as String? ?? '';
    var trashMode = existingRaw['trashMode'] as String? ?? 'vaultTrash';
    var useTab = existingRaw['useTab'] as bool? ?? true;
    var tabSize = existingRaw['tabSize'] as int? ?? 4;
    var readableLineLength = existingRaw['readableLineLength'] as bool? ?? true;
    var defaultViewMode = existingRaw['defaultViewMode'] as String? ?? 'source';
    var newLinkFormat = existingRaw['newLinkFormat'] as String? ?? 'shortest';
    var useMarkdownLinks = existingRaw['useMarkdownLinks'] as bool? ?? false;
    var alwaysUpdateLinks = existingRaw['alwaysUpdateLinks'] as bool? ?? true;
    var excludedFolders = existingRaw['excludedFolders'] is List
        ? (existingRaw['excludedFolders'] as List)
              .map((e) => e.toString())
              .toList()
        : <String>[];

    final existingDaily = existingRaw['dailyNotes'] is Map
        ? Map<String, Object?>.from(existingRaw['dailyNotes'] as Map)
        : <String, Object?>{};
    final existingTemplates = existingRaw['templates'] is Map
        ? Map<String, Object?>.from(existingRaw['templates'] as Map)
        : <String, Object?>{};
    final existingUnique = existingRaw['uniqueNote'] is Map
        ? Map<String, Object?>.from(existingRaw['uniqueNote'] as Map)
        : <String, Object?>{};

    Map<String, Object?> dailyNotes = existingDaily;
    Map<String, Object?> templates = existingTemplates;
    Map<String, Object?> uniqueNote = existingUnique;

    // 1. app.json
    final appJsonPath = VaultPath('.obsidian/app.json');
    final appStat = await fs.stat(appJsonPath);
    if (appStat != null && !appStat.isFolder) {
      try {
        final doc = await fs.readText(appJsonPath);
        final decoded = json.decode(doc.text);
        if (decoded is Map<String, Object?>) {
          if (!existingRaw.containsKey('attachmentFolder') &&
              decoded['attachmentFolderPath'] is String) {
            attachmentFolder = decoded['attachmentFolderPath'] as String;
          }

          final loc = decoded['newFileLocation'];
          if (!existingRaw.containsKey('newFileLocation') &&
              (loc == 'root' || loc == 'current' || loc == 'folder')) {
            newFileLocation = loc as String;
          }

          if (!existingRaw.containsKey('newFileFolder') &&
              decoded['newFileFolderPath'] is String) {
            newFileFolder = decoded['newFileFolderPath'] as String;
          }

          if (!existingRaw.containsKey('useTab') && decoded['useTab'] is bool) {
            useTab = decoded['useTab'] as bool;
          }

          if (!existingRaw.containsKey('tabSize') &&
              decoded['tabSize'] is int) {
            final sz = decoded['tabSize'] as int;
            if (sz >= 2 && sz <= 8) {
              tabSize = sz;
            }
          }

          if (!existingRaw.containsKey('readableLineLength') &&
              decoded['readableLineLength'] is bool) {
            readableLineLength = decoded['readableLineLength'] as bool;
          }

          if (!existingRaw.containsKey('trashMode')) {
            final trash = decoded['trashOption'];
            if (trash == 'system') {
              trashMode = 'system';
            } else if (trash == 'local') {
              trashMode = 'vaultTrash';
            } else if (trash == 'none') {
              trashMode = 'permanent';
            }
          }

          if (!existingRaw.containsKey('defaultViewMode')) {
            final viewMode = decoded['defaultViewMode'];
            if (viewMode == 'preview') {
              defaultViewMode = 'reading';
            } else {
              defaultViewMode = 'source';
            }
          }

          if (!existingRaw.containsKey('newLinkFormat') &&
              decoded['newLinkFormat'] is String) {
            final f = decoded['newLinkFormat'] as String;
            if (f == 'shortest' || f == 'relative' || f == 'absolute') {
              newLinkFormat = f;
            }
          }

          if (!existingRaw.containsKey('useMarkdownLinks') &&
              decoded['useMarkdownLinks'] is bool) {
            useMarkdownLinks = decoded['useMarkdownLinks'] as bool;
          }

          if (!existingRaw.containsKey('alwaysUpdateLinks') &&
              decoded['alwaysUpdateLinks'] is bool) {
            alwaysUpdateLinks = decoded['alwaysUpdateLinks'] as bool;
          }

          if (!existingRaw.containsKey('excludedFolders') &&
              decoded['userIgnoreFilters'] is List) {
            excludedFolders = (decoded['userIgnoreFilters'] as List)
                .map((e) => e.toString())
                .where((e) => e.isNotEmpty)
                .toList();
          }

          imported.add('app.json');
        } else {
          skipped.add('app.json');
        }
      } catch (e, st) {
        _log.warning('Failed to parse .obsidian/app.json: $e', e, st);
        skipped.add('app.json');
      }
    }

    // 2. daily-notes.json
    final dailyPath = VaultPath('.obsidian/daily-notes.json');
    final dailyStat = await fs.stat(dailyPath);
    if (dailyStat != null && !dailyStat.isFolder) {
      try {
        final doc = await fs.readText(dailyPath);
        final decoded = json.decode(doc.text);
        if (decoded is Map<String, Object?>) {
          final m = Map<String, Object?>.from(existingDaily);
          if (!existingDaily.containsKey('folder') &&
              decoded['folder'] is String) {
            m['folder'] = decoded['folder'];
          }
          if (!existingDaily.containsKey('format') &&
              decoded['format'] is String) {
            m['format'] = decoded['format'];
          }
          if (!existingDaily.containsKey('template') &&
              decoded['template'] is String) {
            m['template'] = decoded['template'];
          }
          if (!existingDaily.containsKey('openOnStartup') &&
              decoded['autorun'] is bool) {
            m['openOnStartup'] = decoded['autorun'];
          }
          dailyNotes = m;
          imported.add('daily-notes.json');
        } else {
          skipped.add('daily-notes.json');
        }
      } catch (e, st) {
        _log.warning('Failed to parse .obsidian/daily-notes.json: $e', e, st);
        skipped.add('daily-notes.json');
      }
    }

    // 3. templates.json
    final tmplPath = VaultPath('.obsidian/templates.json');
    final tmplStat = await fs.stat(tmplPath);
    if (tmplStat != null && !tmplStat.isFolder) {
      try {
        final doc = await fs.readText(tmplPath);
        final decoded = json.decode(doc.text);
        if (decoded is Map<String, Object?>) {
          final m = Map<String, Object?>.from(existingTemplates);
          if (!existingTemplates.containsKey('folder') &&
              decoded['folder'] is String) {
            m['folder'] = decoded['folder'];
          }
          if (!existingTemplates.containsKey('dateFormat') &&
              decoded['dateFormat'] is String) {
            m['dateFormat'] = decoded['dateFormat'];
          }
          if (!existingTemplates.containsKey('timeFormat') &&
              decoded['timeFormat'] is String) {
            m['timeFormat'] = decoded['timeFormat'];
          }
          templates = m;
          imported.add('templates.json');
        } else {
          skipped.add('templates.json');
        }
      } catch (e, st) {
        _log.warning('Failed to parse .obsidian/templates.json: $e', e, st);
        skipped.add('templates.json');
      }
    }

    // 3b. zk-prefixer.json
    final zkPath = VaultPath('.obsidian/zk-prefixer.json');
    final zkStat = await fs.stat(zkPath);
    if (zkStat != null && !zkStat.isFolder) {
      try {
        final doc = await fs.readText(zkPath);
        final decoded = json.decode(doc.text);
        if (decoded is Map<String, Object?>) {
          final m = Map<String, Object?>.from(existingUnique);
          if (!existingUnique.containsKey('prefixFormat') &&
              decoded['format'] is String) {
            m['prefixFormat'] = decoded['format'];
          }
          if (!existingUnique.containsKey('folder') &&
              decoded['folder'] is String) {
            m['folder'] = decoded['folder'];
          }
          if (!existingUnique.containsKey('template') &&
              decoded['template'] is String) {
            m['template'] = decoded['template'];
          }
          uniqueNote = m;
          imported.add('zk-prefixer.json');
        } else {
          skipped.add('zk-prefixer.json');
        }
      } catch (e, st) {
        _log.warning('Failed to parse .obsidian/zk-prefixer.json: $e', e, st);
        skipped.add('zk-prefixer.json');
      }
    }

    // 4. hotkeys.json
    final hotkeysPath = VaultPath('.obsidian/hotkeys.json');
    final hotkeysStat = await fs.stat(hotkeysPath);
    if (hotkeysStat != null && !hotkeysStat.isFolder) {
      final targetPath = VaultPath('.tephra/hotkeys.json');
      final targetStat = await fs.stat(targetPath);
      if (targetStat == null) {
        try {
          final doc = await fs.readText(hotkeysPath);
          final decoded = json.decode(doc.text);
          if (decoded is Map<String, Object?>) {
            final converted = convertObsidianHotkeys(decoded);
            await store.writeMap(fs, targetPath, converted);
            imported.add('hotkeys.json');
          } else {
            skipped.add('hotkeys.json');
          }
        } catch (e, st) {
          _log.warning('Failed to import hotkeys.json: $e', e, st);
          skipped.add('hotkeys.json');
        }
      } else {
        skipped.add('hotkeys.json');
      }
    }

    // 5. bookmarks.json
    final bookmarksPath = VaultPath('.obsidian/bookmarks.json');
    final bookmarksStat = await fs.stat(bookmarksPath);
    if (bookmarksStat != null && !bookmarksStat.isFolder) {
      final targetPath = VaultPath('.tephra/bookmarks.json');
      final targetStat = await fs.stat(targetPath);
      if (targetStat == null) {
        try {
          final bytes = await fs.readBytes(bookmarksPath);
          await fs.writeBytes(targetPath, bytes);
          imported.add('bookmarks.json');
        } catch (e, st) {
          _log.warning('Failed to copy bookmarks.json: $e', e, st);
          skipped.add('bookmarks.json');
        }
      } else {
        skipped.add('bookmarks.json');
      }
    }

    // 6. types.json
    final typesPath = VaultPath('.obsidian/types.json');
    final typesStat = await fs.stat(typesPath);
    if (typesStat != null && !typesStat.isFolder) {
      final targetPath = VaultPath('.tephra/types.json');
      final targetStat = await fs.stat(targetPath);
      if (targetStat == null) {
        try {
          final bytes = await fs.readBytes(typesPath);
          await fs.writeBytes(targetPath, bytes);
          imported.add('types.json');
        } catch (e, st) {
          _log.warning('Failed to copy types.json: $e', e, st);
          skipped.add('types.json');
        }
      } else {
        skipped.add('types.json');
      }
    }

    final vaultSettings = VaultSettings(
      attachmentFolder: attachmentFolder,
      newFileLocation: newFileLocation,
      newFileFolder: newFileFolder,
      trashMode: trashMode,
      useTab: useTab,
      tabSize: tabSize,
      readableLineLength: readableLineLength,
      defaultViewMode: defaultViewMode,
      dailyNotes: dailyNotes,
      templates: templates,
      uniqueNote: uniqueNote,
      importedFromObsidian: true,
      newLinkFormat: newLinkFormat,
      useMarkdownLinks: useMarkdownLinks,
      alwaysUpdateLinks: alwaysUpdateLinks,
      excludedFolders: excludedFolders,
    );

    await VaultSettingsStore(fs).save(vaultSettings);

    return ImportSummary(
      foundObsidian: true,
      imported: imported,
      skipped: skipped,
    );
  }
}
