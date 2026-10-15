// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/settings/vault_settings.dart';
import 'package:tephra/settings/vault_settings_store.dart';
import 'package:tephra/vault/obsidian_importer.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

void main() {
  group('VaultSettings - Note Tools Defaults', () {
    test('default settings have correct dailyNotes, templates, uniqueNote, corePlugins', () {
      const settings = VaultSettings();

      expect(settings.dailyNotesSettings.format, 'YYYY-MM-DD');
      expect(settings.dailyNotesSettings.folder, '');
      expect(settings.dailyNotesSettings.template, '');
      expect(settings.dailyNotesSettings.openOnStartup, isFalse);

      expect(settings.templatesFolder, '');
      expect(settings.templatesDateFormat, 'YYYY-MM-DD');
      expect(settings.templatesTimeFormat, 'HH:mm');

      expect(settings.uniqueNoteSettings.prefixFormat, 'YYYYMMDDHHmm');
      expect(settings.uniqueNoteSettings.folder, '');
      expect(settings.uniqueNoteSettings.template, '');

      expect(settings.corePluginsSettings.dailyNotes, isTrue);
      expect(settings.corePluginsSettings.templates, isTrue);
      expect(settings.corePluginsSettings.uniqueNoteCreator, isFalse);
    });

    test('JSON round-trip preserves unknown keys', () {
      final json = <String, Object?>{
        'dailyNotes': {
          'format': 'YYYY/MM/DD',
          'folder': 'Daily',
          'template': 'Templates/Daily.md',
          'autorun': true,
          'unknown_daily_key': 'preserved_daily',
        },
        'templates': {
          'folder': 'Templates',
          'dateFormat': 'DD-MM-YYYY',
          'timeFormat': 'hh:mm A',
          'unknown_template_key': 42,
        },
        'uniqueNote': {
          'format': 'YYYYMMDD-HHmmss',
          'folder': 'Zettel',
          'template': 'Templates/Zk.md',
          'unknown_unique_key': true,
        },
        'corePlugins': {
          'dailyNotes': false,
          'templates': true,
          'uniqueNoteCreator': false,
          'unknown_plugin': 'active',
        },
      };

      final parsed = VaultSettings.fromJson(json);
      expect(parsed.dailyNotesSettings.format, 'YYYY/MM/DD');
      expect(parsed.dailyNotesSettings.folder, 'Daily');
      expect(parsed.dailyNotesSettings.template, 'Templates/Daily.md');
      expect(parsed.dailyNotesSettings.openOnStartup, isTrue);
      expect(parsed.dailyNotes['unknown_daily_key'], 'preserved_daily');

      expect(parsed.templatesFolder, 'Templates');
      expect(parsed.templatesDateFormat, 'DD-MM-YYYY');
      expect(parsed.templatesTimeFormat, 'hh:mm A');
      expect(parsed.templates['unknown_template_key'], 42);

      expect(parsed.uniqueNoteSettings.prefixFormat, 'YYYYMMDD-HHmmss');
      expect(parsed.uniqueNoteSettings.folder, 'Zettel');
      expect(parsed.uniqueNoteSettings.template, 'Templates/Zk.md');
      expect(parsed.uniqueNote['unknown_unique_key'], isTrue);

      expect(parsed.corePluginsSettings.dailyNotes, isFalse);
      expect(parsed.corePluginsSettings.templates, isTrue);
      expect(parsed.corePluginsSettings.uniqueNoteCreator, isFalse);
      expect(parsed.corePlugins['unknown_plugin'], 'active');

      final outJson = parsed.toJson();
      final dailyOut = outJson['dailyNotes'] as Map<String, Object?>;
      expect(dailyOut['unknown_daily_key'], 'preserved_daily');
      final tmplOut = outJson['templates'] as Map<String, Object?>;
      expect(tmplOut['unknown_template_key'], 42);
      final uniqueOut = outJson['uniqueNote'] as Map<String, Object?>;
      expect(uniqueOut['unknown_unique_key'], isTrue);
      final coreOut = outJson['corePlugins'] as Map<String, Object?>;
      expect(coreOut['unknown_plugin'], 'active');
    });
  });

  group('ObsidianImporter', () {
    test('imports .obsidian/daily-notes.json with autorun: true -> openOnStartup: true', () async {
      final fs = MemoryVaultFileSystem();
      await fs.writeText(
        VaultPath('.obsidian/daily-notes.json'),
        TextDocument(
          text: jsonEncode({
            'format': 'YYYY/MM/DD',
            'folder': 'Journal',
            'template': 'Templates/Day',
            'autorun': true,
          }),
        ),
      );

      final importer = ObsidianImporter(fs, const SystemClock());
      await importer.run();

      final imported = await VaultSettingsStore(fs).load();
      expect(imported.dailyNotesSettings.format, 'YYYY/MM/DD');
      expect(imported.dailyNotesSettings.folder, 'Journal');
      expect(imported.dailyNotesSettings.template, 'Templates/Day');
      expect(imported.dailyNotesSettings.openOnStartup, isTrue);
    });

    test('imports .obsidian/zk-prefixer.json format -> prefixFormat', () async {
      final fs = MemoryVaultFileSystem();
      await fs.writeText(
        VaultPath('.obsidian/zk-prefixer.json'),
        TextDocument(
          text: jsonEncode({
            'format': 'YYYYMMDD-HHmmss',
            'folder': 'Zettelkasten',
            'template': 'Templates/Zk',
          }),
        ),
      );

      final importer = ObsidianImporter(fs, const SystemClock());
      await importer.run();

      final imported = await VaultSettingsStore(fs).load();
      expect(imported.uniqueNoteSettings.prefixFormat, 'YYYYMMDD-HHmmss');
      expect(imported.uniqueNoteSettings.folder, 'Zettelkasten');
      expect(imported.uniqueNoteSettings.template, 'Templates/Zk');
    });

    test(
      'preserves existing .tephra/settings.json keys and never overwrites them',
      () async {
        final fs = MemoryVaultFileSystem();
        // Existing Tephra settings
        await fs.writeText(
          VaultPath('.tephra/settings.json'),
          TextDocument(
            text: jsonEncode({
              'dailyNotes': {
                'format': 'YYYY-MM-DD-ddd',
                'folder': 'MyDaily',
                'template': 'MyTemplate',
                'openOnStartup': false,
              },
            }),
          ),
        );

        // Obsidian daily notes that should NOT overwrite existing
        await fs.writeText(
          VaultPath('.obsidian/daily-notes.json'),
          TextDocument(
            text: jsonEncode({
              'format': 'YYYY/MM/DD',
              'folder': 'ObsidianDaily',
              'template': 'ObsidianTemplate',
              'autorun': true,
            }),
          ),
        );

        final importer = ObsidianImporter(fs, const SystemClock());
        await importer.run();

        final imported = await VaultSettingsStore(fs).load();
        expect(imported.dailyNotesSettings.format, 'YYYY-MM-DD-ddd');
        expect(imported.dailyNotesSettings.folder, 'MyDaily');
        expect(imported.dailyNotesSettings.template, 'MyTemplate');
        expect(imported.dailyNotesSettings.openOnStartup, isFalse);
      },
    );
  });
}
