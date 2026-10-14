// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../commands/command_registry.dart';
import '../commands/tephra_command.dart';
import '../editor/edit_operation.dart';
import '../editor/providers.dart';
import '../vault/providers.dart';
import '../workspace/open_file.dart';
import 'typing_benchmark.dart';

void registerDevCommands(CommandRegistry registry) {
  if (!const bool.fromEnvironment('TEPHRA_DEV')) return;

  registry.register(
    TephraCommand(
      id: 'dev.run-typing-benchmark',
      label: (l10n) => 'Dev: Run typing benchmark',
      icon: Icons.speed,
      showInPalette: true,
      run: (ref, context) async {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const TypingBenchmarkScreen(),
          ),
        );
      },
    ),
  );

  registry.register(
    TephraCommand(
      id: 'dev.type-and-wait',
      label: (l10n) => 'Dev: Type and wait (kill test)',
      icon: Icons.keyboard,
      showInPalette: true,
      run: (ref, context) async {
        final session = ref.read(vaultSessionProvider);
        if (session == null) return;

        final fs = session.fs;
        final path = VaultPath('__kill_test.md');
        if (await fs.stat(path) == null) {
          await fs.writeText(path, const TextDocument(text: ''));
        }

        openFile(ref, path);

        var n = 1;
        Timer.periodic(const Duration(milliseconds: 200), (timer) {
          if (n > 300) {
            timer.cancel();
            return;
          }
          final controller = ref
              .read(editorRegistryProvider)
              .controllerFor(path);
          if (controller != null) {
            final off = controller.text.length;
            controller.apply(
              EditOperation(off, off, 'K$n\n'),
              selectAfter: true,
            );
            debugPrint('TYPED K$n');
          }
          n++;
        });
      },
    ),
  );
}
