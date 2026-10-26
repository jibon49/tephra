// © 2026 Tephra. All rights reserved.

import 'package:timezone/timezone.dart' as tz;

import '../model/sticky_meta.dart';

/// Returns the UTC instant for wall-clock [t] in [location].
///
/// Gap (time does not exist, spring forward): shift forward by the gap length (02:30 → 03:30 on a 1-hour gap).
/// Overlap (time exists twice, fall back): the earlier instant (the first occurrence).
DateTime resolveWallTime(LocalDateTime t, tz.Location location) {
  // 1. n = DateTime.utc(t.year, t.month, t.day, t.hour, t.minute).millisecondsSinceEpoch
  final n = DateTime.utc(
    t.year,
    t.month,
    t.day,
    t.hour,
    t.minute,
  ).millisecondsSinceEpoch;

  // 2. oBefore = location.timeZone(n - 86400000).offset, oAfter = location.timeZone(n + 86400000).offset
  final oBefore = location.timeZone(n - 86400000).offset;
  final oAfter = location.timeZone(n + 86400000).offset;

  // 3. Candidates: for each distinct o in {oBefore, oAfter}: u = n - o; valid if location.timeZone(u).offset == o
  // Note: timezone package offset is a Duration.
  final offsets = <Duration>{oBefore, oAfter};
  final validCandidates = <int>[];
  for (final o in offsets) {
    final u = n - o.inMilliseconds;
    if (location.timeZone(u).offset == o) {
      validCandidates.add(u);
    }
  }

  // 4. If one or more valid -> return the smallest u as DateTime.fromMillisecondsSinceEpoch(u, isUtc: true)
  if (validCandidates.isNotEmpty) {
    validCandidates.sort();
    return DateTime.fromMillisecondsSinceEpoch(
      validCandidates.first,
      isUtc: true,
    );
  }

  // 5. If none valid (gap) -> return n - oBefore (lands after the transition, i.e. shifted forward by the gap)
  return DateTime.fromMillisecondsSinceEpoch(
    n - oBefore.inMilliseconds,
    isUtc: true,
  );
}
