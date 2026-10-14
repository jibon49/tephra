// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/core/json_file_store.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

void main() {
  group('TephraJsonStore', () {
    late MemoryVaultFileSystem fs;
    late TephraJsonStore store;
    final path = VaultPath('settings.json');

    setUp(() {
      fs = MemoryVaultFileSystem();
      store = const TephraJsonStore();
    });

    test('readMap of a missing file returns empty map', () async {
      final map = await store.readMap(fs, path);
      expect(map, isEmpty);
    });

    test(
      'readMap of invalid JSON returns empty map without throwing',
      () async {
        await fs.writeBytes(path, [1, 2, 3, 4, 5]);
        final map = await store.readMap(fs, path);
        expect(map, isEmpty);
      },
    );

    test('update keeps unknown keys', () async {
      await store.writeMap(fs, path, {
        'zzz': [1, 2],
        'name': 'initial',
      });
      await store.update(fs, path, (map) {
        map['name'] = 'updated';
      });

      final reloaded = await store.readMap(fs, path);
      expect(reloaded['name'], equals('updated'));
      expect(reloaded['zzz'], equals([1, 2]));
    });

    test('writeMap returns false and fs.writeCount unchanged when content identical', () async {
      final initialMap = {'key': 'value', 'num': 42};
      final wroteFirst = await store.writeMap(fs, path, initialMap);
      expect(wroteFirst, isTrue);

      final countBefore = fs.writeCount;
      final wroteSecond = await store.writeMap(fs, path, initialMap);
      expect(wroteSecond, isFalse);
      expect(fs.writeCount, equals(countBefore));
    });

    test('writing over an invalid file creates settings.json.bad-<ts> with old bytes', () async {
      final corruptBytes = [0xDE, 0xAD, 0xBE, 0xEF];
      await fs.writeBytes(path, corruptBytes);

      final wrote = await store.writeMap(fs, path, {'valid': true});
      expect(wrote, isTrue);

      // Check bad file was created
      final entries = await fs.list(folder: path.parent ?? VaultPath.root);
      final badEntries = entries
          .where(
            (e) =>
                RegExp(r'^settings\.json\.bad-\d{14}$').hasMatch(e.path.name),
          )
          .toList();
      expect(badEntries.length, equals(1));

      final savedCorruptBytes = await fs.readBytes(badEntries.first.path);
      expect(savedCorruptBytes, equals(corruptBytes));

      // New file has valid content
      final validMap = await store.readMap(fs, path);
      expect(validMap['valid'], isTrue);
    });

    test('output ends with newline and uses 2-space indentation', () async {
      await store.writeMap(fs, path, {
        'a': {'b': 1},
      });
      final doc = await fs.readText(path);
      expect(doc.text.endsWith('\n'), isTrue);
      expect(doc.text, contains('  "a": {\n    "b": 1\n  }\n'));
    });
  });

  group('AppJsonFile', () {
    late Directory tempDir;
    late File file;
    late AppJsonFile appJsonFile;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('app_json_test_');
      file = File('${tempDir.path}/app_settings.json');
      appJsonFile = AppJsonFile(file);
    });

    tearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('readSync of missing file returns empty map', () {
      expect(appJsonFile.readSync(), isEmpty);
    });

    test('readSync of invalid file returns empty map without throwing', () {
      file.writeAsStringSync('corrupt json string {{{');
      expect(appJsonFile.readSync(), isEmpty);
    });

    test('write and readSync round-trips map', () async {
      await appJsonFile.write({'theme': 'dark', 'version': 1});
      final map = appJsonFile.readSync();
      expect(map['theme'], equals('dark'));
      expect(map['version'], equals(1));
    });
  });
}
