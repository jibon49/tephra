// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_sync/tephra_sync.dart';
import 'package:tephra_vault/tephra_vault.dart';
import 'package:test/test.dart';

final class _RejectingEditorGuard implements EditorGuard {
  const _RejectingEditorGuard();

  @override
  Future<bool> mayReplace(VaultPath path, String expectedHash) async => false;
}

void main() {
  group('Executor', () {
    late MemoryVaultFileSystem fs;
    late MemorySyncProvider provider;
    late PlaintextObjectCipher cipher;
    late SyncStateStore store;
    late BlobStore blobStore;
    late JournalWriter journalWriter;
    late LocalHistory localHistory;
    late Executor executor;

    setUp(() async {
      fs = MemoryVaultFileSystem();
      provider = MemorySyncProvider();
      cipher = PlaintextObjectCipher();
      store = await SyncStateStore.openMemory();
      blobStore = BlobStore(provider: provider, cipher: cipher, store: store);
      final hlcClock = HlcClock(deviceId: 'dev1', clock: const SystemClock());
      journalWriter = JournalWriter(
        provider: provider,
        cipher: cipher,
        store: store,
        hlcClock: hlcClock,
      );
      localHistory = LocalHistory(fs);
      executor = Executor(
        fs: fs,
        store: store,
        blobStore: blobStore,
        journalWriter: journalWriter,
        deviceName: 'dev1',
        localHistory: localHistory,
      );
    });

    tearDown(() async {
      await store.close();
    });

    group('Download', () {
      test('downloads and verifies remote content', () async {
        final path = VaultPath('note.md');
        final bytes = utf8.encode('# Remote Note Content');
        final hash = contentHash(bytes);
        final blobKeys = await blobStore.putFile(bytes, plainHash: hash);

        final entry = JournalEntry(
          entryId: 'rem:1',
          deviceId: 'rem',
          seq: 1,
          hlc: const Hlc(millis: 1000, counter: 0, deviceId: 'rem').encoded,
          op: 'put',
          path: path.value,
          hash: hash,
          size: bytes.length,
          blobKeys: blobKeys,
          time: 1000,
        );

        final result = await executor.execute(Download(path, entry: entry));
        expect(result.status, ExecutionStatus.applied);
        expect(result.bytesDown, bytes.length);

        expect(await fs.readBytes(path), equals(bytes));
        final base = await store.base(path.value);
        expect(base, isNotNull);
        expect(base!.hash, hash);
        expect(base.version, 'rem:1');

        final baseText = await store.baseText(path.value);
        expect(baseText, '# Remote Note Content');
      });

      test('skips when precondition expectedLocalHash mismatches', () async {
        final path = VaultPath('note.md');
        await fs.writeBytes(path, utf8.encode('actual local'));

        final entry = JournalEntry(
          entryId: 'rem:1',
          deviceId: 'rem',
          seq: 1,
          hlc: const Hlc(millis: 1000, counter: 0, deviceId: 'rem').encoded,
          op: 'put',
          path: path.value,
          hash: 'target_hash',
          blobKeys: ['blob1'],
          time: 1000,
        );

        final result = await executor.execute(
          Download(path, entry: entry, expectedLocalHash: 'expected_different'),
        );
        expect(result.status, ExecutionStatus.skippedPrecondition);
        expect(utf8.decode(await fs.readBytes(path)), 'actual local');
      });

      test('already-applied target content only updates state', () async {
        final path = VaultPath('note.md');
        final bytes = utf8.encode('same content');
        final hash = contentHash(bytes);
        await fs.writeBytes(path, bytes);

        final entry = JournalEntry(
          entryId: 'rem:1',
          deviceId: 'rem',
          seq: 1,
          hlc: const Hlc(millis: 1000, counter: 0, deviceId: 'rem').encoded,
          op: 'put',
          path: path.value,
          hash: hash,
          blobKeys: ['blob1'],
          time: 1000,
        );

        final result = await executor.execute(Download(path, entry: entry));
        expect(result.status, ExecutionStatus.alreadyApplied);

        final base = await store.base(path.value);
        expect(base, isNotNull);
        expect(base!.version, 'rem:1');
      });

      test('EditorGuard returning false skips the overwrite', () async {
        final path = VaultPath('note.md');
        final localBytes = utf8.encode('local edits');
        await fs.writeBytes(path, localBytes);
        final localHash = contentHash(localBytes);

        final remoteBytes = utf8.encode('remote changes');
        final remoteHash = contentHash(remoteBytes);
        final blobKeys = await blobStore.putFile(
          remoteBytes,
          plainHash: remoteHash,
        );

        final guardExecutor = Executor(
          fs: fs,
          store: store,
          blobStore: blobStore,
          journalWriter: journalWriter,
          deviceName: 'dev1',
          editorGuard: const _RejectingEditorGuard(),
        );

        final entry = JournalEntry(
          entryId: 'rem:1',
          deviceId: 'rem',
          seq: 1,
          hlc: const Hlc(millis: 1000, counter: 0, deviceId: 'rem').encoded,
          op: 'put',
          path: path.value,
          hash: remoteHash,
          blobKeys: blobKeys,
          time: 1000,
        );

        final result = await guardExecutor.execute(
          Download(path, entry: entry, expectedLocalHash: localHash),
        );
        expect(result.status, ExecutionStatus.skippedEditorGuard);
        expect(await fs.readBytes(path), equals(localBytes));
      });

      test('history snapshot is written before every text overwrite', () async {
        final path = VaultPath('note.md');
        final originalBytes = utf8.encode('original content');
        await fs.writeBytes(path, originalBytes);
        final originalHash = contentHash(originalBytes);

        final newBytes = utf8.encode('overwritten remote content');
        final newHash = contentHash(newBytes);
        final blobKeys = await blobStore.putFile(newBytes, plainHash: newHash);

        final entry = JournalEntry(
          entryId: 'rem:1',
          deviceId: 'rem',
          seq: 1,
          hlc: const Hlc(millis: 1000, counter: 0, deviceId: 'rem').encoded,
          op: 'put',
          path: path.value,
          hash: newHash,
          blobKeys: blobKeys,
          time: 1000,
        );

        final result = await executor.execute(
          Download(path, entry: entry, expectedLocalHash: originalHash),
        );
        expect(result.status, ExecutionStatus.applied);

        final snapshots = await localHistory.list(path);
        expect(snapshots, isNotEmpty);
        final restored = await localHistory.read(snapshots.first);
        expect(restored, equals(originalBytes));
      });
    });

    group('DeleteLocal', () {
      test('deletes local file to vault trash and removes base', () async {
        final path = VaultPath('delete_me.md');
        final bytes = utf8.encode('delete me');
        final hash = contentHash(bytes);
        await fs.writeBytes(path, bytes);

        await store.putBase(
          BaseState(
            path: path.value,
            caseKey: path.caseKey,
            hash: hash,
            size: bytes.length,
            mtime: 1000,
            version: 'rem:1',
            blobKeys: const [],
            syncedAt: 1000,
          ),
        );

        final result = await executor.execute(
          DeleteLocal(path, expectedHash: hash, remoteEntryId: 'rem:2'),
        );
        expect(result.status, ExecutionStatus.applied);
        expect(await fs.stat(path), isNull);
        expect(await store.base(path.value), isNull);
      });

      test('skips if expectedHash does not match current local file', () async {
        final path = VaultPath('keep_me.md');
        await fs.writeBytes(path, utf8.encode('modified user edit'));

        final result = await executor.execute(
          DeleteLocal(
            path,
            expectedHash: 'unmodified_hash',
            remoteEntryId: 'rem:2',
          ),
        );
        expect(result.status, ExecutionStatus.skippedPrecondition);
        expect(await fs.stat(path), isNotNull);
      });

      test('already-applied absent file only updates base state', () async {
        final path = VaultPath('missing.md');
        await store.putBase(
          BaseState(
            path: path.value,
            caseKey: path.caseKey,
            hash: 'h',
            size: 0,
            mtime: 0,
            version: 'v',
            blobKeys: const [],
            syncedAt: 0,
          ),
        );

        final result = await executor.execute(
          DeleteLocal(path, expectedHash: 'h', remoteEntryId: 'rem:2'),
        );
        expect(result.status, ExecutionStatus.alreadyApplied);
        expect(await store.base(path.value), isNull);
      });
    });

    group('RenameLocal', () {
      test('renames local file and moves base state', () async {
        final from = VaultPath('old.md');
        final to = VaultPath('new.md');
        final bytes = utf8.encode('moving note');
        final hash = contentHash(bytes);
        await fs.writeBytes(from, bytes);

        await store.putBase(
          BaseState(
            path: from.value,
            caseKey: from.caseKey,
            hash: hash,
            size: bytes.length,
            mtime: 1000,
            version: 'rem:1',
            blobKeys: const [],
            syncedAt: 1000,
          ),
        );

        final result = await executor.execute(
          RenameLocal(from, to: to, expectedHash: hash, remoteEntryId: 'rem:2'),
        );
        expect(result.status, ExecutionStatus.applied);
        expect(await fs.stat(from), isNull);
        expect(await fs.stat(to), isNotNull);
        expect(await store.base(from.value), isNull);
        final newBase = await store.base(to.value);
        expect(newBase, isNotNull);
        expect(newBase!.path, to.value);
      });

      test(
        'case-only rename succeeds on case-insensitive filesystem',
        () async {
          final caseFs = MemoryVaultFileSystem(caseInsensitive: true);
          final caseExecutor = Executor(
            fs: caseFs,
            store: store,
            blobStore: blobStore,
            journalWriter: journalWriter,
            deviceName: 'dev1',
            caseInsensitive: true,
          );

          final from = VaultPath('test.md');
          final to = VaultPath('TEST.md');
          final bytes = utf8.encode('case content');
          final hash = contentHash(bytes);
          await caseFs.writeBytes(from, bytes);

          final result = await caseExecutor.execute(
            RenameLocal(
              from,
              to: to,
              expectedHash: hash,
              remoteEntryId: 'rem:2',
            ),
          );
          expect(result.status, ExecutionStatus.applied);
          expect(await caseFs.stat(to), isNotNull);
        },
      );
    });

    group('Merge and ConflictCopy', () {
      test('Merge applies clean merge and stages upload', () async {
        final path = VaultPath('merge.md');
        final baseText = 'line1\nline2\nline3\nline4\nline5\n';
        final localText = 'line1\nline2\nline3\nline4 local\nline5\n';
        final remoteText = 'line1 remote\nline2\nline3\nline4\nline5\n';

        await fs.writeBytes(path, utf8.encode(localText));
        final localHash = contentHash(utf8.encode(localText));

        final remoteBytes = utf8.encode(remoteText);
        final remoteHash = contentHash(remoteBytes);
        final blobKeys = await blobStore.putFile(
          remoteBytes,
          plainHash: remoteHash,
        );

        await store.putBaseText(path.value, 'base_hash', baseText);

        final remote = JournalEntry(
          entryId: 'rem:1',
          deviceId: 'rem',
          seq: 1,
          hlc: const Hlc(millis: 1000, counter: 0, deviceId: 'rem').encoded,
          op: 'put',
          path: path.value,
          hash: remoteHash,
          blobKeys: blobKeys,
          time: 1000,
        );

        final result = await executor.execute(
          Merge(
            path,
            kind: MergeKind.markdown,
            localHash: localHash,
            remote: remote,
            basePath: path,
          ),
        );

        expect(result.status, ExecutionStatus.applied);
        expect(result.stagedUploads, hasLength(1));

        final onDisk = utf8.decode(await fs.readBytes(path));
        expect(onDisk, 'line1 remote\nline2\nline3\nline4 local\nline5\n');
      });

      test(
        'ConflictCopy reuses an existing identical copy after a crash',
        () async {
          final path = VaultPath('conflict.md');
          final localBytes = utf8.encode('local conflicting text');
          final localHash = contentHash(localBytes);
          await fs.writeBytes(path, localBytes);

          // Pre-create a conflict copy as if a previous run crashed after creating it
          final existingCopy = VaultPath(
            'conflict (conflict 2026-10-19 dev1).md',
          );
          await fs.writeBytes(existingCopy, localBytes);

          final remoteBytes = utf8.encode('remote conflicting text');
          final remoteHash = contentHash(remoteBytes);
          final blobKeys = await blobStore.putFile(
            remoteBytes,
            plainHash: remoteHash,
          );

          final remote = JournalEntry(
            entryId: 'rem:1',
            deviceId: 'rem',
            seq: 1,
            hlc: const Hlc(millis: 1000, counter: 0, deviceId: 'rem').encoded,
            op: 'put',
            path: path.value,
            hash: remoteHash,
            blobKeys: blobKeys,
            time: 1000,
          );

          final result = await executor.execute(
            ConflictCopy(path, localHash: localHash, remote: remote),
          );

          expect(result.status, ExecutionStatus.applied);
          // Target path now has remote content
          expect(await fs.readBytes(path), equals(remoteBytes));

          // List folder entries: should NOT have created an extra "conflict (... 2).md"
          final list = await fs.list();
          final conflictFiles = list
              .where((e) => e.path.name.contains('conflict (conflict'))
              .toList();
          expect(conflictFiles, hasLength(1));
          expect(conflictFiles.first.path.value, existingCopy.value);

          final conflicts = await store.conflicts();
          expect(conflicts, hasLength(1));
          expect(conflicts.first.copyPath, existingCopy.value);
        },
      );
    });

    group('Upload, RenameRemote, DeleteRemote', () {
      test('Upload stages put entry with uploaded blobs', () async {
        final path = VaultPath('upload_me.md');
        final bytes = utf8.encode('content to upload');
        final hash = contentHash(bytes);
        await fs.writeBytes(path, bytes);

        final result = await executor.execute(Upload(path, localHash: hash));
        expect(result.status, ExecutionStatus.applied);
        expect(result.bytesUp, bytes.length);

        expect(journalWriter.staged, hasLength(1));
        final staged = journalWriter.staged.first;
        expect(staged.op, 'put');
        expect(staged.path, path.value);
        expect(staged.hash, hash);
      });

      test('RenameRemote stages move entry', () async {
        final from = VaultPath('a.md');
        final to = VaultPath('b.md');

        final result = await executor.execute(
          RenameRemote(
            from,
            to: to,
            parent: 'rem:1',
            hash: 'hash',
            blobKeys: const ['b1'],
          ),
        );

        expect(result.status, ExecutionStatus.applied);
        expect(journalWriter.staged, hasLength(1));
        final staged = journalWriter.staged.first;
        expect(staged.op, 'move');
        expect(staged.path, to.value);
        expect(staged.fromPath, from.value);
      });

      test('DeleteRemote stages delete entry', () async {
        final path = VaultPath('del.md');
        final result = await executor.execute(
          DeleteRemote(path, parent: 'rem:1', hash: 'h', blobKeys: const []),
        );

        expect(result.status, ExecutionStatus.applied);
        expect(journalWriter.staged, hasLength(1));
        final staged = journalWriter.staged.first;
        expect(staged.op, 'delete');
        expect(staged.path, path.value);
      });
    });
  });
}
