// © 2026 Tephra. All rights reserved.

import 'dart:math';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_sync/tephra_sync.dart';
import 'package:test/test.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('SnapshotStore', () {
    late MemorySyncProvider provider;
    late SyncStateStore store;
    late ManualClock clock;
    late HlcClock hlcClock;
    late PlaintextObjectCipher cipher;
    late SnapshotStore snapshotStore;

    const myDeviceId = '11111111-1111-4111-8111-111111111111';

    setUp(() async {
      provider = MemorySyncProvider();
      await provider.connect();
      store = await SyncStateStore.openMemory();
      clock = ManualClock(DateTime.utc(2026, 10, 11, 10, 0));
      hlcClock = HlcClock(clock: clock, deviceId: myDeviceId);
      cipher = const PlaintextObjectCipher();
      snapshotStore = SnapshotStore(
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

    test('shouldSnapshot returns true only when crossing multiples of 500', () {
      expect(
        SnapshotStore.shouldSnapshot(lastSeq: 499, lastSnapshotSeq: 0),
        isFalse,
      );
      expect(
        SnapshotStore.shouldSnapshot(lastSeq: 500, lastSnapshotSeq: 0),
        isTrue,
      );
      expect(
        SnapshotStore.shouldSnapshot(lastSeq: 501, lastSnapshotSeq: 500),
        isFalse,
      );
      expect(
        SnapshotStore.shouldSnapshot(lastSeq: 999, lastSnapshotSeq: 500),
        isFalse,
      );
      expect(
        SnapshotStore.shouldSnapshot(lastSeq: 1000, lastSnapshotSeq: 500),
        isTrue,
      );
      expect(
        SnapshotStore.shouldSnapshot(lastSeq: 1500, lastSnapshotSeq: 1000),
        isTrue,
      );
    });

    test(
      'writeSnapshot keeps newest 3 snapshots and prunes older ones',
      () async {
        final history = RemoteHistory([
          const JournalEntry(
            entryId: '$myDeviceId:1',
            deviceId: myDeviceId,
            seq: 1,
            hlc: '000000000001000.000000.$myDeviceId',
            op: 'put',
            path: 'Doc.md',
            time: 1000,
          ),
        ]);

        // Write 4 snapshots: 500, 1000, 1500, 2000
        await snapshotStore.writeSnapshot(
          lastSeq: 500,
          history: history,
          covers: {myDeviceId: 500},
        );
        await snapshotStore.writeSnapshot(
          lastSeq: 1000,
          history: history,
          covers: {myDeviceId: 1000},
        );
        await snapshotStore.writeSnapshot(
          lastSeq: 1500,
          history: history,
          covers: {myDeviceId: 1500},
        );
        await snapshotStore.writeSnapshot(
          lastSeq: 2000,
          history: history,
          covers: {myDeviceId: 2000},
        );

        final prefix = RemoteLayout.deviceSnapshotsPrefix(myDeviceId);
        final objects = await provider.list(prefix);

        // Only newest 3 remain: 1000, 1500, 2000 (500 was deleted)
        expect(objects.length, equals(3));
        final keys = objects.map((o) => o.key).toList();
        expect(keys, contains(RemoteLayout.snapshot(myDeviceId, 1000)));
        expect(keys, contains(RemoteLayout.snapshot(myDeviceId, 1500)));
        expect(keys, contains(RemoteLayout.snapshot(myDeviceId, 2000)));
        expect(keys, isNot(contains(RemoteLayout.snapshot(myDeviceId, 500))));
      },
    );

    test('property test: bootstrap from snapshot + journals matches replay of all journals (3 devices x 2,000 entries)', () async {
      final rng = Random(42);
      const devices = [
        '11111111-1111-4111-8111-111111111111',
        '22222222-2222-4222-8222-222222222222',
        '33333333-3333-4333-8333-333333333333',
      ];
      final paths = List.generate(10, (i) => 'folder/note_$i.md');

      // Shared provider where all 3 devices commit journals
      final sharedProvider = MemorySyncProvider();
      await sharedProvider.connect();

      final devStores = <String, SyncStateStore>{};
      final devWriters = <String, JournalWriter>{};
      final devReaders = <String, JournalReader>{};
      final devSnapStores = <String, SnapshotStore>{};

      for (final devId in devices) {
        final s = await SyncStateStore.openMemory();
        final c = ManualClock(DateTime.utc(2026, 10, 11, 10));
        final h = HlcClock(clock: c, deviceId: devId);
        devStores[devId] = s;
        devWriters[devId] = JournalWriter(
          provider: sharedProvider,
          cipher: cipher,
          store: s,
          hlcClock: h,
        );
        devReaders[devId] = JournalReader(
          provider: sharedProvider,
          cipher: cipher,
          store: s,
          hlcClock: h,
        );
        devSnapStores[devId] = SnapshotStore(
          provider: sharedProvider,
          cipher: cipher,
          store: s,
          hlcClock: h,
        );
      }

      // Simulated timeline: generate 2,000 total mutations across the 3 devices
      for (var i = 0; i < 2000; i++) {
        final devId = devices[rng.nextInt(devices.length)];
        final path = paths[rng.nextInt(paths.length)];
        final isDelete = rng.nextDouble() < 0.1;

        final writer = devWriters[devId]!;
        final reader = devReaders[devId]!;
        final snapStore = devSnapStores[devId]!;
        final devStore = devStores[devId]!;

        // Periodically refresh to observe remote heads
        if (i % 25 == 0) {
          await reader.refresh();
        }

        final head = await devStore.head(path);
        await writer.stage(
          op: isDelete ? 'delete' : 'put',
          path: path,
          hash: isDelete ? null : 'hash_$i',
          size: isDelete ? null : 100 + i,
          parent: head?.$1,
        );

        if (writer.staged.length >= 25 || i == 1999) {
          final batch = await writer.commit();
          if (batch != null) {
            final cursors = await devStore.allCursors();
            final covers = {
              for (final c in cursors) c.deviceId: c.lastSeq,
              devId: batch.lastSeq,
            };
            final history = RemoteHistory(await devStore.allEntries());
            await snapStore.maybeSnapshot(
              lastSeq: batch.lastSeq,
              history: history,
              covers: covers,
            );
          }
        }
      }

      // Flush all devices
      for (final devId in devices) {
        await devWriters[devId]!.commit();
      }

      // 1. Device 4: Bootstraps from snapshot + refreshes remaining journals
      final store4 = await SyncStateStore.openMemory();
      final clock4 = ManualClock(DateTime.utc(2026, 10, 11, 12));
      final hlcClock4 = HlcClock(clock: clock4, deviceId: 'dev4');
      final snapStore4 = SnapshotStore(
        provider: sharedProvider,
        cipher: cipher,
        store: store4,
        hlcClock: hlcClock4,
        clock: clock4,
      );
      final reader4 = JournalReader(
        provider: sharedProvider,
        cipher: cipher,
        store: store4,
        hlcClock: hlcClock4,
        clock: clock4,
      );

      final bootstrapped = await snapStore4.bootstrap();
      expect(bootstrapped, isTrue);
      await reader4.refresh();

      // 2. Device 5 (Control): Replays all journals from seq 1 without snapshot
      final store5 = await SyncStateStore.openMemory();
      final clock5 = ManualClock(DateTime.utc(2026, 10, 11, 12));
      final hlcClock5 = HlcClock(clock: clock5, deviceId: 'dev5');
      final reader5 = JournalReader(
        provider: sharedProvider,
        cipher: cipher,
        store: store5,
        hlcClock: hlcClock5,
        clock: clock5,
      );
      await reader5.refresh();

      // 3. Assert heads on Device 4 match heads on Device 5 identically!
      final heads4 = await store4.heads();
      final heads5 = await store5.heads();

      expect(heads4.keys.toSet(), equals(heads5.keys.toSet()));
      for (final path in heads4.keys) {
        expect(heads4[path]!.$1, equals(heads5[path]!.$1));
        expect(heads4[path]!.$2, equals(heads5[path]!.$2));
      }

      for (final s in devStores.values) {
        await s.close();
      }
      await store4.close();
      await store5.close();
    });
  });
}
