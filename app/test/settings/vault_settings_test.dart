// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/core/json_file_store.dart';
import 'package:tephra/settings/vault_settings.dart';
import 'package:tephra/settings/vault_settings_store.dart';
import 'package:tephra_vault/tephra_vault.dart';

void main() {
  group('VaultSettings', () {
    test('fromJson({}) equals default values', () {
      final s = VaultSettings.fromJson({});
      const expected = VaultSettings();
      expect(s, equals(expected));
      expect(s.attachmentFolder, equals('/'));
      expect(s.newFileLocation, equals('root'));
      expect(s.trashMode, equals('vaultTrash'));
      expect(s.tabSize, equals(4));
      expect(s.fontSize, equals(16.0));
      expect(s.defaultViewMode, equals('reading'));
      expect(s.explorerSort, equals('nameAsc'));
      expect(s.trashModeEnum, equals(TrashMode.vaultTrash));
      expect(s.newLinkFormat, equals('shortest'));
      expect(s.useMarkdownLinks, isFalse);
      expect(s.alwaysUpdateLinks, isTrue);
      expect(s.excludedFolders, isEmpty);
    });

    test('every key round-trips correctly', () {
      const original = VaultSettings(
        attachmentFolder: './attachments',
        newFileLocation: 'folder',
        newFileFolder: 'notes',
        trashMode: 'system',
        showHidden: true,
        useTab: false,
        tabSize: 2,
        readableLineLength: false,
        defaultViewMode: 'source',
        fontSize: 18.0,
        explorerSort: 'modifiedNew',
        dailyNotes: {'folder': 'daily', 'format': 'YYYY-MM-DD'},
        templates: {'folder': 'templates'},
        importedFromObsidian: true,
        newLinkFormat: 'relative',
        useMarkdownLinks: true,
        alwaysUpdateLinks: false,
        excludedFolders: ['Archive', 'Templates/Hidden'],
        extra: {'unknownField': 123},
      );

      final json = original.toJson();
      final reloaded = VaultSettings.fromJson(json);
      expect(reloaded, equals(original));
      expect(reloaded.trashModeEnum, equals(TrashMode.system));
      expect(reloaded.newFileLocationEnum, equals(NewFileLocation.folder));
      expect(reloaded.viewMode, equals(ViewModeSetting.source));
      expect(reloaded.explorerSortEnum, equals(ExplorerSort.modifiedNew));
      expect(reloaded.newLinkFormat, equals('relative'));
      expect(reloaded.useMarkdownLinks, isTrue);
      expect(reloaded.alwaysUpdateLinks, isFalse);
      expect(reloaded.excludedFolders, equals(['Archive', 'Templates/Hidden']));
    });

    test('invalid values fall back to defaults (clamping/enumeration)', () {
      final s = VaultSettings.fromJson({
        'tabSize': 99,
        'fontSize': 5.0,
        'trashMode': 'bogus',
        'newFileLocation': 'invalidLocation',
        'defaultViewMode': 'invalidMode',
        'explorerSort': 'invalidSort',
        'newLinkFormat': 'invalidLinkFormat',
      });

      expect(s.tabSize, equals(4));
      expect(s.fontSize, equals(16.0));
      expect(s.trashMode, equals('vaultTrash'));
      expect(s.newFileLocation, equals('root'));
      expect(s.defaultViewMode, equals('reading'));
      expect(s.explorerSort, equals('nameAsc'));
      expect(s.newLinkFormat, equals('shortest'));
      expect(s.useMarkdownLinks, isFalse);
      expect(s.alwaysUpdateLinks, isTrue);
      expect(s.excludedFolders, isEmpty);
    });
  });

  group('VaultSettingsStore', () {
    late MemoryVaultFileSystem fs;
    late VaultSettingsStore store;

    setUp(() {
      fs = MemoryVaultFileSystem();
      store = VaultSettingsStore(fs);
    });

    test('unknown keys preserved after VaultSettingsStore.save', () async {
      final jsonStore = const TephraJsonStore();
      await jsonStore.writeMap(fs, VaultSettingsStore.settingsPath, {
        'fontSize': 20.0,
        'unrecognizedSetting': {'hello': 'world'},
      });

      final loaded = await store.load();
      expect(loaded.fontSize, equals(20.0));
      expect(loaded.extra['unrecognizedSetting'], equals({'hello': 'world'}));

      final updated = loaded.copyWith(tabSize: 2);
      await store.save(updated);

      final reloaded = await store.load();
      expect(reloaded.tabSize, equals(2));
      expect(reloaded.fontSize, equals(20.0));
      expect(reloaded.extra['unrecognizedSetting'], equals({'hello': 'world'}));
    });

    test('saving two settings changes in a row leaves both changes', () async {
      await store.save(const VaultSettings(fontSize: 18.0));
      final s1 = await store.load();
      await store.save(s1.copyWith(tabSize: 2));

      final finalSettings = await store.load();
      expect(finalSettings.fontSize, equals(18.0));
      expect(finalSettings.tabSize, equals(2));
    });
  });
}
