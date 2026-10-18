// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:logging/logging.dart';

final class PerfResult {
  const PerfResult({
    required this.name,
    required this.value,
    required this.unit,
  });

  final String name;
  final double value;
  final String unit;

  @override
  String toString() => 'PerfResult($name: $value $unit)';
}

abstract final class PerfProbe {
  static const bool enabled = bool.fromEnvironment('TEPHRA_PERF');

  static Stopwatch? _appStartWatch;
  static final Set<String> _marked = {};
  static final List<PerfResult> _results = [];
  static StreamSubscription<LogRecord>? _logSub;

  static void markAppStart() {
    if (!enabled) return;
    _appStartWatch ??= Stopwatch()..start();
  }

  static void mark(String name) {
    if (!enabled) return;
    if (_marked.add(name)) {
      final elapsed = _appStartWatch?.elapsedMicroseconds;
      if (elapsed != null) {
        record(name, elapsed / 1000.0, 'ms');
      }
    }
  }

  static Future<T> measure<T>(String name, Future<T> Function() body) async {
    if (!enabled) return body();
    final sw = Stopwatch()..start();
    try {
      return await body();
    } finally {
      sw.stop();
      record(name, sw.elapsedMicroseconds / 1000.0, 'ms');
    }
  }

  static void record(String name, double value, String unit) {
    if (!enabled) return;
    _results.add(PerfResult(name: name, value: value, unit: unit));

    // Formatted with at most 3 decimals
    final formatted = _formatValue(value);
    // ignore: avoid_print
    print('PERF $name $formatted $unit');
  }

  static String _formatValue(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    final fixed = value.toStringAsFixed(3);
    return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  static List<PerfResult> get results => List.unmodifiable(_results);

  static (String, double, String)? parseLogMessage(String message) {
    final trimmed = message.trim();
    if (!trimmed.toLowerCase().startsWith('perf ')) {
      return null;
    }
    final after = trimmed.substring(5).trim();
    final parts = after.split(RegExp(r'\s+'));
    if (parts.length < 2) {
      return null;
    }
    final name = parts[0];
    final numStr = parts[1].replaceAll(RegExp(r'[^\d.-]'), '');
    final val = double.tryParse(numStr);
    if (val == null) {
      return null;
    }
    final unit = parts.length >= 3 ? parts[2] : 'ms';
    return (name, val, unit);
  }

  static void installLogBridge() {
    if (!enabled) return;
    _logSub?.cancel();
    _logSub = Logger.root.onRecord.listen((rec) {
      final parsed = parseLogMessage(rec.message);
      if (parsed != null) {
        record(parsed.$1, parsed.$2, parsed.$3);
      }
    });
  }

  static void reset() {
    _marked.clear();
    _results.clear();
    _appStartWatch = null;
  }
}
