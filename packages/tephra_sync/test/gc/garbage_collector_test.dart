// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:io';

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
  late HlcClock hlcClock;
  late GarbageCollector gc;

  const deviceA = '00000000-0000-0000-0000-00000000000a';
  const deviceB = '00000000-0000-0000-0000-00000000000b';

  setUp(() async {
    clock = FakeClock(DateTime.utc(2026, 10, 20, 12, 0, 0));
    provider = MemorySyncProvider(clock: clock);
    store = await SyncStateStore.openMemory();
    cipher = PlaintextObjectCipher();
    hlcClock = HlcClock(clock: clock, deviceId: deviceA);

    gc = GarbageCollector(
      vaultId: 'vault-1',
      deviceId: deviceA,
      provider: provider,
      cipher: cipher,
      store: store,
      hlcClock: hlcClock,
      clock: clock,
    );
  });

  tearDown(() async {
    await store.close();
  });

  group('GarbageCollector.isEligible', () {
    test('returns false if conditions not met', () async {
      // Metered
      expect(
        await GarbageCollector.isEligible(
          store: store,
          isUnmetered: false,
          isWindowsOrAndroidCharging: true,
          now: clock.now(),
        ),
        isFalse,
      );

      // Not charging on battery
      expect(
        await GarbageCollector.isEligible(
          store: store,
          isUnmetered: true,
          isWindowsOrAndroidCharging: false,
          now: clock.now(),
        ),
        isFalse,
      );

      // Mode off
      await store.setMeta('mode', 'off');
      expect(
        await GarbageCollector.isEligible(
          store: store,
          isUnmetered: true,
          isWindowsOrAndroidCharging: true,
          now: clock.now(),
        ),
        isFalse,
      );
      await store.setMeta('mode', 'live');

      // First sync pending
      await store.setMeta('firstSyncPending', 'true');
      expect(
        await GarbageCollector.isEligible(
          store: store,
          isUnmetered: true,
          isWindowsOrAndroidCharging: true,
          now: clock.now(),
        ),
        isFalse,
      );
      await store.setMeta('firstSyncPending', 'false');

      // Cooldown not elapsed
      final now = clock.now();
      await store.setMeta(
        'lastGcAt',
        now.subtract(const Duration(days: 3)).millisecondsSinceEpoch.toString(),
      );
      expect(
        await GarbageCollector.isEligible(
          store: store,
          isUnmetered: true,
          isWindowsOrAndroidCharging: true,
          now: now,
        ),
        isFalse,
      );

      // Cooldown elapsed
      await store.setMeta(
        'lastGcAt',
        now.subtract(const Duration(days: 8)).millisecondsSinceEpoch.toString(),
      );
      expect(
        await GarbageCollector.isEligible(
          store: store,
          isUnmetered: true,
          isWindowsOrAndroidCharging: true,
          now: now,
        ),
        isTrue,
      );
    });
  });

  group('GarbageCollector leases', () {
    test('lease resolution picks smallest (hlc, deviceId)', () async {
      final hlcA = Hlc(millis: 1000, counter: 1, deviceId: deviceA);
      final hlcB = Hlc(millis: 1000, counter: 2, deviceId: deviceB);

      final leaseA = GcLease(
        deviceId: deviceA,
        hlc: hlcA,
        createdAt: clock.now(),
      );
      final leaseB = GcLease(
        deviceId: deviceB,
        hlc: hlcB,
        createdAt: clock.now(),
      );

      await provider.put(
        RemoteLayout.gcLease(deviceA),
        await leaseA.seal(cipher),
      );
      await provider.put(
        RemoteLayout.gcLease(deviceB),
        await leaseB.seal(cipher),
      );

      // Device A check: it should be the winner
      final wonA = await gc.resolveLeaseWinner(myLease: leaseA);
      expect(wonA, isTrue);

      // Device B check: it should lose
      final gcB = GarbageCollector(
        vaultId: 'vault-1',
        deviceId: deviceB,
        provider: provider,
        cipher: cipher,
        store: store,
        hlcClock: HlcClock(clock: clock, deviceId: deviceB),
        clock: clock,
      );
      final wonB = await gcB.resolveLeaseWinner(myLease: leaseB);
      expect(wonB, isFalse);
    });

    test('expired leases older than 30 minutes are ignored', () async {
      // Lease B was written 40 minutes ago
      clock._now = clock.now().subtract(const Duration(minutes: 40));
      final hlcB = Hlc(millis: 500, counter: 0, deviceId: deviceB);
      final leaseB = GcLease(
        deviceId: deviceB,
        hlc: hlcB,
        createdAt: clock.now(),
      );

      // Write lease B with old modified time
      await provider.put(
        RemoteLayout.gcLease(deviceB),
        await leaseB.seal(cipher),
      );

      // Now advance clock 40 minutes and claim lease A
      clock.step(const Duration(minutes: 40));
      final leaseA = await gc.claimLease();
      final wonA = await gc.resolveLeaseWinner(myLease: leaseA);
      expect(wonA, isTrue);
    });
  });

  group('GarbageCollector mark and sweep', () {
    test('two-phase sweep: 7-day grace and 24-hour candidate delay before deletion', () async {
      const liveBlobHash =
          '1111111111111111111111111111111111111111111111111111111111111111';
      const youngUnrefBlobHash =
          '2222222222222222222222222222222222222222222222222222222222222222';
      const oldUnrefBlobHash =
          '3333333333333333333333333333333333333333333333333333333333333333';

      final liveKey = RemoteLayout.blob(liveBlobHash);
      final youngKey = RemoteLayout.blob(youngUnrefBlobHash);
      final oldKey = RemoteLayout.blob(oldUnrefBlobHash);

      // Put old blob 8 days ago
      clock._now = DateTime.utc(2026, 10, 12, 12, 0, 0);
      await provider.put(oldKey, utf8.encode('old data'));

      // Put young blob 3 days ago
      clock._now = DateTime.utc(2026, 10, 17, 12, 0, 0);
      await provider.put(youngKey, utf8.encode('young data'));

      // Put live blob today
      clock._now = DateTime.utc(2026, 10, 20, 12, 0, 0);
      await provider.put(liveKey, utf8.encode('live data'));

      // Write a journal batch referencing liveKey
      final batch = JournalBatch(
        deviceId: deviceA,
        firstSeq: 1,
        lastSeq: 1,
        createdAt: clock.now(),
        entries: [
          JournalEntry(
            entryId: '$deviceA:1',
            deviceId: deviceA,
            seq: 1,
            hlc: hlcClock.tick().encoded,
            time: clock.now().millisecondsSinceEpoch,
            path: 'note.md',
            op: 'put',
            blobKeys: [liveKey],
          ),
        ],
      );
      final batchKey = RemoteLayout.journal(deviceA, 1);
      final sealedBatch = await cipher.seal(
        utf8.encode(jsonEncode(batch.toJson())),
        ObjectPurpose.journal,
      );
      await provider.put(batchKey, sealedBatch);

      // Run 1: at Day 0 (2026-10-20)
      final report1 = await gc.runGc(skipLeaseWait: true);
      expect(report1, isNotNull);
      expect(report1!.liveBlobs, 1);
      expect(report1.deletedBlobs, 0);
      expect(report1.candidateBlobs, 1); // oldKey became candidate

      // Verify oldKey and youngKey and liveKey all still exist
      expect(await provider.get(liveKey), isNotNull);
      expect(await provider.get(youngKey), isNotNull);
      expect(await provider.get(oldKey), isNotNull);

      // Advance clock by 12 hours (less than 24h candidate grace)
      clock.step(const Duration(hours: 12));
      final report2 = await gc.runGc(skipLeaseWait: true);
      expect(report2!.deletedBlobs, 0);
      expect(await provider.get(oldKey), isNotNull);

      // Advance clock by another 13 hours (total > 24h since candidate discovery)
      clock.step(const Duration(hours: 13));
      final report3 = await gc.runGc(skipLeaseWait: true);
      expect(report3!.deletedBlobs, 1);
      expect(report3.candidateBlobs, 0);

      // oldKey is deleted!
      expect(() => provider.get(oldKey), throwsA(anything));
      // youngKey and liveKey remain intact!
      expect(await provider.get(liveKey), isNotNull);
      expect(await provider.get(youngKey), isNotNull);
    });

    test('aborts and deletes zero blobs if journal is unreadable', () async {
      const oldUnrefBlobHash =
          '4444444444444444444444444444444444444444444444444444444444444444';
      final oldKey = RemoteLayout.blob(oldUnrefBlobHash);

      clock._now = DateTime.utc(2026, 10, 10, 12, 0, 0);
      await provider.put(oldKey, utf8.encode('unref'));

      // Put corrupt journal
      clock._now = DateTime.utc(2026, 10, 20, 12, 0, 0);
      await provider.put(
        RemoteLayout.journal(deviceA, 1),
        utf8.encode('corrupted garbage bytes that fail decryption'),
      );

      final report = await gc.runGc(skipLeaseWait: true);
      expect(report, isNull); // aborted!

      // Unreferenced blob was NOT deleted
      expect(await provider.get(oldKey), isNotNull);
    });

    test('preserves blobs from snapshots and backup manifests', () async {
      const snapBlobHash =
          '5555555555555555555555555555555555555555555555555555555555555555';
      const backupBlobHash =
          '6666666666666666666666666666666666666666666666666666666666666666';

      final snapKey = RemoteLayout.blob(snapBlobHash);
      final backupKey = RemoteLayout.blob(backupBlobHash);

      clock._now = DateTime.utc(2026, 10, 10, 12, 0, 0);
      await provider.put(snapKey, utf8.encode('snap'));
      await provider.put(backupKey, utf8.encode('backup'));

      // 1. Snapshot
      final snapData = {
        'v': 1,
        'deviceId': deviceA,
        'seq': 5,
        'entries': [
          {
            'id': '$deviceA:5',
            'seq': 5,
            'hlc': '000000000001000.000001.$deviceA',
            'time': 1000,
            'path': 'snap.md',
            'op': 'put',
            'blobKeys': [snapKey],
          },
        ],
      };
      final gzipped = gzip.encode(utf8.encode(jsonEncode(snapData)));
      final sealedSnap = await cipher.seal(gzipped, ObjectPurpose.snapshot);
      await provider.put(RemoteLayout.snapshot(deviceA, 5), sealedSnap);

      // 2. Backup manifest
      final manifest = BackupManifest(
        vaultId: 'vault-1',
        createdAt: DateTime.utc(2026, 10, 10, 12, 0, 0),
        deviceId: deviceA,
        deviceName: 'Device A',
        kind: BackupKind.manual,
        fileCount: 1,
        totalBytes: 6,
        files: [
          BackupManifestFile(
            path: 'backup.md',
            size: 6,
            hash: 'somehash',
            mtime: 1000,
            blobKeys: [backupKey],
          ),
        ],
      );
      await provider.put(
        RemoteLayout.backupManifest(DateTime.utc(2026, 10, 10, 12, 0, 0)),
        await manifest.seal(cipher),
      );

      // Run GC at Day 10
      clock._now = DateTime.utc(2026, 10, 20, 12, 0, 0);
      final report = await gc.runGc(skipLeaseWait: true);
      expect(report, isNotNull);
      expect(report!.liveBlobs, 2);
      expect(report.candidateBlobs, 0);
      expect(report.deletedBlobs, 0);

      expect(await provider.get(snapKey), isNotNull);
      expect(await provider.get(backupKey), isNotNull);
    });

    test('preserves blobs from revoked devices', () async {
      const revokedBlobHash =
          '7777777777777777777777777777777777777777777777777777777777777777';
      final revokedBlobKey = RemoteLayout.blob(revokedBlobHash);

      clock._now = DateTime.utc(2026, 10, 10, 12, 0, 0);
      await provider.put(revokedBlobKey, utf8.encode('revoked data'));

      // Put revocation record for deviceB
      await provider.put(
        RemoteLayout.deviceRevocation(deviceB),
        utf8.encode('{"revoked": true}'),
      );

      // Put journal for deviceB containing revokedBlobKey
      final batch = JournalBatch(
        deviceId: deviceB,
        firstSeq: 1,
        lastSeq: 2,
        createdAt: clock.now(),
        entries: [
          JournalEntry(
            entryId: '$deviceB:1',
            deviceId: deviceB,
            seq: 1,
            hlc: '000000000001000.000001.$deviceB',
            time: 1000,
            path: 'old_deleted_file.md',
            op: 'put',
            blobKeys: [revokedBlobKey],
          ),
          JournalEntry(
            entryId: '$deviceB:2',
            deviceId: deviceB,
            seq: 2,
            hlc: '000000000002000.000001.$deviceB',
            time: 2000,
            path: 'old_deleted_file.md',
            op: 'delete',
          ),
        ],
      );
      final sealedBatch = await cipher.seal(
        utf8.encode(jsonEncode(batch.toJson())),
        ObjectPurpose.journal,
      );
      await provider.put(RemoteLayout.journal(deviceB, 1), sealedBatch);

      // Run GC: even though file is deleted and old, revoked device blobs are preserved
      clock._now = DateTime.utc(2026, 10, 20, 12, 0, 0);
      final report = await gc.runGc(skipLeaseWait: true);
      expect(report, isNotNull);
      expect(report!.liveBlobs, 1);
      expect(report.candidateBlobs, 0);
      expect(await provider.get(revokedBlobKey), isNotNull);
    });
  });
}
