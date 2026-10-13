// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/settings/providers.dart';
import 'package:tephra/settings/settings_screen.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../helpers/test_app.dart';

void main() {
  group('SettingsScreen', () {
    late MemoryVaultFileSystem fs;

    setUp(() {
      fs = MemoryVaultFileSystem();
    });

    testWidgets(
      'changing tabSize to 2 updates vaultSettingsProvider and writes settings.json',
      (tester) async {
        late WidgetRef capturedRef;

        await tester.pumpWidget(
          testApp(
            Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                return const SettingsScreen();
              },
            ),
            fs: fs,
          ),
        );

        await tester.pumpAndSettle();

        // Find tab size dropdown
        final dropdown = find.widgetWithText(DropdownButton<int>, '4 spaces');
        expect(dropdown, findsOneWidget);

        await tester.tap(dropdown);
        await tester.pumpAndSettle();

        await tester.tap(find.text('2 spaces').last);
        await tester.pumpAndSettle();

        expect(capturedRef.read(vaultSettingsProvider).tabSize, 2);

        final settingsFile = await fs.readText(
          VaultPath('.tephra/settings.json'),
        );
        final map = jsonDecode(settingsFile.text) as Map<String, dynamic>;
        expect(map['tabSize'], 2);
      },
    );

    testWidgets('theme dropdown updates appSettings.themeMode', (tester) async {
      late WidgetRef capturedRef;

      await tester.pumpWidget(
        testApp(
          Consumer(
            builder: (context, ref, _) {
              capturedRef = ref;
              return const SettingsScreen();
            },
          ),
          fs: fs,
        ),
      );

      await tester.pumpAndSettle();

      // Find theme dropdown
      final themeDropdown = find.widgetWithText(
        DropdownButton<String>,
        'System',
      );
      expect(themeDropdown, findsOneWidget);

      await tester.tap(themeDropdown);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dark').last);
      await tester.pumpAndSettle();

      expect(capturedRef.read(appSettingsProvider).themeMode, 'dark');
    });
  });
}
