// © 2026 Tephra. All rights reserved.

import 'package:editor_spike/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Run editor benchmarks for A and B', (tester) async {
    await tester.pumpWidget(const EditorSpikeApp());
    await tester.pumpAndSettle();

    // 1. Prototype A (re_editor)
    final btnA = find.text('A: re_editor');
    expect(btnA, findsOneWidget);
    await tester.tap(btnA);
    await tester.pumpAndSettle();

    // Wait for text asset to load
    await Future<void>.delayed(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    final runBenchA = find.text('Run benchmark');
    expect(runBenchA, findsOneWidget);
    await tester.tap(runBenchA);

    // Wait for benchmark to run (typing 500 chars + 1s + scroll 5s + 0.5s)
    await Future<void>.delayed(const Duration(seconds: 12));
    await tester.pumpAndSettle();

    // Close dialog
    final closeBtnA = find.text('Close');
    if (closeBtnA.evaluate().isNotEmpty) {
      await tester.tap(closeBtnA);
      await tester.pumpAndSettle();
    }

    // Go back
    final backBtnA = find.byType(BackButton);
    if (backBtnA.evaluate().isNotEmpty) {
      await tester.tap(backBtnA);
      await tester.pumpAndSettle();
    }

    // 2. Prototype B (TextField)
    final btnB = find.text('B: TextField');
    expect(btnB, findsOneWidget);
    await tester.tap(btnB);
    await tester.pumpAndSettle();

    // Wait for text asset to load
    await Future<void>.delayed(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    final runBenchB = find.text('Run benchmark');
    expect(runBenchB, findsOneWidget);
    await tester.tap(runBenchB);

    // Wait for benchmark to run
    await Future<void>.delayed(const Duration(seconds: 12));
    await tester.pumpAndSettle();

    final closeBtnB = find.text('Close');
    if (closeBtnB.evaluate().isNotEmpty) {
      await tester.tap(closeBtnB);
      await tester.pumpAndSettle();
    }
  });
}
