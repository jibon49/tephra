// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';
import 'package:test/test.dart';

import 'vault_file_system_contract.dart';

class _FakeSystemTrash implements SystemTrash {
  String? movedPath;
  bool shouldSucceed = true;

  @override
  Future<bool> moveToTrash(
    String absolutePath, {
    required bool isFolder,
  }) async {
    movedPath = absolutePath;
    return shouldSucceed;
  }
}

void main() {
  late Directory tempDir;

  runVaultFileSystemContract('IoVaultFileSystem', () async {
    final sub = Directory.systemTemp.createTempSync('tephra_io_contract_');
    return IoVaultFileSystem(sub.path);
  });

  group('IoVaultFileSystem IO specifics', () {
    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('tephra_io_specifics_');
    });

    tearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('1. no temp files left after a successful write', () async {
      final fs = IoVaultFileSystem(tempDir.path);
      await fs.writeText(
        VaultPath('note.md'),
        const TextDocument(text: 'data'),
      );

      final diskEntries = tempDir.listSync();
      expect(diskEntries.length, equals(1));
      expect(p.basename(diskEntries.first.path), equals('note.md'));
    });

    test('2. unchanged bytes of other files', () async {
      final fs = IoVaultFileSystem(tempDir.path);
      final aBytes = utf8.encode('file a content');
      await fs.writeBytes(VaultPath('a.md'), aBytes);

      await fs.writeBytes(VaultPath('b.md'), utf8.encode('file b content'));
      expect(await fs.readBytes(VaultPath('a.md')), equals(aBytes));
    });

    test(
      '3. case-only rename',
      () async {
        final fs = IoVaultFileSystem(tempDir.path, caseInsensitive: true);
        await fs.writeText(
          VaultPath('note.md'),
          const TextDocument(text: 'case'),
        );
        await fs.move(VaultPath('note.md'), VaultPath('Note.md'));

        final list = await fs.list();
        expect(list.length, equals(1));
        expect(list.first.path.value, equals('Note.md'));
      },
      skip: !Platform.isWindows
          ? 'Case-only rename is Windows-specific test'
          : null,
    );

    test(
      '4. list skips invalid names',
      () async {},
      skip: Platform.isWindows
          ? 'Windows filesystems reject colons in filenames'
          : null,
    );

    test(
      '5. invalid file name on disk is skipped',
      () async {},
      skip: Platform.isWindows
          ? 'Windows kernel reserved device names cannot be easily created'
          : null,
    );

    test('6. cleanStaleTemps removes only old temp files', () async {
      final clock = ManualClock(DateTime(2026, 1, 10, 12, 0));
      final fs = IoVaultFileSystem(tempDir.path, clock: clock);

      final staleTmp = File(p.join(tempDir.path, '.a.md.tephra-tmp-0a1b2c3d'));
      await staleTmp.writeAsString('stale');
      staleTmp.setLastModifiedSync(DateTime(2026, 1, 8, 12, 0)); // 2 days old

      final freshTmp = File(p.join(tempDir.path, '.b.md.tephra-tmp-12345678'));
      await freshTmp.writeAsString('fresh');
      freshTmp.setLastModifiedSync(DateTime(2026, 1, 10, 11, 0)); // 1 hour old

      final normalHidden = File(p.join(tempDir.path, '.hidden'));
      await normalHidden.writeAsString('hidden');
      normalHidden.setLastModifiedSync(DateTime(2026, 1, 1, 12, 0));

      final count = await fs.cleanStaleTemps(
        olderThan: const Duration(hours: 24),
      );
      expect(count, equals(1));
      expect(staleTmp.existsSync(), isFalse);
      expect(freshTmp.existsSync(), isTrue);
      expect(normalHidden.existsSync(), isTrue);
    });

    test('7. systemTrash is used when provided and true', () async {
      final fake = _FakeSystemTrash()..shouldSucceed = true;
      final fs = IoVaultFileSystem(tempDir.path, systemTrash: fake);

      final path = VaultPath('t.md');
      await fs.writeText(path, const TextDocument(text: 'trash'));
      await fs.delete(path, mode: TrashMode.system);

      expect(fake.movedPath, isNotNull);
      expect(fake.movedPath, contains('t.md'));
      expect(await fs.stat(VaultPath('.trash/t.md')), isNull);
    });

    test('8. systemTrash falls back when it returns false', () async {
      final fake = _FakeSystemTrash()..shouldSucceed = false;
      final fs = IoVaultFileSystem(tempDir.path, systemTrash: fake);

      final path = VaultPath('fallback.md');
      await fs.writeText(path, const TextDocument(text: 'fb'));
      await fs.delete(path, mode: TrashMode.system);

      expect(fake.movedPath, isNotNull);
      expect(await fs.stat(VaultPath('.trash/fallback.md')), isNotNull);
    });
  });
}
