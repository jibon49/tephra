// © 2026 Tephra. All rights reserved.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/core/json_file_store.dart';
import 'package:tephra/settings/vault_settings_store.dart';
import 'package:tephra/vault/obsidian_importer.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

void main() {
  final clock = ManualClock(DateTime.utc(2026, 10, 11, 9, 30));

  test(
    'full import fills every mapped field and never writes under .obsidian',
    () async {
      final fs = MemoryVaultFileSystem(clock: clock);

      // Create .obsidian folder and files
      await fs.writeText(
        VaultPath('.obsidian/app.json'),
        const TextDocument(
          text: '''
{
  "attachmentFolderPath": "Attachments",
  "newFileLocation": "folder",
  "newFileFolderPath": "Inbox",
  "useTab": false,
  "tabSize": 2,
  "readableLineLength": false,
  "trashOption": "local",
  "defaultViewMode": "preview"
}
''',
        ),
      );

      await fs.writeText(
        VaultPath('.obsidian/daily-notes.json'),
        const TextDocument(
          text: '''
{
  "folder": "Daily",
  "format": "YYYY-MM-DD",
  "template": "T"
}
''',
        ),
      );

      await fs.writeText(
        VaultPath('.obsidian/templates.json'),
        const TextDocument(
          text: '''
{
  "folder": "Templates",
  "dateFormat": "YYYY-MM-DD",
  "timeFormat": "HH:mm"
}
''',
        ),
      );

      await fs.writeText(
        VaultPath('.obsidian/hotkeys.json'),
        const TextDocument(
          text: '''
{
  "editor:toggle-bold": [{"modifiers": ["Mod"], "key": "b"}]
}
''',
        ),
      );

      final bookmarksBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      await fs.writeBytes(
        VaultPath('.obsidian/bookmarks.json'),
        bookmarksBytes,
      );

      final typesBytes = Uint8List.fromList([6, 7, 8]);
      await fs.writeBytes(VaultPath('.obsidian/types.json'), typesBytes);

      final importer = ObsidianImporter(fs, clock);
      final summary = await importer.run();

      expect(summary.foundObsidian, isTrue);
      expect(
        summary.imported,
        containsAll([
          'app.json',
          'daily-notes.json',
          'templates.json',
          'hotkeys.json',
          'bookmarks.json',
          'types.json',
        ]),
      );

      final settings = await VaultSettingsStore(fs).load();
      expect(settings.attachmentFolder, equals('Attachments'));
      expect(settings.newFileLocation, equals('folder'));
      expect(settings.newFileFolder, equals('Inbox'));
      expect(settings.useTab, isFalse);
      expect(settings.tabSize, equals(2));
      expect(settings.readableLineLength, isFalse);
      expect(settings.trashMode, equals('vaultTrash'));
      expect(settings.defaultViewMode, equals('reading'));
      expect(settings.importedFromObsidian, isTrue);
      expect(
        settings.dailyNotes,
        equals({'folder': 'Daily', 'format': 'YYYY-MM-DD', 'template': 'T'}),
      );
      expect(
        settings.templates,
        equals({
          'folder': 'Templates',
          'dateFormat': 'YYYY-MM-DD',
          'timeFormat': 'HH:mm',
        }),
      );

      // Bookmarks bytes copied identically
      final copiedBookmarks = await fs.readBytes(
        VaultPath('.tephra/bookmarks.json'),
      );
      expect(copiedBookmarks, equals(bookmarksBytes));

      // Hotkeys written
      const store = TephraJsonStore();
      final hotkeysMap = await store.readMap(
        fs,
        VaultPath('.tephra/hotkeys.json'),
      );
      expect(hotkeysMap['editor.toggle-bold'], equals(['Ctrl+B']));

      // Assert fs.writeLog has no write under .obsidian after importer started
      final importerWrites = fs.writeLog.skip(6); // first 6 were setup
      for (final writePath in importerWrites) {
        expect(writePath.startsWith('.obsidian'), isFalse);
      }
    },
  );

  test(
    'no .obsidian creates settings with importedFromObsidian: false',
    () async {
      final fs = MemoryVaultFileSystem(clock: clock);
      final importer = ObsidianImporter(fs, clock);
      final summary = await importer.run();

      expect(summary.foundObsidian, isFalse);
      expect(summary.imported, isEmpty);

      final settings = await VaultSettingsStore(fs).load();
      expect(settings.importedFromObsidian, isFalse);
      expect(settings.attachmentFolder, equals('/')); // defaults
    },
  );

  test('app.json without defaultViewMode defaults to source', () async {
    final fs = MemoryVaultFileSystem(clock: clock);
    await fs.writeText(
      VaultPath('.obsidian/app.json'),
      const TextDocument(text: '{"attachmentFolderPath": "Att"}'),
    );

    final importer = ObsidianImporter(fs, clock);
    await importer.run();

    final settings = await VaultSettingsStore(fs).load();
    expect(settings.defaultViewMode, equals('source'));
  });

  test('existing .tephra/bookmarks.json is not overwritten', () async {
    final fs = MemoryVaultFileSystem(clock: clock);
    await fs.writeText(
      VaultPath('.tephra/bookmarks.json'),
      const TextDocument(text: 'existing tephra bookmarks'),
    );
    await fs.writeText(
      VaultPath('.obsidian/bookmarks.json'),
      const TextDocument(text: 'new obsidian bookmarks'),
    );

    final importer = ObsidianImporter(fs, clock);
    final summary = await importer.run();

    expect(summary.skipped, contains('bookmarks.json'));
    final doc = await fs.readText(VaultPath('.tephra/bookmarks.json'));
    expect(doc.text, equals('existing tephra bookmarks'));
  });

  test('invalid app.json is skipped, other files still imported', () async {
    final fs = MemoryVaultFileSystem(clock: clock);
    await fs.writeText(
      VaultPath('.obsidian/app.json'),
      const TextDocument(text: '{corrupt json'),
    );
    await fs.writeText(
      VaultPath('.obsidian/daily-notes.json'),
      const TextDocument(text: '{"folder": "Daily"}'),
    );

    final importer = ObsidianImporter(fs, clock);
    final summary = await importer.run();

    expect(summary.skipped, contains('app.json'));
    expect(summary.imported, contains('daily-notes.json'));

    final settings = await VaultSettingsStore(fs).load();
    expect(settings.dailyNotes, equals({'folder': 'Daily'}));
    expect(settings.attachmentFolder, equals('/')); // default preserved
  });
}
