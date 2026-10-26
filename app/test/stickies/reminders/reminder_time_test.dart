// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/stickies/model/sticky_meta.dart';
import 'package:tephra/stickies/reminders/reminder_time.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(() {
    tz.initializeTimeZones();
  });

  group('resolveWallTime', () {
    test('Asia/Dhaka plain time', () {
      final loc = tz.getLocation('Asia/Dhaka');
      const time = LocalDateTime(2026, 10, 12, 9, 0);
      final instant = resolveWallTime(time, loc);
      expect(instant, equals(DateTime.utc(2026, 10, 12, 3, 0)));
    });

    test('New York spring-forward gap', () {
      final loc = tz.getLocation('America/New_York');
      // 02:30 does not exist on 2026-03-08 in NY (clocks jump 02:00 -> 03:00)
      const time = LocalDateTime(2026, 3, 8, 2, 30);
      final instant = resolveWallTime(time, loc);
      // Lands at 03:30 EDT = 07:30 UTC
      expect(instant, equals(DateTime.utc(2026, 3, 8, 7, 30)));
    });

    test('New York fall-back overlap picks first', () {
      final loc = tz.getLocation('America/New_York');
      // 01:30 occurs twice on 2026-11-01 (EDT and EST)
      const time = LocalDateTime(2026, 11, 1, 1, 30);
      final instant = resolveWallTime(time, loc);
      // First occurrence is EDT (UTC-4) -> 05:30 UTC
      expect(instant, equals(DateTime.utc(2026, 11, 1, 5, 30)));
    });

    test('London summer time', () {
      final loc = tz.getLocation('Europe/London');
      const time = LocalDateTime(2026, 7, 1, 9, 0);
      final instant = resolveWallTime(time, loc);
      // BST is UTC+1 -> 08:00 UTC
      expect(instant, equals(DateTime.utc(2026, 7, 1, 8, 0)));
    });

    test('Sydney southern DST', () {
      final loc = tz.getLocation('Australia/Sydney');
      // Sydney springs forward on first Sunday of October (2026-10-04, 02:00 -> 03:00)
      const time = LocalDateTime(2026, 10, 4, 2, 30);
      final instant = resolveWallTime(time, loc);
      // Gap: shifted forward to 03:30 AEDT (UTC+11) = 2026-10-03 16:30 UTC
      expect(instant, equals(DateTime.utc(2026, 10, 3, 16, 30)));
    });

    test('UTC identity', () {
      final loc = tz.getLocation('UTC');
      const time = LocalDateTime(2026, 10, 12, 9, 0);
      final instant = resolveWallTime(time, loc);
      expect(instant, equals(DateTime.utc(2026, 10, 12, 9, 0)));
    });
  });
}
