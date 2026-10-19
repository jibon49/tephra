// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_sync/tephra_sync.dart';
import 'package:tephra_vault/tephra_vault.dart';
import 'package:test/test.dart';

final class _CountingVaultFileSystem implements VaultFileSystem {
  _CountingVaultFileSystem(this.inner);

  final MemoryVaultFileSystem inner;
  int readBytesCount = 0;

  @override
  String get rootDisplayPath => inner.rootDisplayPath;

  @override
  Future<List<VaultEntry>> list({
    VaultPath folder = VaultPath.root,
    bool recursive = true,
  }) => inner.list(folder: folder, recursive: recursive);

  @override
  Future<VaultEntry?> stat(VaultPath path) => inner.stat(path);

  @override
  Future<List<int>> readBytes(VaultPath path) {
    readBytesCount++;
    return inner.readBytes(path);
  }

  @override
  Future<TextDocument> readText(VaultPath path) => inner.readText(path);

  @override
  Future<void> writeBytes(VaultPath path, List<int> bytes) =>
      inner.writeBytes(path, bytes);

  @override
  Future<void> writeText(VaultPath path, TextDocument doc) =>
      inner.writeText(path, doc);

  @override
  Future<void> createFolder(VaultPath path) => inner.createFolder(path);

  @override
  Future<void> move(VaultPath from, VaultPath to) => inner.move(from, to);

  @override
  Future<void> delete(
    VaultPath path, {
    TrashMode mode = TrashMode.vaultTrash,
  }) => inner.delete(path, mode: mode);

  @override
  Stream<VaultChange> watch() => inner.watch();

  @override
  Future<void> dispose() => inner.dispose();
}

final class _FailingStatFileSystem extends _CountingVaultFileSystem {
  _FailingStatFileSystem(super.inner);

  @override
  Future<VaultEntry?> stat(VaultPath path) async {
    if (path.isRoot) throw Exception('Simulated I/O failure on root stat');
    return super.stat(path);
  }
}

final class _MissingRootFileSystem extends _CountingVaultFileSystem {
  _MissingRootFileSystem(super.inner);

  @override
  Future<VaultEntry?> stat(VaultPath path) async {
    if (path.isRoot) return null;
    return super.stat(path);
  }
}

final class _FailingListFileSystem extends _CountingVaultFileSystem {
  _FailingListFileSystem(super.inner);

