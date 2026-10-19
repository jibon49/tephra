// © 2026 Tephra. All rights reserved.

@Tags(['fuzz'])
library;

import 'dart:io';

import 'package:tephra_core/tephra_core.dart';
import 'package:test/test.dart';

import 'invariants.dart';
import 'sim_ops.dart';
import 'sim_world.dart';

void main() {
  final envOps = Platform.environment['TEPHRA_FUZZ_OPS'];
  final opsCount = envOps != null ? int.parse(envOps) : 3000;

  final envSeed = Platform.environment['TEPHRA_FUZZ_SEED'];
  final seeds = envSeed != null
      ? [int.parse(envSeed)]
      : (opsCount >= 50000 ? const [1] : const [1, 2, 3]);

  for (final seed in seeds) {
    test('fuzz test seed=$seed ops=$opsCount', () async {
      final world = await SimWorld.create(seed);
      try {
        for (var i = 1; i <= opsCount; i++) {
          try {
            await SimOps.executeRandomOp(world);
          } catch (e, st) {
            final last50 = world.opLog.reversed.take(50).toList().reversed;
            // ignore: avoid_print // spec 03.12 requires printing FUZZ FAILURE on error
            print('FUZZ FAILURE seed=$seed op=$i error: $e\nStacktrace:\n$st');
            // ignore: avoid_print // spec 03.12 requires printing last 50 ops
            print('Last ${last50.length} operations:');
            for (final line in last50) {
              // ignore: avoid_print // spec 03.12 requires printing last 50 ops
              print('  $line');
            }
            rethrow;
          }
        }

        // Bring all devices online and converge
        await world.convergeAll();

        // Check invariants
        try {
          await SimulatorInvariants.checkNoLoss(
            mustSurvive: world.mustSurvive,
            devices: world.devices,
            provider: world.provider,
            cipher: world.cipher,
          );
          await SimulatorInvariants.checkConvergence(
            devices: world.devices,
            provider: world.provider,
            cipher: world.cipher,
          );
        } catch (e) {
          final last50 = world.opLog.reversed.take(50).toList().reversed;
          // ignore: avoid_print // spec 03.12 requires printing FUZZ FAILURE on invariant violation
          print('FUZZ FAILURE seed=$seed invariant violation: $e');
          // ignore: avoid_print // spec 03.12 requires printing last 50 ops
          print('Last ${last50.length} operations:');
          for (final line in last50) {
            // ignore: avoid_print // spec 03.12 requires printing last 50 ops
            print('  $line');
          }
          rethrow;
        }
      } finally {
        await world.close();
      }
    }, timeout: Timeout(Duration(minutes: opsCount >= 50000 ? 120 : 15)));
  }

  test(
    'Determinism: running same seed twice gives identical final states',
    () async {
      const determinismSeed = 999;
      const testOps = 300;

      Future<Map<String, String>> runSeed(int s) async {
        final world = await SimWorld.create(s);
        try {
          for (var i = 1; i <= testOps; i++) {
            await SimOps.executeRandomOp(world);
          }
          await world.convergeAll();

          final map = <String, String>{};
          for (final dev in world.devices) {
            final entries = await dev.fs.list(recursive: true);
            for (final e in entries) {
              if (!e.isFolder) {
                final bytes = await dev.fs.readBytes(e.path);
                map['${dev.name}:${e.path.value}'] = contentHash(bytes);
              }
            }
          }
          return map;
        } finally {
          await world.close();
        }
      }

      final state1 = await runSeed(determinismSeed);
      final state2 = await runSeed(determinismSeed);
      expect(state1, equals(state2));
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
