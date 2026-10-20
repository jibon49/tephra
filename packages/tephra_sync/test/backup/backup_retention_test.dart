// © 2026 Tephra. All rights reserved.

import 'package:tephra_sync/tephra_sync.dart';
import 'package:test/test.dart';

void main() {
  group('BackupRetention', () {
    test('empty stamps returns empty set', () {
      expect(BackupRetention.select([]), isEmpty);
    });

    test('always keeps newest backup', () {
      final t1 = DateTime.utc(2025, 1, 1, 10, 0, 0);
      final t2 = DateTime.utc(2025, 1, 1, 12, 0, 0);
      final kept = BackupRetention.select(
        [t1, t2],
        hourly: 1,
        daily: 1,
        monthly: 1,
      );
      expect(kept.contains(t2), isTrue);
    });

    test('hourly backups for 400 days retains 48 hourly + 30 daily + 12 monthly buckets exactly', () {
      final now = DateTime.utc(2026, 10, 20, 12, 0, 0);
      final stamps = <DateTime>[];

      // 400 days of hourly backups = 9,600 backups
      for (var h = 0; h < 400 * 24; h++) {
        stamps.add(now.subtract(Duration(hours: h)));
      }
      expect(stamps.length, equals(9600));

      final kept = BackupRetention.select(
        stamps,
        hourly: 48,
        daily: 30,
        monthly: 12,
        now: now,
      );

      // Newest backup is preserved
      expect(kept.contains(stamps.first), isTrue);

      // 1. Verify 48 most recent distinct hour buckets are each represented
      final keptHourBuckets = kept
          .map((dt) => '${dt.year}-${dt.month}-${dt.day}-${dt.hour}')
          .toSet();
      for (var h = 0; h < 48; h++) {
        final expected = stamps[h];
        final key =
            '${expected.year}-${expected.month}-${expected.day}-${expected.hour}';
        expect(
          keptHourBuckets.contains(key),
          isTrue,
          reason: 'Hour bucket $key must be preserved',
        );
      }

      // 2. Verify 30 most recent distinct day buckets are each represented
      final keptDayBuckets = kept
          .map((dt) => '${dt.year}-${dt.month}-${dt.day}')
          .toSet();
      final seenDays = <String>{};
      for (final s in stamps) {
        final key = '${s.year}-${s.month}-${s.day}';
        seenDays.add(key);
        if (seenDays.length <= 30) {
          expect(
            keptDayBuckets.contains(key),
            isTrue,
            reason: 'Day bucket $key must be preserved',
          );
        }
      }

      // 3. Verify 12 most recent distinct month buckets are each represented
      final keptMonthBuckets = kept
          .map((dt) => '${dt.year}-${dt.month}')
          .toSet();
      final seenMonths = <String>{};
      for (final s in stamps) {
        final key = '${s.year}-${s.month}';
        seenMonths.add(key);
        if (seenMonths.length <= 12) {
          expect(
            keptMonthBuckets.contains(key),
            isTrue,
            reason: 'Month bucket $key must be preserved',
          );
        }
      }

      // Out of 9,600 backups, retention kept a lean union (approx 80-90 backups)
      expect(kept.length, greaterThanOrEqualTo(48));
      expect(kept.length, lessThan(100));
    });

    test('preserves preRestore backups younger than 30 days', () {
      final now = DateTime.utc(2026, 10, 20, 12, 0, 0);

      // A pre-restore backup from 5 days ago at 10:15 (not the newest of that day)
      final preRestoreYoung = DateTime.utc(2026, 10, 15, 10, 15, 0);
      // Another backup on the same day at 23:00 (newest of that day)
      final regularNewestOfDay = DateTime.utc(2026, 10, 15, 23, 0, 0);

      // An old pre-restore backup from 45 days ago
      final preRestoreOld = DateTime.utc(2026, 9, 1, 10, 0, 0);
      final regularOldNewestOfMonth = DateTime.utc(2026, 9, 30, 23, 0, 0);

      final allStamps = [
        now,
        regularNewestOfDay,
        preRestoreYoung,
        regularOldNewestOfMonth,
        preRestoreOld,
      ];

      final kept = BackupRetention.select(
        allStamps,
        hourly: 1, // Only keeps `now` in hourly
        daily: 2, // Keeps `now` (today) and `regularNewestOfDay` (5 days ago)
        monthly: 2, // Keeps `now` (Oct) and `regularOldNewestOfMonth` (Sept)
        preRestoreStamps: [preRestoreYoung, preRestoreOld],
        now: now,
      );

      // `preRestoreYoung` is kept because it is < 30 days old
      expect(kept.contains(preRestoreYoung), isTrue);

      // `preRestoreOld` is NOT kept because it is > 30 days old and not the newest in Sept
      expect(kept.contains(preRestoreOld), isFalse);

      // The regular newest backups are kept
      expect(kept.contains(now), isTrue);
      expect(kept.contains(regularNewestOfDay), isTrue);
      expect(kept.contains(regularOldNewestOfMonth), isTrue);
    });

    test('selectManifests filters by stamp strings', () {
      final now = DateTime.utc(2026, 10, 20, 12, 0, 0);
      final m1 = BackupManifest(
        vaultId: 'v1',
        createdAt: now,
        deviceId: 'd1',
        deviceName: 'Device',
        kind: BackupKind.manual,
        fileCount: 1,
        totalBytes: 10,
        files: const [],
      );

      final keptStamps = BackupRetention.selectManifests([m1]);
      expect(keptStamps, contains(m1.stamp));
    });
  });
}
