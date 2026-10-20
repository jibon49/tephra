// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/l10n/app_localizations.dart';
import 'package:tephra/sync_ui/diff/diff_model.dart';
import 'package:tephra/sync_ui/diff/diff_view.dart';

Widget _wrap(Widget child, {Size size = const Size(1200, 800)}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: Scaffold(
        body: SizedBox(width: size.width, height: size.height, child: child),
      ),
    ),
  );
}

void main() {
  group('DiffView widget tests', () {
    testWidgets('renders side-by-side diff at 1200 dp desktop width', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const oldText = 'Line 1\nOld Line\nLine 3\n';
      const newText = 'Line 1\nNew Line\nLine 3\n';

      await tester.pumpWidget(
        _wrap(
          const DiffView(
            oldText: oldText,
            newText: newText,
            oldTitle: 'Their version',
            newTitle: 'Your version',
          ),
          size: const Size(1200, 800),
        ),
      );
      await tester.pumpAndSettle();

      // Should show column headers
      expect(find.text('Their version'), findsWidgets);
      expect(find.text('Your version'), findsWidgets);

      // Should show diff contents
      expect(find.text('Old Line'), findsOneWidget);
      expect(find.text('New Line'), findsOneWidget);

      // Toggle button should be visible
      expect(find.byType(SegmentedButton<DiffDisplayMode>), findsOneWidget);
    });

    testWidgets('renders stacked unified diff at 400 dp phone width', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const oldText = 'Line 1\nOld Line\nLine 3\n';
      const newText = 'Line 1\nNew Line\nLine 3\n';

      await tester.pumpWidget(
        _wrap(
          const DiffView(oldText: oldText, newText: newText),
          size: const Size(400, 800),
        ),
      );
      await tester.pumpAndSettle();

      // In inline/stacked mode, should show '+' and '-' markers
      expect(find.text('-'), findsOneWidget);
      expect(find.text('+'), findsOneWidget);
      expect(find.text('Old Line'), findsOneWidget);
      expect(find.text('New Line'), findsOneWidget);
    });

    testWidgets('switching toggle updates diff display mode', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const oldText = 'Alpha\nBeta\n';
      const newText = 'Alpha\nGamma\n';

      await tester.pumpWidget(
        _wrap(
          const DiffView(oldText: oldText, newText: newText),
          size: const Size(1200, 800),
        ),
      );
      await tester.pumpAndSettle();

      // Desktop defaults to side-by-side (no '-' marker)
      expect(find.text('-'), findsNothing);

      // Tap "Inline" segment
      final inlineSegment = find.text('Inline');
      expect(inlineSegment, findsOneWidget);
      await tester.tap(inlineSegment);
      await tester.pumpAndSettle();

      // Now inline mode shows '-' and '+'
      expect(find.text('-'), findsOneWidget);
      expect(find.text('+'), findsOneWidget);
    });
  });
}
