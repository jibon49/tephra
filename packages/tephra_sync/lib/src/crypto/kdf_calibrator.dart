// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'kdf_params.dart';

/// Function signature for measuring KDF derivation latency in milliseconds.
typedef KdfMeasureFn = Future<int> Function(
  int memoryKiB,
  int iterations,
  int parallelism,
  List<int> salt,
);

/// Calibrates Argon2id parameters based on target platform and hardware speed.
abstract final class KdfCalibrator {
  /// Target latency threshold in milliseconds for Android calibration.
  static const int targetThresholdMs = 350;

  /// Maximum allowed memory cap during calibration (128 MiB = 131,072 KiB).
  static const int maxMemoryKiB = 131072;

  /// Maximum allowed iteration cap during calibration.
  static const int maxIterations = 4;

  /// Runs Argon2id parameter calibration.
  ///
  /// On Windows, immediately returns the floor parameters without measuring
  /// (a PC-calibrated value would take too long to unlock on mobile devices).
  ///
  /// On Android, benchmarks derivations starting from the floor:
  /// - Doubles [memoryKiB] while elapsed < 350 ms and [memoryKiB] < 131,072.
  /// - Increments [iterations] while elapsed < 350 ms and [iterations] < 4.
  ///
  /// Long operations run in an isolate via [Isolate.run] unless [measureOverride] is supplied.
  static Future<KdfParams> calibrate({
    required bool isAndroid,
    List<int>? salt,
    Random? random,
    KdfMeasureFn? measureOverride,
  }) async {
    final effectiveSalt = salt != null
        ? Uint8List.fromList(salt)
        : _generateSalt(random: random);

    // On Windows, return floor parameters without measuring.
    if (!isAndroid) {
      return KdfParams.floor(salt: effectiveSalt, calibratedMs: 0);
    }

    if (measureOverride != null) {
      return _runCalibrationLoop(effectiveSalt, measureOverride);
    }

    // On Android, run in background isolate
    return Isolate.run(() async {
      return _runCalibrationLoop(effectiveSalt, _defaultMeasure);
    });
  }

  static Future<KdfParams> _runCalibrationLoop(
    Uint8List salt,
    KdfMeasureFn measure,
  ) async {
    var memoryKiB = KdfParams.floorMemoryKiB;
    var iterations = KdfParams.floorIterations;
    const parallelism = KdfParams.floorParallelism;

    // 1. Measure floor
    var elapsed = await measure(memoryKiB, iterations, parallelism, salt);

    // 2. While elapsed < 350 ms and memoryKiB < 131072, double memoryKiB
    while (elapsed < targetThresholdMs && memoryKiB < maxMemoryKiB) {
      final nextMemory = memoryKiB * 2;
      if (nextMemory > maxMemoryKiB) break;
      memoryKiB = nextMemory;
      elapsed = await measure(memoryKiB, iterations, parallelism, salt);
    }

    // 3. While elapsed < 350 ms and iterations < 4, increment iterations
    while (elapsed < targetThresholdMs && iterations < maxIterations) {
      iterations += 1;
      elapsed = await measure(memoryKiB, iterations, parallelism, salt);
    }

    return KdfParams(
      memoryKiB: memoryKiB,
      iterations: iterations,
      parallelism: parallelism,
      salt: salt,
      calibratedMs: elapsed,
    );
  }

  static Future<int> _defaultMeasure(
    int memoryKiB,
    int iterations,
    int parallelism,
    List<int> salt,
  ) async {
    final argon2 = Argon2id(
      parallelism: parallelism,
      memory: memoryKiB,
      iterations: iterations,
      hashLength: 32,
    );
    final sw = Stopwatch()..start();
    await argon2.deriveKey(
      secretKey: SecretKey(utf8.encode('tephra-calibration-probe')),
      nonce: salt,
    );
    sw.stop();
    return sw.elapsedMilliseconds;
  }

  static Uint8List _generateSalt({Random? random}) {
    final rng = random ?? Random.secure();
    final bytes = Uint8List(KdfParams.saltLength);
    for (var i = 0; i < KdfParams.saltLength; i++) {
      bytes[i] = rng.nextInt(256);
    }
    return bytes;
  }
}
