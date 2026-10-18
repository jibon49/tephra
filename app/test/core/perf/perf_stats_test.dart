// © 2026 Tephra. All rights reserved.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/core/perf/perf_stats.dart';

void main() {
  group('percentile', () {
    test('percentile([1..100], 95) == 95', () {
      final list = List.generate(100, (i) => (i + 1).toDouble());
      expect(percentile(list, 95), 95.0);
    });

    test('percentile([5], 99) == 5', () {
      expect(percentile([5.0], 99), 5.0);
    });

    test('percentile([], 50) throws ArgumentError', () {
      expect(() => percentile([], 50), throwsArgumentError);
    });
  });

  group('frameStats', () {
    test('over 4 fake timings counts the one over 16.0 ms', () {
      final timings = <FrameTiming>[
        FrameTiming(
          vsyncStart: 0,
          buildStart: 0,
          buildFinish: 8000,
          rasterStart: 8000,
          rasterFinish: 14000,
          rasterFinishWallTime: 0,
        ),
        FrameTiming(
          vsyncStart: 0,
          buildStart: 0,
          buildFinish: 10000,
          rasterStart: 10000,
          rasterFinish: 15000,
          rasterFinishWallTime: 0,
        ),
        FrameTiming(
          vsyncStart: 0,
          buildStart: 0,
          buildFinish: 20000, // 20ms > 16.0ms
          rasterStart: 20000,
          rasterFinish: 22000,
          rasterFinishWallTime: 0,
        ),
        FrameTiming(
          vsyncStart: 0,
          buildStart: 0,
          buildFinish: 5000,
          rasterStart: 5000,
          rasterFinish: 9000,
          rasterFinishWallTime: 0,
        ),
      ];

      final stats = frameStats(timings);
      expect(stats.count, 4);
      expect(stats.over16, 1);
      expect(stats.max, 20.0);
    });
  });
}
