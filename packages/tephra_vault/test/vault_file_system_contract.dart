// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';
import 'package:test/test.dart';

void runVaultFileSystemContract(
  String name,
  Future<VaultFileSystem> Function() create,
) {
  group('VaultFileSystem contract ($name)', () {
    late VaultFileSystem fs;

    setUp(() async {
      fs = await create();
    });

    tearDown(() async {
      await fs.dispose();
    });

    test('1. write then read text', () async {
      final aPath = VaultPath('a.md');
      await fs.writeText(aPath, const TextDocument(text: 'hi'));
      final docA = await fs.readText(aPath);
      expect(docA.text, equals('hi'));

      final nested = VaultPath('x/y/z.md');
      await fs.writeText(nested, const TextDocument(text: 'nested text'));
      final docNested = await fs.readText(nested);
      expect(docNested.text, equals('nested text'));
    });

    test('2. write is bytes exact', () async {
      final binPath = VaultPath('b.bin');
      final bytes = [0, 1, 2, 255];
      await fs.writeBytes(binPath, bytes);
      expect(await fs.readBytes(binPath), equals(bytes));
    });

    test('3. missing file read throws', () async {
      final missing = VaultPath('nope.md');
      expect(
        () => fs.readBytes(missing),
        throwsA(isA<FileNotFoundException>()),
      );
      expect(await fs.stat(missing), isNull);
    });

    test('4. list sorted and recursive', () async {
      await fs.writeText(VaultPath('b.md'), const TextDocument(text: 'b'));
      await fs.writeText(VaultPath('a/c.md'), const TextDocument(text: 'c'));
      await fs.writeText(VaultPath('A.md'), const TextDocument(text: 'A'));

      final full = await fs.list(recursive: true);
      final paths = full.map((e) => e.path.value).toList();
      expect(paths, equals(['A.md', 'a', 'a/c.md', 'b.md']));

      final rootOnly = await fs.list(recursive: false);
      final rootPaths = rootOnly.map((e) => e.path.value).toList();
      expect(rootPaths, containsAll(['A.md', 'a', 'b.md']));
      expect(rootPaths, isNot(contains('a/c.md')));
    });

    test('5. list hides ignored paths', () async {
      await fs.writeText(
        VaultPath('.obsidian/app.json'),
        const TextDocument(text: '{}'),
      );
      await fs.writeText(
        VaultPath('.trash/x.md'),
        const TextDocument(text: 'trash'),
      );
      await fs.writeText(
        VaultPath('.hidden/h.md'),
        const TextDocument(text: 'hidden'),
      );
      await fs.writeText(
        VaultPath('visible.md'),
        const TextDocument(text: 'visible'),
      );

      final listing = await fs.list(recursive: true);
      final listPaths = listing.map((e) => e.path.value).toList();
      expect(listPaths, equals(['visible.md']));

      expect(await fs.stat(VaultPath('.obsidian/app.json')), isNotNull);
    });

    test('6. move file', () async {
      final src = VaultPath('a.md');
      final dest = VaultPath('Sub/b.md');
      await fs.writeText(src, const TextDocument(text: 'content'));
      await fs.move(src, dest);

      expect(await fs.stat(src), isNull);
      final read = await fs.readText(dest);
      expect(read.text, equals('content'));
    });

    test('7. move conflict', () async {
      final p1 = VaultPath('a.md');
      final p2 = VaultPath('b.md');
      await fs.writeText(p1, const TextDocument(text: 'one'));
      await fs.writeText(p2, const TextDocument(text: 'two'));

      expect(() => fs.move(p1, p2), throwsA(isA<FileConflictException>()));
      expect((await fs.readText(p1)).text, equals('one'));
      expect((await fs.readText(p2)).text, equals('two'));
    });

    test('8. move folder', () async {
      await fs.writeText(VaultPath('d/x.md'), const TextDocument(text: 'x'));
      await fs.writeText(VaultPath('d/e/y.md'), const TextDocument(text: 'y'));

      await fs.move(VaultPath('d'), VaultPath('d2'));

      expect(await fs.stat(VaultPath('d')), isNull);
      expect(await fs.stat(VaultPath('d/x.md')), isNull);
      expect(await fs.stat(VaultPath('d/e/y.md')), isNull);

      expect((await fs.readText(VaultPath('d2/x.md'))).text, equals('x'));
      expect((await fs.readText(VaultPath('d2/e/y.md'))).text, equals('y'));
    });

    test('9. move missing source throws FileNotFoundException', () async {
      expect(
        () => fs.move(VaultPath('missing.md'), VaultPath('dest.md')),
        throwsA(isA<FileNotFoundException>()),
      );
    });

    test('10. delete vaultTrash', () async {
      final src = VaultPath('Folder/n.md');
      await fs.writeText(src, const TextDocument(text: 'delete me'));
      await fs.delete(src, mode: TrashMode.vaultTrash);

      expect(await fs.stat(src), isNull);
      expect(await fs.stat(VaultPath('.trash/Folder/n.md')), isNotNull);
      expect(
        (await fs.readText(VaultPath('.trash/Folder/n.md'))).text,
        equals('delete me'),
      );
    });

    test('11. delete vaultTrash collision', () async {
      final src = VaultPath('n.md');
      await fs.writeText(src, const TextDocument(text: 'v1'));
      await fs.delete(src, mode: TrashMode.vaultTrash);
      expect(await fs.stat(VaultPath('.trash/n.md')), isNotNull);

      await fs.writeText(src, const TextDocument(text: 'v2'));
      await fs.delete(src, mode: TrashMode.vaultTrash);
      expect(await fs.stat(VaultPath('.trash/n 1.md')), isNotNull);

      await fs.writeText(src, const TextDocument(text: 'v3'));
      await fs.delete(src, mode: TrashMode.vaultTrash);
      expect(await fs.stat(VaultPath('.trash/n 2.md')), isNotNull);
    });

    test('12. delete permanent', () async {
      final src = VaultPath('n.md');
      await fs.writeText(src, const TextDocument(text: 'perm'));
      await fs.delete(src, mode: TrashMode.permanent);

      expect(await fs.stat(src), isNull);
      expect(await fs.stat(VaultPath('.trash')), isNull);
    });

    test('13. delete folder vaultTrash keeps structure', () async {
      await fs.writeText(VaultPath('d/e/y.md'), const TextDocument(text: 'y'));
      await fs.delete(VaultPath('d'), mode: TrashMode.vaultTrash);

      expect(await fs.stat(VaultPath('d')), isNull);
      expect(await fs.stat(VaultPath('.trash/d/e/y.md')), isNotNull);
    });

    test('14. delete missing is no-op', () async {
      await fs.delete(VaultPath('missing.md'), mode: TrashMode.permanent);
      await fs.delete(VaultPath('missing.md'), mode: TrashMode.vaultTrash);
    });

    test('15. delete system falls back to vault trash when no SystemTrash is provided', () async {
      final src = VaultPath('sys.md');
      await fs.writeText(src, const TextDocument(text: 'sys'));
      await fs.delete(src, mode: TrashMode.system);

      expect(await fs.stat(src), isNull);
      expect(await fs.stat(VaultPath('.trash/sys.md')), isNotNull);
    });

    test('16. writeText refuses malformed documents', () async {
      final file = VaultPath('valid.md');
      await fs.writeText(file, const TextDocument(text: 'original'));

      expect(
        () => fs.writeText(
          file,
          const TextDocument(text: 'bad', malformed: true),
        ),
        throwsA(isA<PermissionDeniedException>()),
      );
      expect((await fs.readText(file)).text, equals('original'));
    });

    test('17. write over folder throws FileConflictException', () async {
      final folder = VaultPath('f');
      await fs.createFolder(folder);
      expect(
        () => fs.writeText(folder, const TextDocument(text: 'hi')),
        throwsA(isA<FileConflictException>()),
      );
    });

    test('18. createFolder then stat', () async {
      final folder = VaultPath('sub/dir');
      await fs.createFolder(folder);
      final st = await fs.stat(folder);
      expect(st?.isFolder, isTrue);

      final file = VaultPath('file.md');
      await fs.writeText(file, const TextDocument(text: 'x'));
      expect(
        () => fs.createFolder(file),
        throwsA(isA<FileConflictException>()),
      );
    });

    test('19. stat reports size and modified', () async {
      final file = VaultPath('data.txt');
      final bytes = utf8.encode('1234567890');
      await fs.writeBytes(file, bytes);
      final st = await fs.stat(file);
      expect(st?.size, equals(10));
      expect(st?.isFolder, isFalse);
      expect(
        st!.modified.isAfter(
          DateTime.now().subtract(const Duration(seconds: 10)),
        ),
        isTrue,
      );
    });
  });
}
