// © 2026 Tephra. All rights reserved.

import 'package:tephra_sync/tephra_sync.dart';
import 'package:test/test.dart';

void main() {
  group('GcLease', () {
    test('serializes and deserializes cleanly with cipher', () async {
      final cipher = PlaintextObjectCipher();
      final hlc = Hlc(millis: 1729420000000, counter: 5, deviceId: 'dev-1');
      final lease = GcLease(
        deviceId: 'dev-1',
        hlc: hlc,
        createdAt: DateTime.utc(2026, 10, 20, 10, 0, 0),
      );

      final sealed = await lease.seal(cipher);
      final opened = await GcLease.open(sealed, cipher);

      expect(opened.version, 1);
      expect(opened.deviceId, 'dev-1');
      expect(opened.hlc, hlc);
      expect(opened.createdAt, DateTime.utc(2026, 10, 20, 10, 0, 0));
    });

    test('deterministic comparison: smallest (hlc, deviceId) wins', () {
      final hlc1 = Hlc(millis: 1000, counter: 1, deviceId: 'dev-a');
      final hlc2 = Hlc(millis: 1000, counter: 2, deviceId: 'dev-a');
      final hlc3 = Hlc(millis: 2000, counter: 0, deviceId: 'dev-a');

      final lease1 = GcLease(
        deviceId: 'dev-a',
        hlc: hlc1,
        createdAt: DateTime.utc(2026, 10, 20),
      );
      final lease2 = GcLease(
        deviceId: 'dev-b',
        hlc: hlc1,
        createdAt: DateTime.utc(2026, 10, 20),
      );
      final lease3 = GcLease(
        deviceId: 'dev-a',
        hlc: hlc2,
        createdAt: DateTime.utc(2026, 10, 20),
      );
      final lease4 = GcLease(
        deviceId: 'dev-a',
        hlc: hlc3,
        createdAt: DateTime.utc(2026, 10, 20),
      );

      // lease1 vs lease2: same HLC, 'dev-a' < 'dev-b' -> lease1 < lease2
      expect(lease1.compareTo(lease2), lessThan(0));
      expect(lease2.compareTo(lease1), greaterThan(0));

      // lease1 vs lease3: counter 1 < counter 2 -> lease1 < lease3
      expect(lease1.compareTo(lease3), lessThan(0));

      // lease3 vs lease4: millis 1000 < millis 2000 -> lease3 < lease4
      expect(lease3.compareTo(lease4), lessThan(0));

      final list = [lease4, lease2, lease3, lease1];
      list.sort();
      expect(list.first, lease1);
    });
  });
}
