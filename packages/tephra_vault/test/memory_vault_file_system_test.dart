// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';
import 'package:test/test.dart';

import 'vault_file_system_contract.dart';

void main() {
  runVaultFileSystemContract(
    'MemoryVaultFileSystem',
    () async => MemoryVaultFileSystem(),
  );

  group('MemoryVaultFileSystem extras', () {
    test('putText, putBytes, textOf and writeCount tracking', () async {
      final fs = MemoryVaultFileSystem();
      fs.putText('quick.md', 'hello world');
      expect(fs.textOf('quick.md'), equals('hello world'));
      expect(fs.writeCount, equals(0)); // putText does not increment writeCount

      await fs.writeText(
        VaultPath('tracked.md'),
        const TextDocument(text: 'track'),
      );
      expect(fs.writeCount, equals(1));
      expect(fs.writeLog, equals(['tracked.md']));
      expect(fs.textOf('tracked.md'), equals('track'));
    });

    test('case-insensitive mode supports case-only rename', () async {
      final fs = MemoryVaultFileSystem(caseInsensitive: true);
      await fs.writeText(
        VaultPath('note.md'),
        const TextDocument(text: 'text'),
      );
      await fs.move(VaultPath('note.md'), VaultPath('Note.md'));
      final list = await fs.list();
      expect(list.map((e) => e.path.value).toList(), equals(['Note.md']));
    });

    test('emit pushes to watch stream respecting ignore rules', () async {
      final fs = MemoryVaultFileSystem();
      final events = <VaultChange>[];
      final sub = fs.watch().listen(events.add);

      fs.emit(FileCreated(VaultPath('open.md')));
      fs.emit(FileCreated(VaultPath('.obsidian/ignore.json')));

      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sub.cancel();

      expect(events.length, equals(1));
      expect(events.first.path.value, equals('open.md'));
    });
  });
}
