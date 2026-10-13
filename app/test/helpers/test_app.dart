// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/core/providers.dart';
import 'package:tephra/l10n/app_localizations.dart';
import 'package:tephra/settings/app_settings.dart';
import 'package:tephra/settings/providers.dart';
import 'package:tephra/settings/settings_screen.dart';
import 'package:tephra/settings/vault_settings.dart';
import 'package:tephra/theme/app_theme.dart';
import 'package:tephra/vault/providers.dart';
import 'package:tephra/vault/vault_session.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

final class FixedVaultSessionNotifier extends VaultSessionNotifier {
  FixedVaultSessionNotifier(this._initialSession);

  final VaultSession _initialSession;

  @override
  VaultSession? build() => _initialSession;
}

Widget testApp(
  Widget child, {
  MemoryVaultFileSystem? fs,
  VaultSettings settings = const VaultSettings(),
  AppSettings? appSettings,
  Size size = const Size(1200, 800),
  List<Override> overrides = const [],
}) {
  final effectiveFs = fs ?? MemoryVaultFileSystem();
  final defaultAppSettings =
      appSettings ?? const AppSettings(deviceId: 'test-device-id');
  final session = VaultSession(
    vaultId: 'test',
    rootDir: '/memory',
    name: 'Test vault',
    fs: effectiveFs,
    settings: settings,
  );

  return ProviderScope(
    overrides: [
      initialAppSettingsProvider.overrideWithValue(defaultAppSettings),
      clockProvider.overrideWithValue(
        ManualClock(DateTime(2026, 10, 11, 9, 30)),
      ),
      vaultSessionProvider.overrideWith(
        () => FixedVaultSessionNotifier(session),
      ),
      ...overrides,
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routes: {SettingsScreen.routeName: (context) => const SettingsScreen()},
      home: ScaffoldMessenger(
        child: MediaQuery(
          data: MediaQueryData(size: size),
          child: child,
        ),
      ),
    ),
  );
}

void setSurfaceSize(WidgetTester t, Size s) {
  t.view.physicalSize = s * t.view.devicePixelRatio;
  addTearDown(t.view.reset);
}
