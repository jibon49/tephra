// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class BenchmarkMetrics {
  const BenchmarkMetrics({
    required this.count,
    required this.buildP50,
    required this.buildP90,
    required this.buildP95,
    required this.buildP99,
    required this.buildMax,
    required this.rasterP50,
    required this.rasterP90,
    required this.rasterP95,
    required this.rasterP99,
    required this.rasterMax,
    required this.framesOver16,
    required this.scrollFrames,
    required this.scrollFps,
    required this.scrollP95,
  });

  final int count;
  final double buildP50;
  final double buildP90;
  final double buildP95;
  final double buildP99;
  final double buildMax;

  final double rasterP50;
  final double rasterP90;
  final double rasterP95;
  final double rasterP99;
  final double rasterMax;

  final int framesOver16;

  final int scrollFrames;
  final double scrollFps;
  final double scrollP95;

  String formatSummary(String name, String platform) {
    return 'SPIKE $name $platform typing build_p95=${buildP95.toStringAsFixed(2)} '
        'raster_p95=${rasterP95.toStringAsFixed(2)} max=${max(buildMax, rasterMax).toStringAsFixed(2)} '
        'over16=$framesOver16 | scroll fps=${scrollFps.toStringAsFixed(1)} p95=${scrollP95.toStringAsFixed(2)}';
  }
}

double _percentile(List<double> values, double p) {
  if (values.isEmpty) return 0.0;
  final index = (p * (values.length - 1)).round();
  return values[index.clamp(0, values.length - 1)];
}

class BenchmarkRunner {
  static Future<BenchmarkMetrics> run({
    required BuildContext context,
    required String name,
    required ScrollController scrollController,
    required Future<void> Function() prepareTypingPosition,
    required Future<void> Function(String char) insertChar,
    bool showModalDialog = true,
    int charCount = 500,
  }) async {
    // 1. Prepare Typing
    await prepareTypingPosition();
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final timings = <FrameTiming>[];
    void onFrameTiming(List<FrameTiming> list) {
      timings.addAll(list);
    }

    SchedulerBinding.instance.addTimingsCallback(onFrameTiming);

    const testText = 'The quick brown fox jumps over the lazy dog. ';
    for (var i = 0; i < charCount; i++) {
      final ch = testText[i % testText.length];
      await insertChar(ch);
      await SchedulerBinding.instance.endOfFrame.timeout(
        const Duration(milliseconds: 50),
        onTimeout: () {},
      );
    }

    await Future<void>.delayed(const Duration(seconds: 1));
    SchedulerBinding.instance.removeTimingsCallback(onFrameTiming);

    final buildTimes = timings.map((t) => t.buildDuration.inMicroseconds / 1000.0).toList()..sort();
    final rasterTimes = timings.map((t) => t.rasterDuration.inMicroseconds / 1000.0).toList()..sort();

    var over16 = 0;
    for (final t in timings) {
      final b = t.buildDuration.inMicroseconds / 1000.0;
      final r = t.rasterDuration.inMicroseconds / 1000.0;
      if (max(b, r) > 16.0) {
        over16++;
      }
    }

    // 2. Scrolling Benchmark
    final scrollTimings = <FrameTiming>[];
    void onScrollTiming(List<FrameTiming> list) {
      scrollTimings.addAll(list);
    }

    if (scrollController.hasClients) {
      scrollController.jumpTo(0);
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));

    SchedulerBinding.instance.addTimingsCallback(onScrollTiming);

    if (scrollController.hasClients) {
      final maxScroll = scrollController.position.maxScrollExtent;
      await scrollController.animateTo(
        maxScroll,
        duration: const Duration(seconds: 5),
        curve: Curves.linear,
      );
    }

    await Future<void>.delayed(const Duration(milliseconds: 200));
    SchedulerBinding.instance.removeTimingsCallback(onScrollTiming);

    final scrollMaxes = scrollTimings.map((t) {
      final b = t.buildDuration.inMicroseconds / 1000.0;
      final r = t.rasterDuration.inMicroseconds / 1000.0;
      return max(b, r);
    }).toList()..sort();

    final platformName = defaultTargetPlatform.name;
    final metrics = BenchmarkMetrics(
      count: timings.length,
      buildP50: _percentile(buildTimes, 0.50),
      buildP90: _percentile(buildTimes, 0.90),
      buildP95: _percentile(buildTimes, 0.95),
      buildP99: _percentile(buildTimes, 0.99),
      buildMax: buildTimes.isNotEmpty ? buildTimes.last : 0.0,
      rasterP50: _percentile(rasterTimes, 0.50),
      rasterP90: _percentile(rasterTimes, 0.90),
      rasterP95: _percentile(rasterTimes, 0.95),
      rasterP99: _percentile(rasterTimes, 0.99),
      rasterMax: rasterTimes.isNotEmpty ? rasterTimes.last : 0.0,
      framesOver16: over16,
      scrollFrames: scrollTimings.length,
      scrollFps: scrollTimings.length / 5.0,
      scrollP95: _percentile(scrollMaxes, 0.95),
    );

    // ignore: avoid_print
    print(metrics.formatSummary(name, platformName));

    if (showModalDialog && context.mounted) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Benchmark $name ($platformName)'),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                Text('Typing Frames: ${metrics.count}'),
                Text('Build p50: ${metrics.buildP50.toStringAsFixed(2)} ms'),
                Text('Build p95: ${metrics.buildP95.toStringAsFixed(2)} ms'),
                Text('Build max: ${metrics.buildMax.toStringAsFixed(2)} ms'),
                const Divider(),
                Text('Raster p50: ${metrics.rasterP50.toStringAsFixed(2)} ms'),
                Text('Raster p95: ${metrics.rasterP95.toStringAsFixed(2)} ms'),
                Text('Raster max: ${metrics.rasterMax.toStringAsFixed(2)} ms'),
                Text('Frames > 16ms: ${metrics.framesOver16}'),
                const Divider(),
                Text('Scroll FPS: ${metrics.scrollFps.toStringAsFixed(1)}'),
                Text('Scroll p95: ${metrics.scrollP95.toStringAsFixed(2)} ms'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }

    return metrics;
  }
}
