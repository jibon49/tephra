// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra/explorer/providers.dart';
import 'package:tephra/l10n/app_localizations.dart';
import 'package:tephra/settings/providers.dart';
import 'package:tephra/settings/settings_screen.dart';
import 'package:tephra/theme/app_theme.dart';
import 'package:tephra/vault/vault_gate.dart';

class TephraApp extends ConsumerWidget {
  const TephraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appSettings = ref.watch(appSettingsProvider);
    final themeMode = switch (appSettings.themeMode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    return MaterialApp(
      scaffoldMessengerKey: ref.watch(scaffoldMessengerKeyProvider),
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const VaultGate(),
      routes: {SettingsScreen.routeName: (context) => const SettingsScreen()},
    );
  }
}
