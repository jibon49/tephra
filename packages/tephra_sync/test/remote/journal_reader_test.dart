// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:typed_data';

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_sync/tephra_sync.dart';
import 'package:test/test.dart';

void main() {
  group('JournalReader', () {
    late MemorySyncProvider provider;
    late SyncStateStore store;
    late ManualClock clock;
    late HlcClock hlcClock;
    late EncryptingObjectCipher cipher;
    late JournalReader reader;

    const myDeviceId = '11111111-1111-4111-8111-111111111111';
    const peerDeviceId = '22222222-2222-4222-8222-222222222222';

    setUp(() async {
      provider = MemorySyncProvider();
      await provider.connect();
      store = await SyncStateStore.openMemory();
      clock = ManualClock(DateTime.utc(2026, 10, 11, 10, 0));
      hlcClock = HlcClock(clock: clock, deviceId: myDeviceId);
      cipher = EncryptingObjectCipher(
        masterKey: SecretKey(Uint8List(32)),
        vaultId: 'test-vault-id',
      );
      reader = JournalReader(
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

    Future<void> putRemoteBatch(JournalBatch batch) async {
      final key = RemoteLayout.journal(batch.deviceId, batch.firstSeq);
      final jsonBytes = utf8.encode(jsonEncode(batch.toJson()));
      final sealed = await cipher.seal(jsonBytes, ObjectPurpose.journal);
      await provider.put(key, sealed);
    }

    test(
      'reader stops at gaps without skipping, resumes when the gap is filled',
      () async {
        // Put Batch 1 (seq 1..2)
        final batch1 = JournalBatch(
          deviceId: peerDeviceId,
          firstSeq: 1,
          lastSeq: 2,
          createdAt: clock.now().toUtc(),
          entries: [
            const JournalEntry(
              entryId: '$peerDeviceId:1',
              deviceId: peerDeviceId,
              seq: 1,
              hlc: '000000000001000.000000.$peerDeviceId',
              op: 'put',
              path: 'Note1.md',
              time: 1000,
            ),
            const JournalEntry(
              entryId: '$peerDeviceId:2',
              deviceId: peerDeviceId,
              seq: 2,
              hlc: '000000000002000.000000.$peerDeviceId',
              op: 'put',
              path: 'Note2.md',
              time: 2000,
            ),
          ],
        );
        await putRemoteBatch(batch1);

        // Put Batch 3 (seq 5..6), leaving a gap for Batch 2 (seq 3..4)
        final batch3 = JournalBatch(
          deviceId: peerDeviceId,
          firstSeq: 5,
          lastSeq: 6,
          createdAt: clock.now().toUtc(),
          entries: [
            const JournalEntry(
              entryId: '$peerDeviceId:5',
              deviceId: peerDeviceId,
              seq: 5,
              hlc: '000000000005000.000000.$peerDeviceId',
              op: 'put',
              path: 'Note5.md',
              time: 5000,
            ),
            const JournalEntry(
              entryId: '$peerDeviceId:6',
              deviceId: peerDeviceId,
              seq: 6,
              hlc: '000000000006000.000000.$peerDeviceId',
              op: 'put',
              path: 'Note6.md',
              time: 6000,
            ),
          ],
        );
        await putRemoteBatch(batch3);

        // 1. First refresh: reads batch 1, stops at batch 2 (batch 3 is not skipped)
        await reader.refresh();

        var entries = await store.allEntries();
        expect(entries.length, equals(2));
        expect(entries.map((e) => e.seq), equals([1, 2]));

        var cursor = await store.cursor(peerDeviceId);
        expect(cursor?.lastSeq, equals(2));

        // 2. Now upload missing Batch 2 (seq 3..4)
        final batch2 = JournalBatch(
          deviceId: peerDeviceId,
          firstSeq: 3,
          lastSeq: 4,
          createdAt: clock.now().toUtc(),
          entries: [
            const JournalEntry(
              entryId: '$peerDeviceId:3',
              deviceId: peerDeviceId,
              seq: 3,
              hlc: '000000000003000.000000.$peerDeviceId',
              op: 'put',
              path: 'Note3.md',
              time: 3000,
            ),
            const JournalEntry(
              entryId: '$peerDeviceId:4',
              deviceId: peerDeviceId,
              seq: 4,
              hlc: '000000000004000.000000.$peerDeviceId',
              op: 'put',
              path: 'Note4.md',
              time: 4000,
            ),
          ],
        );
        await putRemoteBatch(batch2);

        // Second refresh: reads batch 2 and batch 3 sequentially
        await reader.refresh();

        entries = await store.allEntries();
        expect(entries.length, equals(6));
        expect(entries.map((e) => e.seq), equals([1, 2, 3, 4, 5, 6]));

        cursor = await store.cursor(peerDeviceId);
        expect(cursor?.lastSeq, equals(6));
      },
    );

    test('revoked device entries beyond lastAcceptedSeq are ignored', () async {
      // 1. Write revocation record on remote: lastAcceptedSeq = 2
      final revKey = RemoteLayout.deviceRevocation(peerDeviceId);
      final revPayload = {
        'v': 1,
        'deviceId': peerDeviceId,
        'revokedBy': myDeviceId,
        'revokedAt': '2026-10-11T10:00:00.000Z',
        'lastAcceptedSeq': 2,
      };
      final sealedRev = await cipher.seal(
        utf8.encode(jsonEncode(revPayload)),
        ObjectPurpose.device,
      );
      await provider.put(revKey, sealedRev);

      // 2. Remote peer has entries with seq 1, 2, 3, 4
      final batch = JournalBatch(
        deviceId: peerDeviceId,
        firstSeq: 1,
        lastSeq: 4,
        createdAt: clock.now().toUtc(),
        entries: [
          const JournalEntry(
            entryId: '$peerDeviceId:1',
            deviceId: peerDeviceId,
            seq: 1,
            hlc: '000000000001000.000000.$peerDeviceId',
            op: 'put',
            path: 'Allowed1.md',
            time: 1000,
          ),
          const JournalEntry(
            entryId: '$peerDeviceId:2',
            deviceId: peerDeviceId,
            seq: 2,
            hlc: '000000000002000.000000.$peerDeviceId',
            op: 'put',
            path: 'Allowed2.md',
            time: 2000,
          ),
          const JournalEntry(
            entryId: '$peerDeviceId:3',
            deviceId: peerDeviceId,
            seq: 3,
            hlc: '000000000003000.000000.$peerDeviceId',
            op: 'put',
            path: 'Disallowed3.md',
            time: 3000,
          ),
          const JournalEntry(
            entryId: '$peerDeviceId:4',
            deviceId: peerDeviceId,
            seq: 4,
            hlc: '000000000004000.000000.$peerDeviceId',
            op: 'put',
            path: 'Disallowed4.md',
            time: 4000,
          ),
        ],
      );
      await putRemoteBatch(batch);

      // Refresh
      await reader.refresh();

      // Only entries <= lastAcceptedSeq (1 and 2) are admitted
      final entries = await store.allEntries();
      expect(entries.length, equals(2));
      expect(entries.map((e) => e.seq), equals([1, 2]));

      final cursor = await store.cursor(peerDeviceId);
      expect(cursor?.lastSeq, equals(4));
      expect(cursor?.revokedAfterSeq, equals(2));
    });

    test('tampered batch stops reading that device only, other devices continue', () async {
      // Corrupt batch for peerDeviceId
      final badKey = RemoteLayout.journal(peerDeviceId, 1);
      await provider.put(
        badKey,
        Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9]),
      );

      // Valid batch for peer2
      const peer2 = '33333333-3333-4333-8333-333333333333';
      final validBatch = JournalBatch(
        deviceId: peer2,
        firstSeq: 1,
        lastSeq: 1,
        createdAt: clock.now().toUtc(),
        entries: [
          const JournalEntry(
            entryId: '$peer2:1',
            deviceId: peer2,
            seq: 1,
            hlc: '000000000001000.000000.$peer2',
            op: 'put',
            path: 'Peer2Note.md',
            time: 1000,
          ),
        ],
      );
      await putRemoteBatch(validBatch);

      // Refresh should not throw; should log severe and successfully read peer2
      await reader.refresh();

      final entries = await store.allEntries();
      expect(entries.length, equals(1));
      expect(entries.first.deviceId, equals(peer2));

      // Peer1 cursor was not advanced
      final cursorPeer1 = await store.cursor(peerDeviceId);
      expect(cursorPeer1, isNull);

      // Peer2 cursor was advanced
      final cursorPeer2 = await store.cursor(peer2);
      expect(cursorPeer2?.lastSeq, equals(1));
    });

    test('clone detection: foreign batch with firstSeq >= meta.nextSeq throws DeviceCloneDetectedException', () async {
      // Local meta.nextSeq is 1
      await store.setMeta('nextSeq', '1');

      // Someone else wrote a batch in myDeviceId's folder!
      final foreignBatch = JournalBatch(
        deviceId: myDeviceId,
        firstSeq: 1,
        lastSeq: 1,
        createdAt: clock.now().toUtc(),
        entries: [
          const JournalEntry(
            entryId: '$myDeviceId:1',
            deviceId: myDeviceId,
            seq: 1,
            hlc: '000000000001000.000000.$myDeviceId',
            op: 'put',
            path: 'Clone.md',
            time: 1000,
          ),
        ],
      );
      await putRemoteBatch(foreignBatch);

      expect(
        () => reader.refresh(),
        throwsA(isA<DeviceCloneDetectedException>()),
      );
    });
  });
}
