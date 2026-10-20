// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

/// Backoff schedule for offline and network failures during sync cycles.
///
/// Schedule: 30 s, 1 min, 2 min, 5 min, then every 5 min thereafter.
class BackoffSchedule {
  BackoffSchedule({this._clock = const SystemClock()});

  final Clock _clock;
  int _consecutiveFailures = 0;
  DateTime? _nextAttemptAt;

  static const List<Duration> steps = [
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 2),
    Duration(minutes: 5),
  ];

  static const Duration maxDelay = Duration(minutes: 5);

  int get failureCount => _consecutiveFailures;
  DateTime? get nextAttemptAt => _nextAttemptAt;

  bool get shouldRetryNow {
    final next = _nextAttemptAt;
    if (next == null) return true;
    final now = _clock.now();
    return now.isAfter(next) || now.isAtSameMomentAs(next);
  }

  Duration get currentDelay {
    if (_consecutiveFailures == 0) return Duration.zero;
    final index = _consecutiveFailures - 1;
    if (index < steps.length) {
      return steps[index];
    }
    return maxDelay;
  }

  void recordFailure() {
    _consecutiveFailures++;
    final delay = currentDelay;
    _nextAttemptAt = _clock.now().add(delay);
  }

  void reset() {
    _consecutiveFailures = 0;
    _nextAttemptAt = null;
  }
}
