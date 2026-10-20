// © 2026 Tephra. All rights reserved.

import 'package:tephra_sync/tephra_sync.dart';
import 'package:test/test.dart';

void main() {
  group('BackupSchedule', () {
    test('frequency string parsing and serialization', () {
      expect(
        BackupScheduleFrequency.fromString('off'),
        equals(BackupScheduleFrequency.off),
      );
      expect(
        BackupScheduleFrequency.fromString('hourly'),
        equals(BackupScheduleFrequency.hourly),
      );
      expect(
        BackupScheduleFrequency.fromString('daily'),
        equals(BackupScheduleFrequency.daily),
      );
      expect(
        BackupScheduleFrequency.fromString('weekly'),
        equals(BackupScheduleFrequency.weekly),
      );
      expect(
        BackupScheduleFrequency.fromString('unknown'),
        equals(BackupScheduleFrequency.off),
      );
      expect(
        BackupScheduleFrequency.fromString(null),
        equals(BackupScheduleFrequency.off),
      );
      expect(BackupScheduleFrequency.hourly.toJson(), equals('hourly'));
    });

    test('off schedule is never due', () {
      final now = DateTime.utc(2026, 10, 20, 12, 0, 0);
      expect(
        BackupSchedule.isDue(now, null, BackupScheduleFrequency.off),
        isFalse,
      );
      expect(
        BackupSchedule.isDue(
          now,
          now.subtract(const Duration(days: 30)),
          BackupScheduleFrequency.off,
        ),
        isFalse,
      );
    });

    test('hourly schedule table (UTC)', () {
      final now = DateTime.utc(2026, 10, 20, 12, 0, 0);

      // Never backed up -> due
      expect(
        BackupSchedule.isDue(now, null, BackupScheduleFrequency.hourly),
        isTrue,
      );

      // 59 minutes elapsed -> not due
      expect(
        BackupSchedule.isDue(
          now,
          now.subtract(const Duration(minutes: 59)),
          BackupScheduleFrequency.hourly,
        ),
        isFalse,
      );

      // Exactly 60 minutes elapsed -> due
      expect(
        BackupSchedule.isDue(
          now,
          now.subtract(const Duration(minutes: 60)),
          BackupScheduleFrequency.hourly,
        ),
        isTrue,
      );

      // 2 hours elapsed -> due
      expect(
        BackupSchedule.isDue(
          now,
          now.subtract(const Duration(hours: 2)),
          BackupScheduleFrequency.hourly,
        ),
        isTrue,
      );
    });

    test('daily schedule 24-hour elapsed fallback (UTC)', () {
      final now = DateTime.utc(2026, 10, 20, 12, 0, 0);

      // Never backed up -> due
      expect(
        BackupSchedule.isDue(now, null, BackupScheduleFrequency.daily),
        isTrue,
      );

      // 23 hours elapsed, same local day if mock matched -> test >= 24h
      expect(
        BackupSchedule.isDue(
          now,
          now.subtract(const Duration(hours: 24)),
          BackupScheduleFrequency.daily,
        ),
        isTrue,
      );

      expect(
        BackupSchedule.isDue(
          now,
          now.subtract(const Duration(hours: 25)),
          BackupScheduleFrequency.daily,
        ),
        isTrue,
      );
    });

    test('daily schedule local-time 03:00 date-advance test', () {
      // Local time test: create DateTime in local zone
      final localLast = DateTime(
        2026,
        10,
        19,
        22,
        0,
        0,
      ); // Yesterday 10 PM local

      // Today 02:59 AM local (elapsed = 4h 59m, local date changed, but hour < 3) -> not due
      final localEarly = DateTime(2026, 10, 20, 2, 59, 0);
      expect(
        BackupSchedule.isDue(
          localEarly,
          localLast,
          BackupScheduleFrequency.daily,
        ),
        isFalse,
      );

      // Today 03:00 AM local (elapsed = 5h, local date changed, hour >= 3) -> due
      final localDue = DateTime(2026, 10, 20, 3, 0, 0);
      expect(
        BackupSchedule.isDue(
          localDue,
          localLast,
          BackupScheduleFrequency.daily,
        ),
        isTrue,
      );

      // Already backed up today at 03:05 AM -> at 03:10 AM local date has not changed and elapsed < 24h -> not due
      final localRanToday = DateTime(2026, 10, 20, 3, 5, 0);
      final localLater = DateTime(2026, 10, 20, 3, 10, 0);
      expect(
        BackupSchedule.isDue(
          localLater,
          localRanToday,
          BackupScheduleFrequency.daily,
        ),
        isFalse,
      );
    });

    test('weekly schedule table', () {
      final now = DateTime.utc(2026, 10, 20, 12, 0, 0);

      // Never backed up -> due
      expect(
        BackupSchedule.isDue(now, null, BackupScheduleFrequency.weekly),
        isTrue,
      );

      // 6 days 23 hours elapsed -> not due
      expect(
        BackupSchedule.isDue(
          now,
          now.subtract(const Duration(days: 6, hours: 23)),
          BackupScheduleFrequency.weekly,
        ),
        isFalse,
      );

      // Exactly 7 days elapsed -> due
      expect(
        BackupSchedule.isDue(
          now,
          now.subtract(const Duration(days: 7)),
          BackupScheduleFrequency.weekly,
        ),
        isTrue,
      );

      // 8 days elapsed -> due
      expect(
        BackupSchedule.isDue(
          now,
          now.subtract(const Duration(days: 8)),
          BackupScheduleFrequency.weekly,
        ),
        isTrue,
      );
    });
  });
}