  @override
  Future<List<VaultEntry>> list({
    VaultPath folder = VaultPath.root,
    bool recursive = true,
  }) async {
    throw Exception('Simulated I/O failure on root list');
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('LocalScanner', () {
    late MemoryVaultFileSystem rawFs;
    late _CountingVaultFileSystem fs;
    late SyncStateStore store;
    late LocalScanner scanner;

    setUp(() async {
      rawFs = MemoryVaultFileSystem();
      fs = _CountingVaultFileSystem(rawFs);
      store = await SyncStateStore.openMemory();
      scanner = LocalScanner(fs: fs, store: store);
    });

    tearDown(() async {
      await store.close();
      await fs.dispose();
    });

    test('empty vault folder returns empty map', () async {
      final result = await scanner.scan(const SelectiveSyncRules());
      expect(result, isEmpty);
      expect(fs.readBytesCount, equals(0));
    });

    test('participating files are scanned and hashed', () async {
      fs.inner.putText('notes/idea.md', '# Idea\nContent');
      fs.inner.putText('notes/daily.md', '# Daily\nLog');
      fs.inner.putText('.tephra/settings.json', '{"theme": "dark"}');

      final result = await scanner.scan(const SelectiveSyncRules());
      expect(result.length, equals(3));

      final ideaState = result[VaultPath('notes/idea.md')];
      expect(ideaState, isNotNull);
      expect(ideaState!.path.value, equals('notes/idea.md'));
      expect(
        ideaState.hash,
        equals(contentHash(utf8.encode('# Idea\nContent'))),
      );
      expect(ideaState.size, equals(utf8.encode('# Idea\nContent').length));

      final dailyState = result[VaultPath('notes/daily.md')];
      expect(dailyState, isNotNull);
      expect(
        dailyState!.hash,
        equals(contentHash(utf8.encode('# Daily\nLog'))),
      );

      final settingsState = result[VaultPath('.tephra/settings.json')];
      expect(settingsState, isNotNull);
      expect(
        settingsState!.hash,
        equals(contentHash(utf8.encode('{"theme": "dark"}'))),
      );

      expect(fs.readBytesCount, equals(3));
    });

    test('excluded and non-participating paths are absent from scan', () async {
      // Allowed file
      fs.inner.putText('doc.md', 'regular doc');

      // Ignored paths
      fs.inner.putText('.obsidian/app.json', '{}');
      fs.inner.putText('.git/config', 'gitconfig');
      fs.inner.putText('node_modules/pkg/index.js', 'js');
      fs.inner.putText('.tephra/vault.json', 'header');
      fs.inner.putText('.tephra/cache/probe.tmp', 'probe');
      fs.inner.putText('.hidden_folder/secret.txt', 'secret');
      fs.inner.putText('notes/.hidden.md', 'hidden');
      fs.inner.putText('temp.md.tephra-tmp', 'temp');
      fs.inner.putText('conflict.tephra-case-probe.md', 'case-tmp');
      fs.inner.putText('archive/old.md', 'old');

      const rules = SelectiveSyncRules(excludedFolders: ['archive']);

      final result = await scanner.scan(rules);
      expect(result.keys.map((p) => p.value).toList(), equals(['doc.md']));
      expect(fs.readBytesCount, equals(1));
    });

    test('scan uses the hash cache on unchanged files', () async {
      fs.inner.putText('a.md', 'content a');
      fs.inner.putText('b.md', 'content b');
      fs.inner.putText('c.md', 'content c');

      // Initial scan hashes all 3 files
      final result1 = await scanner.scan(const SelectiveSyncRules());
      expect(result1.length, equals(3));
      expect(fs.readBytesCount, equals(3));

      // Second scan uses cached hashes without reading file bytes
      final result2 = await scanner.scan(const SelectiveSyncRules());
      expect(result2.length, equals(3));
      expect(fs.readBytesCount, equals(3)); // unchanged!

      // Modify only one file
      fs.inner.putText('b.md', 'content b updated');

      final result3 = await scanner.scan(const SelectiveSyncRules());
      expect(result3.length, equals(3));
      expect(fs.readBytesCount, equals(4)); // only b.md was re-read!
      expect(
        result3[VaultPath('b.md')]!.hash,
        equals(contentHash(utf8.encode('content b updated'))),
      );
    });

    test('throws VaultFolderUnavailableException when root stat throws or is missing', () async {
      final failingFs = _FailingStatFileSystem(rawFs);
      final failingScanner = LocalScanner(fs: failingFs, store: store);
      await expectLater(
        failingScanner.scan(const SelectiveSyncRules()),
        throwsA(isA<VaultFolderUnavailableException>()),
      );

      final missingFs = _MissingRootFileSystem(rawFs);
      final missingScanner = LocalScanner(fs: missingFs, store: store);
      await expectLater(
        missingScanner.scan(const SelectiveSyncRules()),
        throwsA(isA<VaultFolderUnavailableException>()),
      );
    });

    test('throws VaultFolderUnavailableException when list throws', () async {
      final failingListFs = _FailingListFileSystem(rawFs);
      final failingScanner = LocalScanner(fs: failingListFs, store: store);
      await expectLater(
        failingScanner.scan(const SelectiveSyncRules()),
        throwsA(isA<VaultFolderUnavailableException>()),
      );
    });

    test('hashes files concurrently with max concurrency 4', () async {
      // Populate 10 files
      for (var i = 0; i < 10; i++) {
        fs.inner.putText('file_$i.md', 'content of file $i');
      }

      final result = await scanner.scan(const SelectiveSyncRules());
      expect(result.length, equals(10));
      expect(fs.readBytesCount, equals(10));
    });
  });
}
