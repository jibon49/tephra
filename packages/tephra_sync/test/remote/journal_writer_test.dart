// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:typed_data';

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_sync/tephra_sync.dart';
import 'package:test/test.dart';

void main() {
  group('JournalWriter', () {
    late MemorySyncProvider provider;
    late SyncStateStore store;
    late ManualClock clock;
    late HlcClock hlcClock;
    late EncryptingObjectCipher cipher;
    late JournalWriter writer;

    const deviceId = '11111111-1111-4111-8111-111111111111';

    setUp(() async {
      provider = MemorySyncProvider();
      await provider.connect();
      store = await SyncStateStore.openMemory();
      clock = ManualClock(DateTime.utc(2026, 10, 11, 10, 0));
      hlcClock = HlcClock(clock: clock, deviceId: deviceId);
      cipher = EncryptingObjectCipher(
        masterKey: SecretKey(Uint8List(32)),
        vaultId: 'test-vault-id',
      );
      writer = JournalWriter(
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

    test('staging assigns sequential seq and HLC, commit seals and writes to remote', () async {
      final e1 = await writer.stage(
        op: 'put',
        path: 'Note1.md',
        hash: 'hash1',
        size: 100,
      );
      final e2 = await writer.stage(
        op: 'put',
        path: 'Note2.md',
        hash: 'hash2',
        size: 200,
      );

      expect(e1.seq, equals(1));
      expect(e2.seq, equals(2));
      expect(Hlc.parse(e2.hlc) > Hlc.parse(e1.hlc), isTrue);

      final batch = await writer.commit();
      expect(batch, isNotNull);
      expect(batch!.firstSeq, equals(1));
      expect(batch.lastSeq, equals(2));
      expect(batch.entries.length, equals(2));

      // 1. Remote object exists and decrypts
      final key = RemoteLayout.journal(deviceId, 1);
      final raw = await provider.get(key);
      final decrypted = await cipher.open(raw, ObjectPurpose.journal);
      final remoteBatch = JournalBatch.fromJson(
        jsonDecode(utf8.decode(decrypted)) as Map<String, Object?>,
      );
      expect(remoteBatch.entries.length, equals(2));

      // 2. Local database state updated
      final nextSeq = await store.getMeta('nextSeq');
      expect(nextSeq, equals('3'));

      final allEntries = await store.allEntries();
      expect(allEntries.length, equals(2));
      expect(allEntries[0].entryId, equals('$deviceId:1'));
      expect(allEntries[1].entryId, equals('$deviceId:2'));

      // 3. Pending ops removed
      final pending = await store.pendingOps();
      expect(pending, isEmpty);
    });

    test('commit order: pending op stored BEFORE put; crash at put leaves pending op, recover() finishes it', () async {
      await writer.stage(
        op: 'put',
        path: 'CrashTest.md',
        hash: 'hashA',
        size: 50,
      );

      // Fault injection: simulate network failure / crash at provider.put
      var putAttempted = false;
      provider.beforeOp = (op, key) async {
        if (op == 'put' && key.startsWith('journals/')) {
          putAttempted = true;
          throw const NetworkUnavailableException(
            'Network crashed right before put',
          );
        }
      };

      // Commit fails because put threw
      await expectLater(
        writer.commit(),
        throwsA(isA<NetworkUnavailableException>()),
      );
      expect(putAttempted, isTrue);

      // Verify: pending_op survived in SQLite!
      final pending = await store.pendingOps();
      expect(pending.length, equals(1));
      expect(pending.first.kind, equals('journalBatch'));

      // Next run: recover() is called with network restored
      provider.beforeOp = null;
      await writer.recover();

      // Remote object now exists!
      final key = RemoteLayout.journal(deviceId, 1);
      final raw = await provider.get(key);
      expect(raw, isNotEmpty);

      // NextSeq advanced and pending op cleared
      final nextSeq = await store.getMeta('nextSeq');
      expect(nextSeq, equals('2'));
      final pendingAfter = await store.pendingOps();
      expect(pendingAfter, isEmpty);

      // Entries inserted into remote_entries
      final entries = await store.allEntries();
      expect(entries.length, equals(1));
      expect(entries.first.path, equals('CrashTest.md'));
    });

    test('crash after put before SQLite update: recover() finishes without re-uploading different bytes', () async {
      await writer.stage(
        op: 'put',
        path: 'CrashAfterPut.md',
        hash: 'hashB',
        size: 75,
      );

      // Put the sealed batch directly to simulate put having succeeded remotely,
      // but SQLite failed before completing transaction
      final tempBatch = JournalBatch(
        deviceId: deviceId,
        firstSeq: 1,
        lastSeq: 1,
        createdAt: clock.now().toUtc(),
        entries: writer.staged,
      );
      final key = RemoteLayout.journal(deviceId, 1);
      final jsonBytes = utf8.encode(jsonEncode(tempBatch.toJson()));
      final sealed = await cipher.seal(jsonBytes, ObjectPurpose.journal);
      await provider.put(key, sealed);

      // Insert pending op simulating crash right after put
      final payloadJson = jsonEncode({
        'firstSeq': 1,
        'lastSeq': 1,
        'key': key,
        'bytesBase64': base64Encode(sealed),
        'entries': writer.staged
            .map((e) => e.toJson(includeDeviceId: true))
            .toList(),
      });
      await store.addPendingOp('journalBatch', payloadJson);

      var putCalledDuringRecover = false;
      provider.beforeOp = (op, k) async {
        if (op == 'put' && k == key) {
          putCalledDuringRecover = true;
        }
      };

      // Call recover()
      await writer.recover();

      // Assert recover finished without calling provider.put again!
      expect(putCalledDuringRecover, isFalse);

      final nextSeq = await store.getMeta('nextSeq');
      expect(nextSeq, equals('2'));
      final pending = await store.pendingOps();
      expect(pending, isEmpty);

      final entries = await store.allEntries();
      expect(entries.length, equals(1));
      expect(entries.first.path, equals('CrashAfterPut.md'));
    });
  });
}
