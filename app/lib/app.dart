// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra/l10n/app_localizations.dart';
import 'package:tephra/theme/app_theme.dart';
import 'package:tephra/welcome/welcome_screen.dart';

class TephraApp extends ConsumerWidget {
  const TephraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
    onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    themeMode: ThemeMode.system,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const WelcomeScreen(),
  );
}
