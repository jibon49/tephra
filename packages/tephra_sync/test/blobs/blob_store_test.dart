// © 2026 Tephra. All rights reserved.

import 'dart:math';
import 'dart:typed_data';

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_sync/tephra_sync.dart';
import 'package:test/test.dart';

Uint8List _makeBuffer(int length, int seed) {
  final rng = Random(seed);
  final buf = Uint8List(length);
  for (var i = 0; i < length; i++) {
    buf[i] = rng.nextInt(256);
  }
  return buf;
}

void main() {
  group('BlobStore tests', () {
    const vaultId = '00000000-0000-4000-8000-000000000001';
    final masterKey = MasterKey(List<int>.generate(32, (i) => i));

    for (final cipherType in ['encrypted', 'plaintext']) {
      group('with $cipherType cipher', () {
        late MemorySyncProvider provider;
        late SyncStateStore store;
        late ObjectCipher cipher;
        late ManualClock clock;
        late BlobStore blobStore;

        setUp(() async {
          provider = MemorySyncProvider();
          await provider.connect();
          store = await SyncStateStore.openMemory();
          clock = ManualClock(DateTime.utc(2026, 10, 18, 12, 0, 0));

          if (cipherType == 'encrypted') {
            cipher = EncryptingObjectCipher(
              masterKey: masterKey.secretKey,
              vaultId: vaultId,
            );
          } else {
            cipher = const PlaintextObjectCipher();
          }

          blobStore = BlobStore(
            provider: provider,
            cipher: cipher,
            store: store,
            clock: clock,
          );
        });

        tearDown(() async {
          await store.close();
        });

        test('round trip across 0 B, 10 B, 4 MiB, 4 MiB + 1, 12 MiB', () async {
          final testSizes = [
            0,
            10,
            4194304, // 4 MiB
            4194305, // 4 MiB + 1
            12 * 1024 * 1024, // 12 MiB
          ];

          for (final size in testSizes) {
            final data = _makeBuffer(size, size);
            final hash = contentHash(data);

            final keys = await blobStore.putFile(data, plainHash: hash);
            if (size <= 4194304) {
              expect(keys.length, equals(1));
            } else {
              expect(keys.length, greaterThan(1));
            }

            final retrieved = await blobStore.getFile(
              keys,
              expectedPlainHash: hash,
            );
            expect(retrieved.length, equals(size));
            expect(contentHash(retrieved), equals(hash));
          }
        });

        test('second putFile of identical bytes performs zero put calls (deduplication)', () async {
          final data = _makeBuffer(1024 * 1024, 77); // 1 MiB
          final hash = contentHash(data);

          var putCalls = 0;
          provider.beforeOp = (op, key) async {
            if (op == 'put') putCalls++;
          };

          // First upload
          final keys1 = await blobStore.putFile(data, plainHash: hash);
          expect(keys1.length, equals(1));
          expect(putCalls, equals(1));

          // Second upload of identical bytes
          putCalls = 0;
          final keys2 = await blobStore.putFile(data, plainHash: hash);
          expect(keys2, equals(keys1));
          expect(putCalls, equals(0)); // Zero put calls!
        });

        test('stale blob_index row whose blob was deleted remotely causes re-upload', () async {
          final data = _makeBuffer(500, 88);
          final hash = contentHash(data);

          final keys = await blobStore.putFile(data, plainHash: hash);
          final blobKey = keys.first;

          // Advance clock by 25 hours (past 24h stale threshold)
          clock.advance(const Duration(hours: 25));

          // Delete blob remotely
          await provider.delete(blobKey);
          expect(await provider.list(blobKey), isEmpty);

          var putCalls = 0;
          provider.beforeOp = (op, key) async {
            if (op == 'put') putCalls++;
          };

          // putFile detects remote absence and re-uploads
          final newKeys = await blobStore.putFile(data, plainHash: hash);
          expect(newKeys.length, equals(1));
          expect(putCalls, equals(1));

          // Confirm blob exists remotely again
          final retrieved = await blobStore.getFile(
            newKeys,
            expectedPlainHash: hash,
          );
          expect(retrieved, equals(data));
        });

        test(
          'corrupting one stored byte throws TamperedDataException',
          () async {
            final data = _makeBuffer(1000, 99);
            final hash = contentHash(data);

            final keys = await blobStore.putFile(data, plainHash: hash);
            final blobKey = keys.first;

            // Corrupt one byte in the stored blob
            final stored = Uint8List.fromList(await provider.get(blobKey));
            stored[stored.length - 1] ^= 0x55;
            await provider.put(blobKey, stored);

            expect(
              () => blobStore.getFile(keys, expectedPlainHash: hash),
              throwsA(isA<TamperedDataException>()),
            );
          },
        );

        test(
          'wrong expected plain hash throws TamperedDataException',
          () async {
            final data = _makeBuffer(1000, 111);
            final hash = contentHash(data);

            final keys = await blobStore.putFile(data, plainHash: hash);

            expect(
              () => blobStore.getFile(
                keys,
                expectedPlainHash: '0000000000000000000000000000000000000000000000000000000000000000',
              ),
              throwsA(isA<TamperedDataException>()),
            );
          },
        );
      });
    }
  });
}
