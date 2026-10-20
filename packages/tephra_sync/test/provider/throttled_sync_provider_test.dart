// © 2026 Tephra. All rights reserved.

import 'dart:typed_data';

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_sync/tephra_sync.dart';
import 'package:test/test.dart';

void main() {
  group('ThrottledSyncProvider', () {
    late MemorySyncProvider inner;
    late ManualClock clock;
    late Duration totalSimulatedDelay;

    Future<void> fakeDelay(Duration d) async {
      totalSimulatedDelay += d;
      clock.advance(d);
    }

    setUp(() {
      inner = MemorySyncProvider();
      clock = ManualClock(DateTime.utc(2026, 10, 20, 12, 0, 0));
      totalSimulatedDelay = Duration.zero;
    });

    test('unlimited (0 KiBps) does not delay', () async {
      final provider = ThrottledSyncProvider(
        inner,
        upKiBps: 0,
        downKiBps: 0,
        clock: clock,
        delay: fakeDelay,
      );

      final data = Uint8List(100 * 1024); // 100 KiB
      await provider.put('test.bin', data);
      final read = await provider.get('test.bin');

      expect(read.length, equals(100 * 1024));
      expect(totalSimulatedDelay, equals(Duration.zero));
    });

    test('clamps rates < 16 KiBps to minimum 16 KiBps', () {
      final provider = ThrottledSyncProvider(
        inner,
        upKiBps: 5,
        downKiBps: 10,
        clock: clock,
        delay: fakeDelay,
      );

      expect(provider.upKiBps, equals(5));
      // Effective rate is 16 KiBps (16,384 bytes/s)
    });

    test('upload throttling timing with initial burst', () async {
      final provider = ThrottledSyncProvider(
        inner,
        upKiBps: 16, // 16 KiB/s = 16,384 B/s
        clock: clock,
        delay: fakeDelay,
      );

      // 1. Initial burst: bucket starts full (16 KiB)
      final burstData = Uint8List(16 * 1024);
      await provider.put('burst.bin', burstData);
      expect(totalSimulatedDelay, equals(Duration.zero));

      // 2. Second upload immediately after: bucket is now empty, must wait 1 full second for 16 KiB
      await provider.put('second.bin', burstData);
      expect(totalSimulatedDelay.inMilliseconds, inInclusiveRange(999, 1001));

      // 3. Upload of 32 KiB: takes 2 seconds
      final doubleData = Uint8List(32 * 1024);
      final before32 = totalSimulatedDelay;
      await provider.put('double.bin', doubleData);
      final delta = totalSimulatedDelay - before32;
      expect(delta.inMilliseconds, inInclusiveRange(1999, 2001));
    });

    test('download throttling timing', () async {
      final provider = ThrottledSyncProvider(
        inner,
        downKiBps: 16, // 16 KiB/s
        clock: clock,
        delay: fakeDelay,
      );

      // Seed 32 KiB directly into inner
      final data = Uint8List(32 * 1024);
      await inner.put('down.bin', data);

      // First get: consumes 16 KiB burst, waits 1s for remaining 16 KiB
      final read = await provider.get('down.bin');
      expect(read.length, equals(32 * 1024));
      expect(totalSimulatedDelay.inMilliseconds, inInclusiveRange(999, 1001));

      // Second get immediately after: bucket is empty, waits 2s for 32 KiB
      final beforeSecond = totalSimulatedDelay;
      final read2 = await provider.get('down.bin');
      expect(read2.length, equals(32 * 1024));
      final delta = totalSimulatedDelay - beforeSecond;
      expect(delta.inMilliseconds, inInclusiveRange(1999, 2001));
    });

    test('delegates non-throttled calls to inner provider', () async {
      final provider = ThrottledSyncProvider(
        inner,
        upKiBps: 16,
        clock: clock,
        delay: fakeDelay,
      );

      await provider.connect();
      expect(provider.id, equals(inner.id));

      await provider.put('k1', [1]);
      await provider.put('k2', [2]);

      final list = await provider.list('');
      expect(list.map((o) => o.key), containsAll(['k1', 'k2']));

      final changes = await provider.changesSince(null);
      expect(changes.cursor, isNotEmpty);

      await provider.delete('k1');
      expect(await inner.list(''), hasLength(1));

      final q = await provider.quota();
      expect(q, isNotNull);

      await provider.close();
    });
  });
}
