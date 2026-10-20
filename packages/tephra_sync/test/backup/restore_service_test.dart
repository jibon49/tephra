// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_sync/tephra_sync.dart';
import 'package:tephra_vault/tephra_vault.dart';
import 'package:test/test.dart';

class FakeClock implements Clock {
  FakeClock(this._now);
  DateTime _now;

  @override
  DateTime now() => _now;

  void step(Duration d) => _now = _now.add(d);
}

void main() {
  late MemoryVaultFileSystem fs;
  late MemorySyncProvider provider;
  late SyncStateStore store;
  late PlaintextObjectCipher cipher;
  late BlobStore blobStore;
  late FakeClock clock;
  late BackupService backupService;
  late RestoreService restoreService;

  setUp(() async {
    fs = MemoryVaultFileSystem();
    clock = FakeClock(DateTime.utc(2026, 10, 20, 12, 0, 0));
    provider = MemorySyncProvider(clock: clock);
    store = await SyncStateStore.openMemory();
    cipher = PlaintextObjectCipher();
    blobStore = BlobStore(
      provider: provider,
      cipher: cipher,
      store: store,
      clock: clock,
    );
    backupService = BackupService(
      vaultId: 'vault-1',
      deviceId: 'dev-1',
      deviceName: 'Device 1',
      fs: fs,
      blobStore: blobStore,
      provider: provider,
      cipher: cipher,
      store: store,
      syncLock: MemorySyncLock(),
      clock: clock,
    );

    restoreService = RestoreService(
      provider: provider,
      cipher: cipher,
      blobStore: blobStore,
      fs: fs,
      backupService: backupService,
      clock: clock,
    );
  });

  tearDown(() async {
    await store.close();
  });

  group('RestoreService intoVault', () {
    test(
      'handles absent, identical, and modified files with collision naming',
      () async {
        // Upload 3 blobs for 3 notes:
        // note1: absent locally -> restored
        // note2: identical locally -> skipped
        // note3: modified locally -> renamed to collision name
        final content1 = utf8.encode('Note 1 backup content');
        final hash1 = contentHash(content1);
        final blobKey1 = RemoteLayout.blob(hash1);
        await provider.put(
          blobKey1,
          await cipher.seal(content1, ObjectPurpose.blob),
        );

        final content2 = utf8.encode('Note 2 identical content');
        final hash2 = contentHash(content2);
        final blobKey2 = RemoteLayout.blob(hash2);
        await provider.put(
          blobKey2,
          await cipher.seal(content2, ObjectPurpose.blob),
        );
        // Write note2 locally with identical content
        await fs.writeBytes(VaultPath('note2.md'), content2);

        final content3Backup = utf8.encode('Note 3 original backup content');
        final hash3Backup = contentHash(content3Backup);
        final blobKey3 = RemoteLayout.blob(hash3Backup);
        await provider.put(
          blobKey3,
          await cipher.seal(content3Backup, ObjectPurpose.blob),
        );
        // Write note3 locally with different content
        await fs.writeBytes(
          VaultPath('note3.md'),
          utf8.encode('Note 3 local modifications'),
        );

        final initialTime = DateTime.utc(2026, 10, 20, 10, 0, 0);
        final manifest = BackupManifest(
          vaultId: 'vault-1',
          createdAt: initialTime,
          deviceId: 'dev-1',
          deviceName: 'Device 1',
          kind: BackupKind.manual,
          fileCount: 3,
          totalBytes: content1.length + content2.length + content3Backup.length,
          files: [
            BackupManifestFile(
              path: 'note1.md',
              hash: hash1,
              size: content1.length,
              mtime: 1000,
              blobKeys: [blobKey1],
            ),
            BackupManifestFile(
              path: 'note2.md',
              hash: hash2,
              size: content2.length,
              mtime: 1000,
              blobKeys: [blobKey2],
            ),
            BackupManifestFile(
              path: 'note3.md',
              hash: hash3Backup,
              size: content3Backup.length,
              mtime: 1000,
              blobKeys: [blobKey3],
            ),
          ],
        );

        await provider.put(
          RemoteLayout.backupManifest(initialTime),
          await manifest.seal(cipher),
        );

        // Advance clock to 12:00 for the restore run
        clock._now = DateTime.utc(2026, 10, 20, 12, 0, 0);

        final progressUpdates = <(int, int)>[];
        final report = await restoreService.restore(
          RestoreRequest(
            stamp: manifest.stamp,
            target: RestoreTarget.intoVault,
          ),
          onProgress: (done, total) => progressUpdates.add((done, total)),
        );

        expect(report.restoredCount, 1);
        expect(report.skippedCount, 1);
        expect(report.renamedCount, 1);
        expect(report.failedCount, 0);

        // Check whole-vault preRestore trigger created a preRestore backup
        final allBackups = await provider.list(RemoteLayout.backupsPrefix);
        final manifestObjects = allBackups
            .where((o) => o.key.endsWith('/manifest.json.enc'))
            .toList();
        expect(manifestObjects.length, 2);

        final latestBytes = await provider.get(manifestObjects.last.key);
        final preRestoreManifest = await BackupManifest.open(
          latestBytes,
          cipher,
        );
        expect(preRestoreManifest.kind, BackupKind.preRestore);

        // note1.md was written
        expect(await fs.readBytes(VaultPath('note1.md')), content1);

        // note2.md unchanged
        expect(await fs.readBytes(VaultPath('note2.md')), content2);

        // note3.md unchanged (local modifications intact)
        expect(
          await fs.readBytes(VaultPath('note3.md')),
          utf8.encode('Note 3 local modifications'),
        );

        // collision file created: note3 (restored 2026-10-20).md
        final collisionPath = VaultPath('note3 (restored 2026-10-20).md');
        expect(await fs.stat(collisionPath), isNotNull);
        expect(await fs.readBytes(collisionPath), content3Backup);

        expect(progressUpdates.isNotEmpty, isTrue);
      },
    );
  });

  group('RestoreService newFolder', () {
    test(
      'restores into fresh directory and rejects non-empty folder',
      () async {
        final tempDir = Directory.systemTemp.createTempSync('restore_test_');

        try {
          final content = utf8.encode('Hello in new folder');
          final hash = contentHash(content);
          final blobKey = RemoteLayout.blob(hash);
          await provider.put(
            blobKey,
            await cipher.seal(content, ObjectPurpose.blob),
          );

          final manifest = BackupManifest(
            vaultId: 'vault-1',
            createdAt: clock.now(),
            deviceId: 'dev-1',
            deviceName: 'Device 1',
            kind: BackupKind.manual,
            fileCount: 1,
            totalBytes: content.length,
            files: [
              BackupManifestFile(
                path: 'folder/hello.md',
                hash: hash,
                size: content.length,
                mtime: 1000,
                blobKeys: [blobKey],
              ),
            ],
          );

          await provider.put(
            RemoteLayout.backupManifest(clock.now()),
            await manifest.seal(cipher),
          );

          final targetPath = p.join(tempDir.path, 'fresh_subfolder');

          final report = await restoreService.restore(
            RestoreRequest(
              stamp: manifest.stamp,
              target: RestoreTarget.newFolder(targetPath),
            ),
          );

          expect(report.restoredCount, 1);
          expect(report.skippedCount, 0);
          expect(report.renamedCount, 0);

          final restoredFile = File(p.join(targetPath, 'folder', 'hello.md'));
          expect(restoredFile.existsSync(), isTrue);
          expect(restoredFile.readAsBytesSync(), content);

          // Trying to restore again into non-empty directory throws StateError
          await expectLater(
            restoreService.restore(
              RestoreRequest(
                stamp: manifest.stamp,
                target: RestoreTarget.newFolder(targetPath),
              ),
            ),
            throwsA(isA<StateError>()),
          );
        } finally {
          if (tempDir.existsSync()) {
            tempDir.deleteSync(recursive: true);
          }
        }
      },
    );
  });
}
