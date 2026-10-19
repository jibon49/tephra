// © 2026 Tephra. All rights reserved.

import 'dart:math';

import 'package:tephra_sync/tephra_sync.dart';
import 'package:test/test.dart';

/// Reusable compliance test suite for implementations of [SyncProvider].
void runSyncProviderContract(
  String name,
  Future<SyncProvider> Function() create, {
  Future<void> Function(SyncProvider)? cleanUp,
}) {
  group(name, () {
    late SyncProvider provider;
    late String testPrefix;

    setUp(() async {
      provider = await create();
      await provider.connect();
      final randHex = Random()
          .nextInt(0x7fffffff)
          .toRadixString(16)
          .padLeft(8, '0');
      testPrefix = 't$randHex';
    });

    tearDown(() async {
      if (cleanUp != null) {
        await cleanUp(provider);
      }
    });

    test(
      'put -> get returns identical bytes across 0 B, 1 KiB, 6 MiB',
      () async {
        // 0 bytes
        final key0 = '$testPrefix/empty.bin';
        await provider.put(key0, const []);
        final bytes0 = await provider.get(key0);
        expect(bytes0, isEmpty);

        // 1 KiB
        final key1k = '$testPrefix/1k.bin';
        final data1k = List<int>.generate(1024, (i) => i % 256);
        await provider.put(key1k, data1k);
        final bytes1k = await provider.get(key1k);
        expect(bytes1k, equals(data1k));

        // 6 MiB of seeded random bytes
        final key6m = '$testPrefix/6m.bin';
        final rng = Random(42);
        final data6m = List<int>.generate(
          6 * 1024 * 1024,
          (_) => rng.nextInt(256),
        );
        await provider.put(key6m, data6m);
        final bytes6m = await provider.get(key6m);
        expect(bytes6m, equals(data6m));
      },
    );

    test(
      'put twice on the same key updates content and list count is 1',
      () async {
        final key = '$testPrefix/update.txt';
        await provider.put(key, [1, 2, 3]);
        expect(await provider.get(key), equals([1, 2, 3]));

        await provider.put(key, [4, 5, 6, 7]);
        expect(await provider.get(key), equals([4, 5, 6, 7]));

        final listed = await provider.list(testPrefix);
        final matches = listed.where((o) => o.key == key).toList();
        expect(matches.length, equals(1));
        expect(matches.first.size, equals(4));
      },
    );

    test('list(prefix) returns exactly matching keys, sorted, including nested keys', () async {
      final k1 = '$testPrefix/alpha/doc1.txt';
      final k2 = '$testPrefix/alpha/sub/doc2.txt';
      final k3 = '$testPrefix/beta/doc3.txt';

      await provider.put(k2, [2]);
      await provider.put(k1, [1]);
      await provider.put(k3, [3]);

      final alphaList = await provider.list('$testPrefix/alpha');
      expect(alphaList.map((o) => o.key).toList(), equals([k1, k2]));

      final fullList = await provider.list(testPrefix);
      expect(fullList.map((o) => o.key).toList(), equals([k1, k2, k3]));
    });

    test('list on an unpopulated prefix returns []', () async {
      final emptyList = await provider.list('$testPrefix/nonexistent/');
      expect(emptyList, isEmpty);
    });

    test('delete removes object, repeat delete does not throw, get throws RemoteNotFoundException', () async {
      final key = '$testPrefix/to_delete.txt';
      await provider.put(key, [42]);
      expect(await provider.get(key), equals([42]));

      await provider.delete(key);
      expect(() => provider.get(key), throwsA(isA<RemoteNotFoundException>()));

      // Repeat delete should not throw
      await provider.delete(key);

      final listed = await provider.list(testPrefix);
      expect(listed.any((o) => o.key == key), isFalse);
    });

    test(
      'changesSince reports created and deleted keys and advances cursor',
      () async {
        final startCursor = (await provider.changesSince(null)).cursor;

        final keyPut = '$testPrefix/changed.txt';
        final keyDel = '$testPrefix/deleted.txt';

        await provider.put(keyDel, [99]);
        await provider.put(keyPut, [100]);
        await provider.delete(keyDel);

        RemoteChanges changes = await provider.changesSince(startCursor);
        expect(changes.changedKeys, contains(keyPut));
        expect(changes.removedKeys, contains(keyDel));
        expect(changes.cursorWasReset, isFalse);

        final nextCursor = changes.cursor;
        changes = await provider.changesSince(nextCursor);
        expect(changes.changedKeys, isEmpty);
        expect(changes.removedKeys, isEmpty);
      },
    );

    test('20 concurrent puts of different keys all succeed and list', () async {
      final futures = <Future<void>>[];
      for (var i = 0; i < 20; i++) {
        final key = '$testPrefix/concurrent_$i.bin';
        futures.add(provider.put(key, [i]));
      }
      await Future.wait(futures);

      final listed = await provider.list(testPrefix);
      expect(listed.length, equals(20));
      for (var i = 0; i < 20; i++) {
        expect(
          listed.any((o) => o.key == '$testPrefix/concurrent_$i.bin'),
          isTrue,
        );
      }
    });

    test(
      'RemoteObject.size equals byte length and modified is reasonable',
      () async {
        final key = '$testPrefix/timestamp.txt';
        final now = DateTime.now().toUtc();
        await provider.put(key, [1, 2, 3, 4, 5]);

        final listed = await provider.list(key);
        expect(listed.length, equals(1));
        final obj = listed.first;
        expect(obj.size, equals(5));

        final diff = obj.modified.difference(now).abs();
        expect(diff, lessThan(const Duration(minutes: 10)));
      },
    );

    test('quota() returns null or Quota with usedBytes >= 0', () async {
      final q = await provider.quota();
      if (q != null) {
        expect(q.usedBytes, greaterThanOrEqualTo(0));
      }
    });

    test('Invalid keys throw ArgumentError without calling backend', () {
      final invalidKeys = [
        '',
        '/a',
        'a//b',
        'a/../b',
        'a b',
        'a/./b',
        'trailing/',
      ];
      for (final k in invalidKeys) {
        expect(() => provider.put(k, [1]), throwsA(isA<ArgumentError>()));
        expect(() => provider.get(k), throwsA(isA<ArgumentError>()));
        expect(() => provider.delete(k), throwsA(isA<ArgumentError>()));
      }
    });
  });
}
