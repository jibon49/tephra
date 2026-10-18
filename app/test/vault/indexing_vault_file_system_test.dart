// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/vault/indexing_vault_file_system.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

class _ThrowingFs implements VaultFileSystem {
  final _inner = MemoryVaultFileSystem();

  @override
  String get rootDisplayPath => _inner.rootDisplayPath;

  @override
  Future<List<VaultEntry>> list({
    VaultPath folder = VaultPath.root,
    bool recursive = true,
  }) => _inner.list(folder: folder, recursive: recursive);

  @override
  Future<VaultEntry?> stat(VaultPath path) => _inner.stat(path);

  @override
  Future<List<int>> readBytes(VaultPath path) => _inner.readBytes(path);

  @override
  Future<TextDocument> readText(VaultPath path) => _inner.readText(path);

  @override
  Future<void> writeBytes(VaultPath path, List<int> bytes) =>
      _inner.writeBytes(path, bytes);

  @override
  Future<void> writeText(VaultPath path, TextDocument doc) async {
    throw FileConflictException(VaultPath('err.md'));
  }

  @override
  Future<void> createFolder(VaultPath path) => _inner.createFolder(path);

  @override
  Future<void> move(VaultPath from, VaultPath to) => _inner.move(from, to);

  @override
  Future<void> delete(
    VaultPath path, {
    TrashMode mode = TrashMode.vaultTrash,
  }) => _inner.delete(path, mode: mode);

  @override
  Stream<VaultChange> watch() => _inner.watch();

  @override
  Future<void> dispose() => _inner.dispose();
}

void main() {
  group('IndexingVaultFileSystem', () {
    test(
      'writeText before attach buffers change; attach flushes in order',
      () async {
        final mem = MemoryVaultFileSystem();
        final indexingFs = IndexingVaultFileSystem(mem);

        final p1 = VaultPath('note1.md');
        final p2 = VaultPath('note2.md');
        await indexingFs.writeText(p1, const TextDocument(text: 'one'));
        await indexingFs.writeText(p2, const TextDocument(text: 'two'));

        final received = <VaultChange>[];
        indexingFs.attachIndex(received.add);

        expect(received, equals([FileModified(p1), FileModified(p2)]));
      },
    );

    test('move reports FileMoved with correct from and to', () async {
      final mem = MemoryVaultFileSystem();
      final indexingFs = IndexingVaultFileSystem(mem);

      final from = VaultPath('old.md');
      final to = VaultPath('new.md');
      await indexingFs.writeText(from, const TextDocument(text: 'hello'));

      final received = <VaultChange>[];
      indexingFs.attachIndex(received.add);

      await indexingFs.move(from, to);
      expect(received, contains(FileMoved(to, from: from)));
    });

    test('delete reports FileDeleted', () async {
      final mem = MemoryVaultFileSystem();
      final indexingFs = IndexingVaultFileSystem(mem);

      final path = VaultPath('del.md');
      await indexingFs.writeText(path, const TextDocument(text: 'del'));

      final received = <VaultChange>[];
      indexingFs.attachIndex(received.add);

      await indexingFs.delete(path);
      expect(received, contains(FileDeleted(path)));
    });

    test('failing inner writeText reports nothing', () async {
      final throwing = _ThrowingFs();
      final indexingFs = IndexingVaultFileSystem(throwing);

      final received = <VaultChange>[];
      indexingFs.attachIndex(received.add);

      final path = VaultPath('fail.md');
      expect(
        () => indexingFs.writeText(path, const TextDocument(text: 'text')),
        throwsA(isA<FileConflictException>()),
      );
      expect(received, isEmpty);
    });
  });
}
