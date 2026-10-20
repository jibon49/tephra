// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:math';

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_sync/tephra_sync.dart';
import 'package:test/test.dart';

class FakeClock implements Clock {
  FakeClock(this._now);
  DateTime _now;

  @override
  DateTime now() => _now;

  void step(Duration d) => _now = _now.add(d);
}

void main() {
  late MemorySyncProvider provider;
  late SyncStateStore store;
  late PlaintextObjectCipher cipher;
  late FakeClock clock;
  late BackupVerifier verifier;

  setUp(() async {
    clock = FakeClock(DateTime.utc(2026, 10, 20, 12, 0, 0));
    provider = MemorySyncProvider(clock: clock);
    store = await SyncStateStore.openMemory();
    cipher = PlaintextObjectCipher();
    verifier = BackupVerifier(
      provider: provider,
      cipher: cipher,
      store: store,
      random: Random(42),
      clock: clock,
    );
  });

  tearDown(() async {
    await store.close();
  });

  group('BackupVerifier', () {
    test(
      'all-good verification succeeds and stores verification row',
      () async {
        // Create 25 blobs and files
        final files = <BackupManifestFile>[];
        for (var i = 0; i < 25; i++) {
          final content = utf8.encode('Content for file $i');
          final plainHash = contentHash(content);
          final sealed = await cipher.seal(content, ObjectPurpose.blob);
          final blobKey = RemoteLayout.blob(plainHash);

          await provider.put(blobKey, sealed);
          files.add(
            BackupManifestFile(
              path: 'file_$i.md',
              hash: plainHash,
              size: content.length,
              mtime: clock.now().millisecondsSinceEpoch,
              blobKeys: [blobKey],
            ),
          );
        }

        final manifest = BackupManifest(
          vaultId: 'vault-1',
          createdAt: clock.now(),
          deviceId: 'dev-1',
          deviceName: 'Device 1',
          kind: BackupKind.manual,
          fileCount: files.length,
          totalBytes: files.fold(0, (sum, f) => sum + f.size),
          files: files,
        );

        final manifestKey = RemoteLayout.backupManifest(clock.now());
        await provider.put(manifestKey, await manifest.seal(cipher));

        // Run verification
        final record = await verifier.verify();

        // Sampled should be 20 (min sample size is 20)
        expect(record.sampled, 20);
        expect(record.ok, 20);
        expect(record.failed, 0);
        expect(record.failedKeys, isEmpty);
        expect(record.stamp, manifest.stamp);

        // Verify row in SQLite store
        final verifications = await store.verificationsForStamp(manifest.stamp);
        expect(verifications.length, 1);
        expect(verifications.first.ok, 20);
        expect(verifications.first.failed, 0);
      },
    );

    test(
      'corrupted blob records failure and failed keys without deleting',
      () async {
        final contentA = utf8.encode('file A content');
        final hashA = contentHash(contentA);
        final blobKeyA = RemoteLayout.blob(hashA);
        await provider.put(
          blobKeyA,
          await cipher.seal(contentA, ObjectPurpose.blob),
        );

        final contentB = utf8.encode('file B content');
        final hashB = contentHash(contentB);
        final blobKeyB = RemoteLayout.blob(hashB);
        // Corrupted blob content
        await provider.put(
          blobKeyB,
          utf8.encode('corrupted bytes that fail hash or decrypt'),
        );

        final manifest = BackupManifest(
          vaultId: 'vault-1',
          createdAt: clock.now(),
          deviceId: 'dev-1',
          deviceName: 'Device 1',
          kind: BackupKind.manual,
          fileCount: 2,
          totalBytes: contentA.length + contentB.length,
          files: [
            BackupManifestFile(
              path: 'a.md',
              hash: hashA,
              size: contentA.length,
              mtime: 1000,
              blobKeys: [blobKeyA],
            ),
            BackupManifestFile(
              path: 'b.md',
              hash: hashB,
              size: contentB.length,
              mtime: 1000,
              blobKeys: [blobKeyB],
            ),
          ],
        );

        await provider.put(
          RemoteLayout.backupManifest(clock.now()),
          await manifest.seal(cipher),
        );

        final record = await verifier.verify(stamp: manifest.stamp);

        expect(record.sampled, 2);
        expect(record.ok, 1);
        expect(record.failed, 1);
        expect(record.failedKeys, [blobKeyB]);

        // Ensure provider still has both blobs (nothing was deleted)
        expect(await provider.get(blobKeyA), isNotNull);
        expect(await provider.get(blobKeyB), isNotNull);
      },
    );
  });
}
