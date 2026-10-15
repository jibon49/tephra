// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/properties/property_type.dart';
import 'package:tephra/properties/property_type_registry.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/tephra_index.dart';
import 'package:tephra_vault/tephra_vault.dart';

void main() {
  group('PropertyTypeRegistry', () {
    late MemoryVaultFileSystem fs;
    late PropertyTypeRegistry registry;

    setUp(() {
      fs = MemoryVaultFileSystem();
      registry = PropertyTypeRegistry(fs);
    });

    test('.obsidian/types.json imported once into .tephra/types.json, .obsidian never written', () async {
      await fs.createFolder(VaultPath('.obsidian'));
      await fs.writeText(
        PropertyTypeRegistry.obsidianTypesPath,
        TextDocument(
          text: jsonEncode({
            'types': {'due': 'date'},
          }),
        ),
      );

      await registry.load();

      expect(registry.types['due'], equals('date'));
      expect(await fs.stat(PropertyTypeRegistry.typesPath), isNotNull);

      final tephraDoc = await fs.readText(PropertyTypeRegistry.typesPath);
      expect(tephraDoc.text.contains('"due": "date"'), isTrue);

      // Verify .obsidian content was not modified
      final obsidianDoc = await fs.readText(
        PropertyTypeRegistry.obsidianTypesPath,
      );
      expect(obsidianDoc.text, equals('{"types":{"due":"date"}}'));
    });

    test('precedence: registry > built-in > index > inference', () async {
      final fakeKeys = [
        const PropertyKeyCount(key: 'custom', count: 1, valueType: 'number'),
        const PropertyKeyCount(key: 'tags', count: 1, valueType: 'text'),
      ];

      // Inference without registry or index
      expect(registry.typeFor('x', true), equals(PropertyType.checkbox));
      expect(registry.typeFor('x', 2), equals(PropertyType.number));
      expect(registry.typeFor('x', ['a']), equals(PropertyType.multitext));
      expect(registry.typeFor('x', '2026-10-11'), equals(PropertyType.date));
      expect(
        registry.typeFor('x', '2026-10-11T09:30'),
        equals(PropertyType.datetime),
      );

      // Built-in takes precedence over inference and index
      expect(registry.typeFor('tags', 'a'), equals(PropertyType.tags));
      expect(
        registry.typeFor('tags', 'a', indexPropertyKeys: fakeKeys),
        equals(PropertyType.tags),
      );

      // Index takes precedence over inference
      expect(
        registry.typeFor('custom', 'some string', indexPropertyKeys: fakeKeys),
        equals(PropertyType.number),
      );

      // Registry takes precedence over built-in and index
      await registry.setType('tags', PropertyType.text);
      expect(registry.typeFor('tags', 'a'), equals(PropertyType.text));
    });

    test('setType twice with identical value writes once', () async {
      await registry.setType('priority', PropertyType.number);
      final firstDoc = await fs.readText(PropertyTypeRegistry.typesPath);

      // Modify nothing on second setType
      await registry.setType('priority', PropertyType.number);
      final secondDoc = await fs.readText(PropertyTypeRegistry.typesPath);

      expect(secondDoc.text, equals(firstDoc.text));
    });

    test('unknown top-level key "extra": 1 preserved', () async {
      await fs.createFolder(VaultPath('.tephra'));
      await fs.writeText(
        PropertyTypeRegistry.typesPath,
        TextDocument(
          text: const JsonEncoder.withIndent('  ').convert({
            'extra': 1,
            'types': {'status': 'text'},
          }),
        ),
      );

      await registry.load();
      await registry.setType('status', PropertyType.multitext);

      final doc = await fs.readText(PropertyTypeRegistry.typesPath);
      final decoded = jsonDecode(doc.text) as Map;
      expect(decoded['extra'], equals(1));
      expect((decoded['types'] as Map)['status'], equals('multitext'));
    });

    test('broken JSON creates backup file on first change', () async {
      await fs.createFolder(VaultPath('.tephra'));
      const brokenJson = '{ not valid json';
      await fs.writeText(
        PropertyTypeRegistry.typesPath,
        const TextDocument(text: brokenJson),
      );

      await registry.load();
      expect(await fs.stat(PropertyTypeRegistry.typesBackupPath), isNull);

      await registry.setType('newKey', PropertyType.checkbox);
      expect(await fs.stat(PropertyTypeRegistry.typesBackupPath), isNotNull);

      final backupDoc = await fs.readText(PropertyTypeRegistry.typesBackupPath);
      expect(backupDoc.text, equals(brokenJson));

      final newDoc = await fs.readText(PropertyTypeRegistry.typesPath);
      final decoded = jsonDecode(newDoc.text) as Map;
      expect((decoded['types'] as Map)['newKey'], equals('checkbox'));
    });
  });
}
