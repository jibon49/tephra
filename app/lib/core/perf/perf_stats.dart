// © 2026 Tephra. All rights reserved.

import 'dart:math' as math;
import 'dart:ui';

final class FrameStats {
  const FrameStats({
    required this.count,
    required this.p50,
    required this.p90,
    required this.p95,
    required this.p99,
    required this.max,
    required this.over16,
  });

  final int count;
  final double p50;
  final double p90;
  final double p95;
  final double p99;
  final double max;
  final int over16;

  @override
  String toString() =>
      'FrameStats(count: $count, p50: ${p50.toStringAsFixed(1)}ms, p95: ${p95.toStringAsFixed(1)}ms, max: ${max.toStringAsFixed(1)}ms, over16: $over16)';
}

/// Calculates the nearest-rank percentile [p] (0..100) from [values].
double percentile(List<double> values, double p) {
  if (values.isEmpty) {
    throw ArgumentError('values must not be empty');
  }
  final sorted = List<double>.of(values)..sort();
  final n = sorted.length;
  final rank = (p / 100.0 * n).ceil();
  final index = (rank - 1).clamp(0, n - 1);
  return sorted[index];
}

/// Computes frame build and raster latency statistics from [timings].
FrameStats frameStats(List<FrameTiming> timings) {
  if (timings.isEmpty) {
    return const FrameStats(
      count: 0,
      p50: 0,
      p90: 0,
      p95: 0,
      p99: 0,
      max: 0,
      over16: 0,
    );
  }

  final durations = <double>[];
  var over16Count = 0;

  for (final t in timings) {
    final frameMs =
        math.max(
          t.buildDuration.inMicroseconds,
          t.rasterDuration.inMicroseconds,
        ) /
        1000.0;
    durations.add(frameMs);
    if (frameMs > 16.0) {
      over16Count++;
    }
  }

  durations.sort();
  return FrameStats(
    count: durations.length,
    p50: percentile(durations, 50),
    p90: percentile(durations, 90),
    p95: percentile(durations, 95),
    p99: percentile(durations, 99),
    max: durations.last,
    over16: over16Count,
  );
}
