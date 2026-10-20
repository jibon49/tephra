// © 2026 Tephra. All rights reserved.

import 'dart:math';

import 'package:logging/logging.dart';
import 'package:tephra_core/tephra_core.dart';

final _logger = Logger('HlcClock');

/// Immutable Hybrid Logical Clock (HLC) timestamp.
///
/// Combines physical time ([millis]), a logical [counter] for causality breaking,
/// and a unique [deviceId] for deterministic total ordering.
final class Hlc implements Comparable<Hlc> {
  /// Creates an [Hlc].
  const Hlc({
    required this.millis,
    required this.counter,
    required this.deviceId,
  });

  /// Parses an [Hlc] from its canonical sortable string representation.
  ///
  /// Expected format: `15-digit millis . 6-digit counter . deviceId`.
  factory Hlc.parse(String s) {
    final firstDot = s.indexOf('.');
    if (firstDot == -1) {
      throw FormatException('Invalid HLC string: $s');
    }
    final secondDot = s.indexOf('.', firstDot + 1);
    if (secondDot == -1) {
      throw FormatException('Invalid HLC string: $s');
    }

    final millis = int.parse(s.substring(0, firstDot));
    final counter = int.parse(s.substring(firstDot + 1, secondDot));
    final deviceId = s.substring(secondDot + 1);

    return Hlc(millis: millis, counter: counter, deviceId: deviceId);
  }

  /// Milliseconds since UTC epoch.
  final int millis;

  /// Monotonic counter within the same millisecond.
  final int counter;

  /// Identifier of the originating device.
  final String deviceId;

  /// Canonical sortable string representation: `millis.counter.deviceId`.
  ///
  /// `millis` is zero-padded to 15 digits; `counter` is zero-padded to 6 digits.
  String get encoded {
    final m = millis.toString().padLeft(15, '0');
    final c = counter.toString().padLeft(6, '0');
    return '$m.$c.$deviceId';
  }

  @override
  int compareTo(Hlc other) {
    var cmp = millis.compareTo(other.millis);
    if (cmp != 0) return cmp;
    cmp = counter.compareTo(other.counter);
    if (cmp != 0) return cmp;
    return deviceId.compareTo(other.deviceId);
  }

  bool operator <(Hlc other) => compareTo(other) < 0;
  bool operator <=(Hlc other) => compareTo(other) <= 0;
  bool operator >(Hlc other) => compareTo(other) > 0;
  bool operator >=(Hlc other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Hlc &&
          runtimeType == other.runtimeType &&
          millis == other.millis &&
          counter == other.counter &&
          deviceId == other.deviceId;

  @override
  int get hashCode => Object.hash(millis, counter, deviceId);

  @override
  String toString() => encoded;
}

/// State machine generating and observing Hybrid Logical Clock timestamps.
final class HlcClock {
  /// Creates an [HlcClock].
  HlcClock({
    required this.clock,
    required this.deviceId,
    this.millis = 0,
    this.counter = 0,
    this.onPersist,
  });

  /// Underlying wall clock.
  final Clock clock;

  /// Local device identifier.
  final String deviceId;

  /// Optional callback invoked whenever clock state changes.
  final void Function(int millis, int counter)? onPersist;

  /// Current logical millisecond timestamp.
  int millis;

  /// Current logical counter.
  int counter;

  /// Generates a new [Hlc] for a local event or message send.
  ///
  /// Advances the logical time ensuring strict monotonicity even if physical
  /// clock moves backwards.
  Hlc tick() {
    final pt = clock.now().toUtc().millisecondsSinceEpoch;
    final l2 = max(millis, pt);
    final c2 = (l2 == millis) ? counter + 1 : 0;

    millis = l2;
    counter = c2;
    onPersist?.call(millis, counter);

    return Hlc(millis: l2, counter: c2, deviceId: deviceId);
  }

  /// Updates clock state upon receiving a remote [m] timestamp.
  void observe(Hlc m) {
    final pt = clock.now().toUtc().millisecondsSinceEpoch;
    final l2 = [millis, m.millis, pt].reduce(max);

    final int c2;
    if (l2 == millis && l2 == m.millis) {
      c2 = max(counter, m.counter) + 1;
    } else if (l2 == millis) {
      c2 = counter + 1;
    } else if (l2 == m.millis) {
      c2 = m.counter + 1;
    } else {
      c2 = 0;
    }

    if (m.millis > pt + const Duration(hours: 24).inMilliseconds) {
      _logger.warning(
        'Remote clock far ahead: ${m.millis} vs local pt $pt from device ${m.deviceId}',
      );
    }

    millis = l2;
    counter = c2;
    onPersist?.call(millis, counter);
  }
}
