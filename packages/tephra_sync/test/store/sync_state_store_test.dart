// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tephra_sync/tephra_sync.dart';
import 'package:test/test.dart';

void main() {
  group('SyncStateStore in-memory CRUD', () {
    late SyncStateStore store;

    setUp(() async {
      store = await SyncStateStore.openMemory();
    });

    tearDown(() async {
      await store.close();
    });

    test('meta table CRUD and initial schemaVersion', () async {
      final initialVersion = await store.getMeta('schemaVersion');
      expect(initialVersion, equals('1'));

      await store.setMeta('remoteVaultId', 'vault-xyz-123');
      await store.setMeta('mode', 'live');

      expect(await store.getMeta('remoteVaultId'), equals('vault-xyz-123'));
      expect(await store.getMeta('mode'), equals('live'));

      final all = await store.allMeta();
      expect(all['remoteVaultId'], equals('vault-xyz-123'));
      expect(all['schemaVersion'], equals('1'));

      await store.removeMeta('mode');
      expect(await store.getMeta('mode'), isNull);
    });

    test('synced_files table CRUD', () async {
      final base1 = BaseState(
        path: 'Notes/Ideas.md',
        caseKey: 'notes/ideas.md',
        hash: 'hash-abc-123',
        size: 1024,
        mtime: 1718000000000,
        version: 'device1:10',
        blobKeys: const ['b1', 'b2'],
        syncedAt: 1718000001000,
      );

      await store.putBase(base1);

      final fetched = await store.base('Notes/Ideas.md');
      expect(fetched, isNotNull);
      expect(fetched!.path, equals('Notes/Ideas.md'));
      expect(fetched.caseKey, equals('notes/ideas.md'));
      expect(fetched.hash, equals('hash-abc-123'));
      expect(fetched.size, equals(1024));
      expect(fetched.mtime, equals(1718000000000));
      expect(fetched.version, equals('device1:10'));
      expect(fetched.blobKeys, equals(['b1', 'b2']));
      expect(fetched.syncedAt, equals(1718000001000));

      final all = await store.allBases();
      expect(all.length, equals(1));
      expect(all.first.path, equals('Notes/Ideas.md'));

      // Update base
      final updated = base1.copyWith(size: 2048, hash: 'hash-def-456');
      await store.putBase(updated);
      final refetched = await store.base('Notes/Ideas.md');
      expect(refetched!.size, equals(2048));
      expect(refetched.hash, equals('hash-def-456'));

      // Remove base
      await store.removeBase('Notes/Ideas.md');
      expect(await store.base('Notes/Ideas.md'), isNull);
      expect((await store.allBases()).isEmpty, isTrue);
    });

    test(
      'bases table (base text gzip compression/normalization) CRUD',
      () async {
        const text = 'Line 1\r\nLine 2\r\nLine 3\n';
        const expectedNormalized = 'Line 1\nLine 2\nLine 3\n';
        const hash = 'hash-text-789';

        await store.putBaseText('Notes/Todo.md', hash, text);

        final retrieved = await store.baseText('Notes/Todo.md');
        expect(retrieved, equals(expectedNormalized));

        await store.removeBaseText('Notes/Todo.md');
        expect(await store.baseText('Notes/Todo.md'), isNull);
      },
    );

    test('local_hash_cache table CRUD', () async {
      await store.putCachedHash(
        'folder/note.md',
        512,
        1710000000000,
        'hash-cached-1',
      );

      final cached = await store.cachedHash(
        'folder/note.md',
        512,
        1710000000000,
      );
      expect(cached, equals('hash-cached-1'));

      // Mismatched size or mtime returns null
      expect(
        await store.cachedHash('folder/note.md', 999, 1710000000000),
        isNull,
      );
      expect(
        await store.cachedHash('folder/note.md', 512, 1710000000001),
        isNull,
      );

      await store.removeCachedHash('folder/note.md');
      expect(
        await store.cachedHash('folder/note.md', 512, 1710000000000),
        isNull,
      );
    });

    test('remote_entries table CRUD and path queries', () async {
      final entry1 = JournalEntry(
        entryId: 'devA:1',
        deviceId: 'devA',
        seq: 1,
        hlc: '2026-10-18T00:00:00.000Z_devA_0000',
        op: 'create',
        path: 'welcome.md',
        hash: 'hash-w-1',
        size: 100,
        mtime: 1719000000000,
        time: 1000,
      );

      final entry2 = JournalEntry(
        entryId: 'devA:2',
        deviceId: 'devA',
        seq: 2,
        hlc: '2026-10-18T00:01:00.000Z_devA_0000',
        op: 'rename',
        path: 'docs/welcome.md',
        fromPath: 'welcome.md',
        hash: 'hash-w-1',
        size: 100,
        mtime: 1719000000000,
        parent: 'devA:1',
        time: 2000,
      );

      await store.insertRemoteEntries([entry1, entry2]);

      final fetched1 = await store.entry('devA:1');
      expect(fetched1, isNotNull);
      expect(fetched1!.path, equals('welcome.md'));
      expect(fetched1.op, equals('create'));

      final all = await store.allEntries();
      expect(all.length, equals(2));
      expect(all.first.entryId, equals('devA:1'));
      expect(all.last.entryId, equals('devA:2'));

      // entriesForPath touches either path or fromPath
      final welcomeEntries = await store.entriesForPath('welcome.md');
      expect(welcomeEntries.length, equals(2));

      final docsEntries = await store.entriesForPath('docs/welcome.md');
      expect(docsEntries.length, equals(1));
      expect(docsEntries.first.entryId, equals('devA:2'));
    });

    test('remote_heads table CRUD', () async {
      final headsMap = {'a.md': ('devA:5', false), 'b.md': ('devB:3', true)};

      await store.replaceHeads(headsMap);

      final allHeads = await store.heads();
      expect(allHeads.length, equals(2));
      expect(allHeads['a.md'], equals(('devA:5', false)));
      expect(allHeads['b.md'], equals(('devB:3', true)));

      expect(await store.head('a.md'), equals(('devA:5', false)));
      expect(await store.head('unknown.md'), isNull);

      // Replace heads with empty map
      await store.replaceHeads({});
      expect((await store.heads()).isEmpty, isTrue);
    });

    test('journal_cursors table CRUD', () async {
      await store.setCursor(
        'dev1',
        42,
        deviceName: 'Pixel 9',
        platform: 'android',
        lastSeenAt: 1720000000000,
      );

      final c = await store.cursor('dev1');
      expect(c, isNotNull);
      expect(c!.deviceId, equals('dev1'));
      expect(c.lastSeq, equals(42));
      expect(c.deviceName, equals('Pixel 9'));
      expect(c.platform, equals('android'));
      expect(c.lastSeenAt, equals(1720000000000));
      expect(c.revokedAfterSeq, isNull);

      // Update cursor
      await store.setCursor('dev1', 43, revokedAfterSeq: 100);
      final updated = await store.cursor('dev1');
      expect(updated!.lastSeq, equals(43));
      expect(updated.revokedAfterSeq, equals(100));

      final all = await store.allCursors();
      expect(all.length, equals(1));
      expect(all.first.deviceId, equals('dev1'));
    });

    test('pending_ops table CRUD', () async {
      final id = await store.addPendingOp('journal_batch', '{"seq": 5}');
      expect(id, isPositive);

      final ops = await store.pendingOps();
      expect(ops.length, equals(1));
      expect(ops.first.id, equals(id));
      expect(ops.first.kind, equals('journal_batch'));
      expect(ops.first.payload, equals('{"seq": 5}'));
      expect(ops.first.state, equals('pending'));
      expect(ops.first.attempts, equals(0));

      await store.updatePendingOp(
        id,
        state: 'in_progress',
        attempts: 1,
        lastError: 'network timeout',
      );

      final updatedOps = await store.pendingOps();
      expect(updatedOps.first.state, equals('in_progress'));
      expect(updatedOps.first.attempts, equals(1));
      expect(updatedOps.first.lastError, equals('network timeout'));

      await store.removePendingOp(id);
      expect((await store.pendingOps()).isEmpty, isTrue);
    });

    test('remote_file_ids table CRUD', () async {
      await store.putFileId(
        'manifest.json',
        'gdrive-file-id-123',
        size: 1024,
        createdAt: 1720000,
      );

      expect(await store.fileId('manifest.json'), equals('gdrive-file-id-123'));
      expect(await store.fileId('unknown.json'), isNull);

      await store.removeFileId('manifest.json');
      expect(await store.fileId('manifest.json'), isNull);
    });

    test('blob_index table CRUD and deduplication lookup', () async {
      await store.putBlobIndex('plain-sha-1', 'blob_0001', 500, 1000);
      await store.putBlobIndex('plain-sha-1', 'blob_0002', 500, 2000);

      // Returns the blob key with newest seenAt
      final matchedBlob = await store.blobForPlainHash('plain-sha-1');
      expect(matchedBlob, equals('blob_0002'));

      await store.touchBlob('blob_0001', 3000);
      final touchedBlob = await store.blobForPlainHash('plain-sha-1');
      expect(touchedBlob, equals('blob_0001'));

      final all = await store.allBlobs();
      expect(all.length, equals(2));
    });

    test('conflicts table CRUD and resolution', () async {
      final id = await store.addConflict(
        ConflictRecord(
          time: 1721000000000,
          path: 'Work/Notes.md',
          copyPath: 'Work/Notes.conflict-laptop.md',
          kind: 'content',
          otherDevice: 'laptop',
          resolved: false,
        ),
      );

      var list = await store.conflicts();
      expect(list.length, equals(1));
      expect(list.first.id, equals(id));
      expect(list.first.resolved, isFalse);

      var unresolved = await store.conflicts(unresolvedOnly: true);
      expect(unresolved.length, equals(1));

      await store.resolveConflict(id);

      list = await store.conflicts();
      expect(list.first.resolved, isTrue);

      unresolved = await store.conflicts(unresolvedOnly: true);
      expect(unresolved.isEmpty, isTrue);
    });

    test('backups and backup_verifications table CRUD', () async {
      final b = BackupRecord(
        stamp: '2026-10-18T12:00:00Z',
        manifestKey: 'backups/2026-10-18T12:00:00Z/manifest.json',
        fileCount: 42,
        totalBytes: 1048576,
        createdAt: 1722000000000,
      );

      await store.putBackup(b);

      final fetched = await store.backup('2026-10-18T12:00:00Z');
      expect(fetched, isNotNull);
      expect(fetched!.fileCount, equals(42));
      expect(fetched.totalBytes, equals(1048576));

      final allBackups = await store.backups();
      expect(allBackups.length, equals(1));
      expect(allBackups.first.stamp, equals('2026-10-18T12:00:00Z'));

      final verId = await store.addBackupVerification(
        BackupVerificationRecord(
          time: 1722000050000,
          stamp: '2026-10-18T12:00:00Z',
          sampled: 10,
          ok: 9,
          failed: 1,
          failedKeys: const ['backups/2026-10-18T12:00:00Z/missing.blob'],
        ),
      );
      expect(verId, isPositive);

      final verifications = await store.verificationsForStamp(
        '2026-10-18T12:00:00Z',
      );
      expect(verifications.length, equals(1));
      expect(verifications.first.sampled, equals(10));
      expect(verifications.first.ok, equals(9));
      expect(verifications.first.failed, equals(1));
      expect(
        verifications.first.failedKeys,
        equals(['backups/2026-10-18T12:00:00Z/missing.blob']),
      );

      await store.removeBackup('2026-10-18T12:00:00Z');
      expect(await store.backup('2026-10-18T12:00:00Z'), isNull);
    });
  });

  group('SyncStateStore transactions and trimming', () {
    test(
      'transaction rollback on an exception leaves no partial rows',
      () async {
        final store = await SyncStateStore.openMemory();
        addTearDown(store.close);

        await store.setMeta('initialKey', 'value1');

        await expectLater(
          () => store.transaction(() async {
            await store.setMeta('txnKey', 'should-rollback');
            await store.putFileId('file.txt', 'file-id-txn');
            throw StateError('Simulated crash inside transaction');
          }),
          throwsA(isA<StateError>()),
        );

        // Verify rolled back
        expect(await store.getMeta('initialKey'), equals('value1'));
        expect(await store.getMeta('txnKey'), isNull);
        expect(await store.fileId('file.txt'), isNull);
      },
    );

    test('log trimming keeps exactly the newest 5,000 rows', () async {
      final store = await SyncStateStore.openMemory();
      addTearDown(store.close);

      // Bulk insert 5,005 log entries
      // Note: We test in a transaction or loop. Since appendLog trims on each call,
      // let's append 5,005 items and verify the count remains exactly 5,000.
      for (var i = 1; i <= 5010; i++) {
        await store.appendLog(
          SyncLogEntry(
            time: 1000 + i,
            level: 'INFO',
            kind: 'sync_step',
            detail: 'event-$i',
          ),
        );
      }

      final recent = await store.log(limit: 6000);
      expect(recent.length, equals(5000));
      // Newest first: first should be event-5010, last should be event-11 (oldest 10 trimmed: 1..10)
      expect(recent.first.detail, equals('event-5010'));
      expect(recent.last.detail, equals('event-11'));
    });
  });

  group('SelectiveSyncRules', () {
    test('JSON round trip and defaults', () {
      const defaultRules = SelectiveSyncRules();
      expect(defaultRules.excludedFolders, isEmpty);
      expect(defaultRules.excludedExtensions, isEmpty);
      expect(defaultRules.maxFileSizeBytes, equals(104857600));
      expect(defaultRules.mobileMode, isFalse);

      final json = defaultRules.toJson();
      final roundTrip = SelectiveSyncRules.fromJson(json);
      expect(roundTrip, equals(defaultRules));

      final customRules = SelectiveSyncRules(
        excludedFolders: const ['Archive', 'Temp/Large'],
        excludedExtensions: const {'pdf', 'iso'},
        maxFileSizeBytes: 10 * 1024 * 1024,
        mobileMode: true,
      );

      final customJson = customRules.toJson();
      final customRoundTrip = SelectiveSyncRules.fromJson(customJson);
      expect(customRoundTrip, equals(customRules));
      expect(customRoundTrip.mobileMode, isTrue);
    });

    test('mobileMode adds video extensions to effective exclusions', () {
      final standardRules = SelectiveSyncRules(
        excludedExtensions: const {'iso'},
        mobileMode: false,
      );
      expect(standardRules.effectiveExcludedExtensions, equals({'iso'}));
      expect(standardRules.isExcluded('video.mp4', 1000), isFalse);

      final mobileRules = SelectiveSyncRules(
        excludedExtensions: const {'iso'},
        mobileMode: true,
      );
      final expectedMobileExts = {
        'iso',
        'mp4',
        'mov',
        'mkv',
        'avi',
        'webm',
        'm4v',
        '3gp',
        'wmv',
        'flv',
      };
      expect(
        mobileRules.effectiveExcludedExtensions,
        equals(expectedMobileExts),
      );
      expect(mobileRules.isExcluded('media/clip.mp4', 1000), isTrue);
      expect(mobileRules.isExcluded('media/clip.MOV', 1000), isTrue);
      expect(mobileRules.isExcluded('notes/doc.md', 1000), isFalse);
    });

    test('isExcluded handles folder prefixes and size limits', () {
      final rules = SelectiveSyncRules(
        excludedFolders: const ['Private', 'Node_modules'],
        maxFileSizeBytes: 500,
      );

      // Folder exclusions
      expect(rules.isExcluded('Private/secret.md', 100), isTrue);
      expect(rules.isExcluded('Private', 100), isTrue);
      expect(rules.isExcluded('PrivateNotes/doc.md', 100), isFalse);
      expect(rules.isExcluded('Public/doc.md', 100), isFalse);

      // Size exclusion
      expect(rules.isExcluded('Public/doc.md', 501), isTrue);
      expect(rules.isExcluded('Public/doc.md', 500), isFalse);
    });
  });

  group('SyncStateStore file-backed reopening', () {
    test(
      'reopening a file-backed DB in temp directory preserves data',
      () async {
        final tempDir = Directory.systemTemp.createTempSync(
          'tephra_sync_test_',
        );
        addTearDown(() {
          try {
            if (tempDir.existsSync()) {
              tempDir.deleteSync(recursive: true);
            }
          } catch (_) {}
        });

        final dbPath = p.join(tempDir.path, 'sync.sqlite');

        // 1. Open DB, insert data, close
        final store1 = await SyncStateStore.open(dbPath);
        await store1.setMeta('vaultRoot', 'D:/vault');
        await store1.putBase(
          BaseState(
            path: 'Index.md',
            caseKey: 'index.md',
            hash: 'hash-init',
            size: 42,
            mtime: 1000,
            version: 'dev:1',
            blobKeys: const ['b1'],
            syncedAt: 1001,
          ),
        );
        await store1.putFileId('manifest.json', 'file-id-drive');
        await store1.close();

        // 2. Reopen DB at same path and verify persistence
        final store2 = await SyncStateStore.open(dbPath);
        addTearDown(store2.close);

        expect(await store2.getMeta('vaultRoot'), equals('D:/vault'));
        final base = await store2.base('Index.md');
        expect(base, isNotNull);
        expect(base!.hash, equals('hash-init'));
        expect(base.size, equals(42));
        expect(await store2.fileId('manifest.json'), equals('file-id-drive'));
      },
    );
  });
}
