// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/app.dart';
import 'package:tephra/welcome/welcome_screen.dart';

void main() {
  testWidgets('uses Tephra title', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: TephraApp()));
    await tester.pumpAndSettle();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.onGenerateTitle, isNotNull);
    expect(find.byType(WelcomeScreen), findsOneWidget);
  });

  testWidgets('supports dark theme', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(() {
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
    });

    await tester.pumpWidget(const ProviderScope(child: TephraApp()));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(WelcomeScreen));
    expect(Theme.of(context).brightness, Brightness.dark);
  });
}
