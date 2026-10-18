// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';

import '../../commands/command_registry.dart';
import '../../commands/tephra_command.dart';
import 'perf_probe.dart';
import 'perf_runner.dart';

/// Registers performance benchmark command when `PerfProbe.enabled` is true.
void registerPerfCommand(CommandRegistry registry) {
  if (!PerfProbe.enabled) return;

  registry.register(
    TephraCommand(
      id: 'dev.run-benchmarks',
      label: (l10n) => l10n.commandRunBenchmarks,
      icon: Icons.speed,
      defaultShortcuts: const [],
      showInMobileToolbar: false,
      run: (ref, context) async {
        await runBenchmarks(context, ref);
      },
    ),
  );
}
