// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra/l10n/app_localizations.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.landscape_outlined, size: 64),
                const SizedBox(height: 16),
                Text(l10n.welcomeTitle, style: textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(l10n.welcomeSubtitle, textAlign: TextAlign.center),
                const SizedBox(height: 32),
                FilledButton.icon(
                  key: const Key('welcome.open'),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.comingInPhase1)),
                    );
                  },
                  icon: const Icon(Icons.folder_open),
                  label: Text(l10n.welcomeOpenVault),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const Key('welcome.create'),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.comingInPhase1)),
                    );
                  },
                  icon: const Icon(Icons.create_new_folder_outlined),
                  label: Text(l10n.welcomeCreateVault),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
