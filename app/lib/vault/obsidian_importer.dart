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

    var attachmentFolder = '/';
    var newFileLocation = 'root';
    var newFileFolder = '';
    var trashMode = 'vaultTrash';
    var useTab = true;
    var tabSize = 4;
    var readableLineLength = true;
    var defaultViewMode = 'source';
    var newLinkFormat = 'shortest';
    var useMarkdownLinks = false;
    var alwaysUpdateLinks = true;
    var excludedFolders = <String>[];

    Map<String, Object?> dailyNotes = const {};
    Map<String, Object?> templates = const {};

    // 1. app.json
    final appJsonPath = VaultPath('.obsidian/app.json');
    final appStat = await fs.stat(appJsonPath);
    if (appStat != null && !appStat.isFolder) {
      try {
        final doc = await fs.readText(appJsonPath);
        final decoded = json.decode(doc.text);
        if (decoded is Map<String, Object?>) {
          if (decoded['attachmentFolderPath'] is String) {
            attachmentFolder = decoded['attachmentFolderPath'] as String;
          }

          final loc = decoded['newFileLocation'];
          if (loc == 'root' || loc == 'current' || loc == 'folder') {
            newFileLocation = loc as String;
          }

          if (decoded['newFileFolderPath'] is String) {
            newFileFolder = decoded['newFileFolderPath'] as String;
          }

          if (decoded['useTab'] is bool) {
            useTab = decoded['useTab'] as bool;
          }

          if (decoded['tabSize'] is int) {
            final sz = decoded['tabSize'] as int;
            if (sz >= 2 && sz <= 8) {
              tabSize = sz;
            }
          }

          if (decoded['readableLineLength'] is bool) {
            readableLineLength = decoded['readableLineLength'] as bool;
          }

          final trash = decoded['trashOption'];
          if (trash == 'system') {
            trashMode = 'system';
          } else if (trash == 'local') {
            trashMode = 'vaultTrash';
          } else if (trash == 'none') {
            trashMode = 'permanent';
          }

          final viewMode = decoded['defaultViewMode'];
          if (viewMode == 'preview') {
            defaultViewMode = 'reading';
          } else {
            defaultViewMode = 'source';
          }

          if (decoded['newLinkFormat'] is String) {
            final f = decoded['newLinkFormat'] as String;
            if (f == 'shortest' || f == 'relative' || f == 'absolute') {
              newLinkFormat = f;
            }
          }

          if (decoded['useMarkdownLinks'] is bool) {
            useMarkdownLinks = decoded['useMarkdownLinks'] as bool;
          }

          if (decoded['alwaysUpdateLinks'] is bool) {
            alwaysUpdateLinks = decoded['alwaysUpdateLinks'] as bool;
          }

          if (decoded['userIgnoreFilters'] is List) {
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
          final m = <String, Object?>{};
          if (decoded['folder'] is String) m['folder'] = decoded['folder'];
          if (decoded['format'] is String) m['format'] = decoded['format'];
          if (decoded['template'] is String) {
            m['template'] = decoded['template'];
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
          final m = <String, Object?>{};
          if (decoded['folder'] is String) m['folder'] = decoded['folder'];
          if (decoded['dateFormat'] is String) {
            m['dateFormat'] = decoded['dateFormat'];
          }
          if (decoded['timeFormat'] is String) {
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
