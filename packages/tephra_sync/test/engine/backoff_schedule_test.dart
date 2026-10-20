// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_sync/src/engine/backoff_schedule.dart';
import 'package:test/test.dart';

void main() {
  group('BackoffSchedule', () {
    late ManualClock clock;
    late BackoffSchedule schedule;

    setUp(() {
      clock = ManualClock(DateTime.utc(2026, 10, 20, 12, 0, 0));
      schedule = BackoffSchedule(clock: clock);
    });

    test('starts with 0 failures and ready to retry immediately', () {
      expect(schedule.failureCount, equals(0));
      expect(schedule.nextAttemptAt, isNull);
      expect(schedule.shouldRetryNow, isTrue);
      expect(schedule.currentDelay, equals(Duration.zero));
    });

    test('progresses through 30s, 1m, 2m, 5m, and caps at 5m', () {
      // 1st failure: 30s
      schedule.recordFailure();
      expect(schedule.failureCount, equals(1));
      expect(schedule.currentDelay, equals(const Duration(seconds: 30)));
      expect(
        schedule.nextAttemptAt,
        equals(DateTime.utc(2026, 10, 20, 12, 0, 30)),
      );
      expect(schedule.shouldRetryNow, isFalse);

      clock.advance(const Duration(seconds: 29));
      expect(schedule.shouldRetryNow, isFalse);
      clock.advance(const Duration(seconds: 1));
      expect(schedule.shouldRetryNow, isTrue);

      // 2nd failure: 1m
      schedule.recordFailure();
      expect(schedule.failureCount, equals(2));
      expect(schedule.currentDelay, equals(const Duration(minutes: 1)));
      expect(
        schedule.nextAttemptAt,
        equals(DateTime.utc(2026, 10, 20, 12, 1, 30)),
      );

      // 3rd failure: 2m
      clock.advance(const Duration(minutes: 1));
      schedule.recordFailure();
      expect(schedule.failureCount, equals(3));
      expect(schedule.currentDelay, equals(const Duration(minutes: 2)));

      // 4th failure: 5m
      clock.advance(const Duration(minutes: 2));
      schedule.recordFailure();
      expect(schedule.failureCount, equals(4));
      expect(schedule.currentDelay, equals(const Duration(minutes: 5)));

      // 5th failure: caps at 5m
      clock.advance(const Duration(minutes: 5));
      schedule.recordFailure();
      expect(schedule.failureCount, equals(5));
      expect(schedule.currentDelay, equals(const Duration(minutes: 5)));

      // 6th failure: still 5m
      clock.advance(const Duration(minutes: 5));
      schedule.recordFailure();
      expect(schedule.failureCount, equals(6));
      expect(schedule.currentDelay, equals(const Duration(minutes: 5)));
    });

    test('reset clears failures and next attempt', () {
      schedule.recordFailure();
      schedule.recordFailure();
      expect(schedule.failureCount, equals(2));
      expect(schedule.nextAttemptAt, isNotNull);

      schedule.reset();
      expect(schedule.failureCount, equals(0));
      expect(schedule.nextAttemptAt, isNull);
      expect(schedule.shouldRetryNow, isTrue);
    });
  });
}
