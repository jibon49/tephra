// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/app.dart';
import 'package:tephra/settings/app_settings.dart';
import 'package:tephra/settings/providers.dart';

void main() {
  testWidgets('pumping TephraApp with no session shows the picker', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialAppSettingsProvider.overrideWithValue(
            const AppSettings(deviceId: 'test-device'),
          ),
        ],
        child: const TephraApp(),
      ),
    );
    await tester.pumpAndSettle();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.onGenerateTitle, isNotNull);
    expect(find.byKey(const Key('vaultPicker.open')), findsOneWidget);
  });

  testWidgets('with ThemeMode from settings dark the brightness is dark', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialAppSettingsProvider.overrideWithValue(
            const AppSettings(deviceId: 'test-device', themeMode: 'dark'),
          ),
        ],
        child: const TephraApp(),
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byKey(const Key('vaultPicker.open')));
    expect(Theme.of(context).brightness, Brightness.dark);
  });
}
