// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/core/providers.dart';
import 'package:tephra/workspace/index_status.dart';
import 'package:tephra_index/tephra_index.dart';

import '../helpers/test_app.dart';

void main() {
  group('IndexStatusItem & PhoneIndexProgressBar', () {
    testWidgets(
      'desktop width (1200 dp) shows "Indexing 5 / 10" during indexing and hides when done',
      (tester) async {
        setSurfaceSize(tester, const Size(1200, 800));
        final controller = StreamController<IndexProgress>.broadcast();
        addTearDown(controller.close);

        await tester.pumpWidget(
          testApp(
            const Scaffold(body: Center(child: IndexStatusItem())),
            size: const Size(1200, 800),
            overrides: [
              indexProgressProvider.overrideWith((ref) => controller.stream),
            ],
          ),
        );
        await tester.pump();

        // Emit indexing progress
        controller.add(
          const IndexProgress(phase: IndexPhase.indexing, done: 5, total: 10),
        );
        await tester.pumpAndSettle();

        expect(find.text('Indexing 5 / 10'), findsOneWidget);
        expect(find.byKey(const Key('desktop.index_status')), findsOneWidget);

        // When done:
        controller.add(
          const IndexProgress(phase: IndexPhase.done, done: 10, total: 10),
        );
        await tester.pumpAndSettle();

        expect(find.text('Indexing 5 / 10'), findsNothing);
        expect(find.byKey(const Key('desktop.index_status')), findsNothing);
      },
    );

    testWidgets(
      'phone width (400 dp) shows LinearProgressIndicator with value 0.5 and hides when done',
      (tester) async {
        setSurfaceSize(tester, const Size(400, 800));
        final controller = StreamController<IndexProgress>.broadcast();
        addTearDown(controller.close);

        await tester.pumpWidget(
          testApp(
            const Scaffold(
              appBar: PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: PhoneIndexProgressBar(),
              ),
              body: SizedBox.expand(),
            ),
            size: const Size(400, 800),
            overrides: [
              indexProgressProvider.overrideWith((ref) => controller.stream),
            ],
          ),
        );
        await tester.pump();

        controller.add(
          const IndexProgress(phase: IndexPhase.indexing, done: 5, total: 10),
        );
        await tester.pumpAndSettle();

        final indicatorFinder = find.byType(LinearProgressIndicator);
        expect(indicatorFinder, findsOneWidget);
        final indicator = tester.widget<LinearProgressIndicator>(
          indicatorFinder,
        );
        expect(indicator.value, equals(0.5));

        // When done:
        controller.add(
          const IndexProgress(phase: IndexPhase.done, done: 10, total: 10),
        );
        await tester.pumpAndSettle();

        expect(find.byType(LinearProgressIndicator), findsNothing);
      },
    );
  });
}
