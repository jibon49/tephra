// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/app.dart';

void main() {
  testWidgets('shows title and both buttons', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: TephraApp()));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Tephra'), findsOneWidget);
    expect(find.byKey(const Key('welcome.open')), findsOneWidget);
    expect(find.byKey(const Key('welcome.create')), findsOneWidget);
  });

  testWidgets('open vault shows coming-soon snackbar', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: TephraApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('welcome.open')));
    await tester.pump();

    expect(find.text('Coming in Phase 1'), findsOneWidget);
  });

  testWidgets('create vault shows coming-soon snackbar', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: TephraApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('welcome.create')));
    await tester.pump();

    expect(find.text('Coming in Phase 1'), findsOneWidget);
  });
}
