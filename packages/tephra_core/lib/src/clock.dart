// © 2026 Tephra. All rights reserved.

abstract interface class Clock {
  DateTime now();
}

final class SystemClock implements Clock {
  const SystemClock();
  @override
  DateTime now() => DateTime.now();
}

/// Test clock; time only moves when [advance] or [set] is called.
final class ManualClock implements Clock {
  ManualClock(DateTime start) : _now = start;
  DateTime _now;
  @override
  DateTime now() => _now;
  void advance(Duration d) => _now = _now.add(d);
  void set(DateTime t) => _now = t;
}
