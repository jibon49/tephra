// © 2026 Tephra. All rights reserved.

import 'dart:convert';

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

/// Delegating [SyncProvider] that tracks put counts by key prefix.
class _TrackingSyncProvider implements SyncProvider {
  _TrackingSyncProvider() : _inner = MemorySyncProvider();

  final MemorySyncProvider _inner;

  int blobPuts = 0;
  int manifestPuts = 0;
  bool failNextManifest = false;

  @override
  String get id => _inner.id;

  @override
  Future<void> connect() => _inner.connect();

  @override
  Future<void> put(String key, List<int> bytes) async {
    if (key.startsWith('blobs/')) {
      blobPuts++;
    } else if (key.startsWith('backups/')) {
      if (failNextManifest) {
        failNextManifest = false;
        throw StateError('Simulated crash writing manifest');
      }
      manifestPuts++;
    }
    return _inner.put(key, bytes);
  }

  @override
  Future<List<int>> get(String key) => _inner.get(key);

  @override
  Future<void> delete(String key) => _inner.delete(key);

  @override
  Future<List<RemoteObject>> list(String prefix) => _inner.list(prefix);

  @override
  Future<RemoteChanges> changesSince(String? cursor) =>
      _inner.changesSince(cursor);

  @override
  Future<Quota?> quota() => _inner.quota();
}

void main() {
  late MemoryVaultFileSystem fs;
  late _TrackingSyncProvider provider;
  late SyncStateStore store;
  late BlobStore blobStore;
  late PlaintextObjectCipher cipher;
  late MemorySyncLock syncLock;
  late FakeClock clock;
  late BackupService service;

  setUp(() async {
    fs = MemoryVaultFileSystem();
    provider = _TrackingSyncProvider();
    store = await SyncStateStore.openMemory();
    cipher = PlaintextObjectCipher();
    clock = FakeClock(DateTime.utc(2026, 10, 20, 10, 0, 0));
    blobStore = BlobStore(
      provider: provider,
      cipher: cipher,
      store: store,
      clock: clock,
    );
    syncLock = MemorySyncLock();

    service = BackupService(
      vaultId: 'vault-test',
      deviceId: 'dev-win',
      deviceName: 'Windows PC',
      fs: fs,
      blobStore: blobStore,
      provider: provider,
      cipher: cipher,
      store: store,
      syncLock: syncLock,
      clock: clock,
    );
  });

  tearDown(() async {
    await store.close();
  });

  group('BackupService', () {
    test(
      'second backup of unchanged 1,000-file vault uploads zero blobs',
      () async {
        // 1. Create 1,000 files in fs
        for (var i = 0; i < 1000; i++) {
          final path = VaultPath('folder_${i % 10}/note_$i.md');
          await fs.writeBytes(
            path,
            utf8.encode('Content of note $i with some padding text.'),
          );
        }

        // 2. First backup run
        final firstResult = await service.runBackup(kind: BackupKind.manual);
        expect(firstResult.manifest.fileCount, equals(1000));
        expect(provider.manifestPuts, equals(1));
        final initialBlobPuts = provider.blobPuts;
        expect(initialBlobPuts, equals(1000)); // 1 chunk per small file

        // 3. Second backup run without any file changes
        clock.step(const Duration(hours: 1));
        provider.blobPuts = 0;
        provider.manifestPuts = 0;

        final secondResult = await service.runBackup(
          kind: BackupKind.scheduled,
        );
        expect(secondResult.manifest.fileCount, equals(1000));
        expect(provider.manifestPuts, equals(1));
        // Zero blobs uploaded during second unchanged backup
        expect(provider.blobPuts, equals(0));
      },
    );

    test('one changed file uploads exactly its chunks', () async {
      // Create 5 files
      for (var i = 0; i < 5; i++) {
        await fs.writeBytes(
          VaultPath('note_$i.md'),
          utf8.encode('Initial text $i'),
        );
      }

      await service.runBackup(kind: BackupKind.manual);
      expect(provider.blobPuts, equals(5));

      // Change exactly 1 file
      clock.step(const Duration(hours: 1));
      provider.blobPuts = 0;
      await fs.writeBytes(
        VaultPath('note_2.md'),
        utf8.encode('Modified text for note 2!'),
      );

      final result = await service.runBackup(kind: BackupKind.manual);
      expect(result.manifest.fileCount, equals(5));
      // Exactly 1 new blob uploaded for note_2.md
      expect(provider.blobPuts, equals(1));
    });

    test(
      'crash before manifest writes no manifest, next backup completes',
      () async {
        await fs.writeBytes(VaultPath('test.md'), utf8.encode('Hello'));

        // Inject simulated crash when writing manifest
        provider.failNextManifest = true;

        await expectLater(
          service.runBackup(kind: BackupKind.manual),
          throwsA(isA<StateError>()),
        );

        // Lock was released in finally block
        expect(syncLock.isHeld, isFalse);

        // No manifest written in provider
        final manifestsBefore = await service.listBackups();
        expect(manifestsBefore, isEmpty);

        // Next run succeeds
        clock.step(const Duration(minutes: 5));
        final nextResult = await service.runBackup(kind: BackupKind.manual);
        expect(nextResult.manifest.fileCount, equals(1));

        final manifestsAfter = await service.listBackups();
        expect(manifestsAfter.length, equals(1));
      },
    );

    test('backup-only mode never writes journals', () async {
      await fs.writeBytes(
        VaultPath('Document.md'),
        utf8.encode('Backup mode text'),
      );

      await service.runBackup(kind: BackupKind.manual);

      // Check remote provider: no journal entries ever created
      final allObjects = await provider.list('');
      final journalObjects = allObjects.where(
        (o) => o.key.startsWith('journals/'),
      );
      expect(journalObjects, isEmpty);
    });

    test('prunes older manifests according to retention', () async {
      await fs.writeBytes(VaultPath('Note.md'), utf8.encode('Content'));

      // Configure retention: keep 2 hourly, 1 daily, 1 monthly
      await store.setMeta(
        'backupRetention',
        jsonEncode(
          const BackupRetentionSettings(
            hourly: 2,
            daily: 1,
            monthly: 1,
          ).toJson(),
        ),
      );

      // Run 5 backups, each 1 hour apart
      for (var i = 0; i < 5; i++) {
        clock.step(const Duration(hours: 1));
        await service.runBackup(kind: BackupKind.scheduled);
      }

      final manifests = await service.listBackups();
      // Only 2 backups retained (the newest 2 hourly)
      expect(manifests.length, equals(2));
    });
  });
}
