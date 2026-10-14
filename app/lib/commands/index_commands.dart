// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:flutter/material.dart';

import '../core/providers.dart';
import '../l10n/app_localizations.dart';
import 'command_registry.dart';
import 'tephra_command.dart';

void registerIndexCommands(CommandRegistry registry) {
  registry.register(
    TephraCommand(
      id: 'index.rebuild',
      label: (l10n) => l10n.commandRebuildIndex,
      icon: Icons.refresh,
      run: (ref, context) async {
        final l10n = AppLocalizations.of(context);
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.rebuildIndexConfirmTitle),
            content: Text(l10n.rebuildIndexConfirmBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(l10n.commonOk),
              ),
            ],
          ),
        );

        if (confirmed == true && context.mounted) {
          final index = await ref.read(noteIndexProvider.future);
          unawaited(() async {
            await index.rebuild();
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(l10n.rebuildIndexDone)));
            }
          }());
        }
      },
    ),
  );
}
