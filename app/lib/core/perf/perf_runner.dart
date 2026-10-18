import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import 'perf_probe.dart';
import 'perf_scenarios.dart';

final _logger = Logger('perf');

/// Executes benchmark scenarios S2–S5 and displays summary dialog.
Future<void> runBenchmarks(BuildContext context, WidgetRef ref) async {
  const isAuto = bool.fromEnvironment('TEPHRA_AUTO_BENCH');
  if (!isAuto) {
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const AlertDialog(
          title: Text('Running Benchmarks...'),
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Running S2 (Index), S3 (Typing), S4 (Search), S5 (Switcher)...',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  try {
    await runScenarioS2(ref);
    await runScenarioS3(ref);
    await runScenarioS4(ref);
    await runScenarioS5(ref);
    runScenarioS6();

    // S7 APK sizes check if present
    for (final dir in [
      Directory(p.join('build', 'app', 'outputs', 'flutter-apk')),
      Directory(p.join('app', 'build', 'app', 'outputs', 'flutter-apk')),
    ]) {
      final arm64 = File(p.join(dir.path, 'app-arm64-v8a-release.apk'));
      if (arm64.existsSync()) {
        PerfProbe.record('apk.arm64', arm64.lengthSync().toDouble(), 'bytes');
      }
      final armv7 = File(p.join(dir.path, 'app-armeabi-v7a-release.apk'));
      if (armv7.existsSync()) {
        PerfProbe.record('apk.armv7', armv7.lengthSync().toDouble(), 'bytes');
      }
      final x64 = File(p.join(dir.path, 'app-x86_64-release.apk'));
      if (x64.existsSync()) {
        PerfProbe.record('apk.x64', x64.lengthSync().toDouble(), 'bytes');
      }
    }
  } catch (e, st) {
    _logger.warning('Benchmark error', e, st);
  } finally {
    if (!isAuto && context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  if (isAuto) {
    // ignore: avoid_print
    print('BENCHMARKS_COMPLETE');
    await Future<void>.delayed(const Duration(milliseconds: 500));
    exit(0);
  }

  if (context.mounted) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Benchmark Results'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final res in PerfProbe.results)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          res.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text('${res.value.toStringAsFixed(2)} ${res.unit}'),
                      ],
                    ),
                  ),
              ],
            ),
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
}
