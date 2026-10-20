// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_sync/tephra_sync.dart';
import 'package:test/test.dart';

void main() {
  group('Hlc and HlcClock', () {
    test('string ordering equals tuple ordering', () {
      final list = [
        const Hlc(millis: 100, counter: 0, deviceId: 'a'),
        const Hlc(millis: 100, counter: 0, deviceId: 'b'),
        const Hlc(millis: 100, counter: 1, deviceId: 'a'),
        const Hlc(millis: 100, counter: 1, deviceId: 'b'),
        const Hlc(millis: 200, counter: 0, deviceId: 'a'),
        const Hlc(millis: 200, counter: 5, deviceId: 'z'),
        const Hlc(millis: 1000000, counter: 999, deviceId: 'dev-1'),
      ];

      for (var i = 0; i < list.length; i++) {
        for (var j = 0; j < list.length; j++) {
          final a = list[i];
          final b = list[j];
          final tupleCmp = a.compareTo(b);
          final strCmp = a.encoded.compareTo(b.encoded);
          expect(
            strCmp.sign,
            equals(tupleCmp.sign),
            reason:
                'Mismatch between tuple cmp ($tupleCmp) and string cmp ($strCmp) for $a vs $b',
          );
        }
      }
    });

    test('Hlc parse round trip', () {
      const original = Hlc(
        millis: 1760175000000,
        counter: 42,
        deviceId: 'dev-uuid-1234',
      );
      final encoded = original.encoded;
      expect(encoded, equals('001760175000000.000042.dev-uuid-1234'));

      final parsed = Hlc.parse(encoded);
      expect(parsed, equals(original));
      expect(parsed.millis, equals(1760175000000));
      expect(parsed.counter, equals(42));
      expect(parsed.deviceId, equals('dev-uuid-1234'));
    });

    test('monotonic under a clock that goes backwards', () {
      final clock = ManualClock(
        DateTime.fromMillisecondsSinceEpoch(1000000, isUtc: true),
      );
      final hlcClock = HlcClock(clock: clock, deviceId: 'dev1');

      final t1 = hlcClock.tick();
      expect(t1.millis, equals(1000000));
      expect(t1.counter, equals(0));

      // Physical clock goes backwards 100 seconds
      clock.set(DateTime.fromMillisecondsSinceEpoch(900000, isUtc: true));

      final t2 = hlcClock.tick();
      expect(t2.millis, equals(1000000)); // Keeps highest seen millis
      expect(t2.counter, equals(1)); // Increments counter
      expect(t2 > t1, isTrue);

      final t3 = hlcClock.tick();
      expect(t3.millis, equals(1000000));
      expect(t3.counter, equals(2));
      expect(t3 > t2, isTrue);

      // Physical clock advances past previous peak
      clock.set(DateTime.fromMillisecondsSinceEpoch(1000001, isUtc: true));

      final t4 = hlcClock.tick();
      expect(t4.millis, equals(1000001));
      expect(t4.counter, equals(0)); // Resets counter to 0 on new millisecond
      expect(t4 > t3, isTrue);
    });

    group('observe rules (all four branches)', () {
      test('Branch 1: l2 == l && l2 == m.millis -> c2 = max(c, m.counter) + 1', () {
        // Local clock at 5000, counter at 2
        final clock = ManualClock(
          DateTime.fromMillisecondsSinceEpoch(5000, isUtc: true),
        );
        final hlcClock = HlcClock(
          clock: clock,
          deviceId: 'local',
          millis: 5000,
          counter: 2,
        );

        // Remote message has millis 5000, counter 7 (pt=5000 == l == m.millis)
        const remote = Hlc(millis: 5000, counter: 7, deviceId: 'remote');
        hlcClock.observe(remote);

        expect(hlcClock.millis, equals(5000));
        expect(hlcClock.counter, equals(8)); // max(2, 7) + 1
      });

      test('Branch 2: l2 == l (local time dominates) -> c2 = c + 1', () {
        // Local logical time 6000, counter 3. Physical clock at 4000.
        final clock = ManualClock(
          DateTime.fromMillisecondsSinceEpoch(4000, isUtc: true),
        );
        final hlcClock = HlcClock(
          clock: clock,
          deviceId: 'local',
          millis: 6000,
          counter: 3,
        );

        // Remote message has millis 5000 (< local 6000)
        const remote = Hlc(millis: 5000, counter: 10, deviceId: 'remote');
        hlcClock.observe(remote);

        expect(hlcClock.millis, equals(6000));
        expect(hlcClock.counter, equals(4)); // c + 1
      });

      test('Branch 3: l2 == m.millis (remote time dominates) -> c2 = m.counter + 1', () {
        // Local logical time 4000, counter 3. Physical clock at 4000.
        final clock = ManualClock(
          DateTime.fromMillisecondsSinceEpoch(4000, isUtc: true),
        );
        final hlcClock = HlcClock(
          clock: clock,
          deviceId: 'local',
          millis: 4000,
          counter: 3,
        );

        // Remote message has millis 8000 (> local 4000, > pt 4000)
        const remote = Hlc(millis: 8000, counter: 15, deviceId: 'remote');
        hlcClock.observe(remote);

        expect(hlcClock.millis, equals(8000));
        expect(hlcClock.counter, equals(16)); // m.counter + 1
      });

      test('Branch 4: else (physical time strictly dominates) -> c2 = 0', () {
        // Local logical time 3000, counter 5. Remote message at 3500, counter 10.
        // Physical clock jumps ahead to 9000.
        final clock = ManualClock(
          DateTime.fromMillisecondsSinceEpoch(9000, isUtc: true),
        );
        final hlcClock = HlcClock(
          clock: clock,
          deviceId: 'local',
          millis: 3000,
          counter: 5,
        );

        const remote = Hlc(millis: 3500, counter: 10, deviceId: 'remote');
        hlcClock.observe(remote);

        expect(hlcClock.millis, equals(9000));
        expect(hlcClock.counter, equals(0)); // Reset to 0
      });
    });
  });
}
