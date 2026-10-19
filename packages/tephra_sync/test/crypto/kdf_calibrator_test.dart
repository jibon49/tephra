// © 2026 Tephra. All rights reserved.

import 'package:tephra_sync/tephra_sync.dart';
import 'package:test/test.dart';

void main() {
  group('KdfParams and KdfCalibrator tests', () {
    test('KdfParams defaults and floor values', () {
      final floor = KdfParams.floor();
      expect(floor.alg, equals('argon2id'));
      expect(floor.version, equals(19));
      expect(floor.memoryKiB, equals(65536)); // 64 MiB
      expect(floor.iterations, equals(3));
      expect(floor.parallelism, equals(1));
      expect(floor.salt.length, equals(16));
      expect(floor.calibratedMs, equals(0));
    });

    test('KdfParams JSON round trip', () {
      final original = KdfParams.floor(calibratedMs: 250);
      final json = original.toJson();
      final roundTrip = KdfParams.fromJson(json);

      expect(roundTrip, equals(original));
      expect(roundTrip.calibratedMs, equals(250));
    });

    test('Windows returns floor immediately without measuring', () async {
      var measured = false;

      final params = await KdfCalibrator.calibrate(
        isAndroid: false,
        measureOverride: (mem, iters, lanes, salt) async {
          measured = true;
          return 50; // would trigger doubling if measured
        },
      );

      expect(measured, isFalse);
      expect(params.memoryKiB, equals(65536));
      expect(params.iterations, equals(3));
      expect(params.parallelism, equals(1));
      expect(params.calibratedMs, equals(0));
    });

    test('Android: fast device doubles memory up to threshold', () async {
      // Suppose floor 64 MiB takes 100 ms, 128 MiB takes 400 ms (>= 350 ms)
      final measurements = <int, int>{65536: 100, 131072: 400};

      final params = await KdfCalibrator.calibrate(
        isAndroid: true,
        measureOverride: (mem, iters, lanes, salt) async {
          return measurements[mem] ?? 500;
        },
      );

      expect(params.memoryKiB, equals(131072)); // doubled once
      expect(
        params.iterations,
        equals(3),
      ); // didn't need to increment iterations because 400 >= 350
      expect(params.calibratedMs, equals(400));
    });

    test('Android: very fast device doubles memory and increments iterations up to caps', () async {
      // Suppose all measurements are very fast (< 350 ms)
      final params = await KdfCalibrator.calibrate(
        isAndroid: true,
        measureOverride: (mem, iters, lanes, salt) async {
          return 50; // always fast
        },
      );

      // Memory capped at 131072 KiB (128 MiB)
      expect(params.memoryKiB, equals(131072));
      // Iterations capped at 4
      expect(params.iterations, equals(4));
      expect(params.calibratedMs, equals(50));
    });

    test(
      'Android: slow device never goes below floor even if floor > 500 ms',
      () async {
        final params = await KdfCalibrator.calibrate(
          isAndroid: true,
          measureOverride: (mem, iters, lanes, salt) async {
            return 800; // takes 800 ms at floor
          },
        );

        expect(params.memoryKiB, equals(65536)); // remains at floor
        expect(params.iterations, equals(3));
        expect(params.parallelism, equals(1));
        expect(params.calibratedMs, equals(800));
      },
    );

    test('derivePasswordKek derives 32-byte key via Argon2id', () async {
      // Use smaller memory for fast test
      const testParams = KdfParams(
        salt: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
        memoryKiB: 32,
        iterations: 1,
        parallelism: 1,
      );

      final key = await testParams.derivePasswordKek(
        'CorrectHorseBatteryStaple',
      );
      final bytes = await key.extractBytes();
      expect(bytes.length, equals(32));
    });
  });
}
