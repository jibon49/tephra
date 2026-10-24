// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/l10n/app_localizations.dart';
import 'package:tephra/stickies/model/sticky_color.dart';
import 'package:tephra/stickies/ui/sticky_color_picker.dart';

void main() {
  group('StickyColorPicker', () {
    testWidgets('semantics labels present', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: StickyColorPicker()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Yellow'), findsOneWidget);
      expect(find.bySemanticsLabel('Pink'), findsOneWidget);
      expect(find.bySemanticsLabel('Blue'), findsOneWidget);
      expect(find.bySemanticsLabel('Green'), findsOneWidget);
      expect(find.bySemanticsLabel('Purple'), findsOneWidget);
      expect(find.bySemanticsLabel('Gray'), findsOneWidget);
      expect(find.bySemanticsLabel('Custom'), findsOneWidget);
    });

    testWidgets('custom hex validates', (tester) async {
      StickyColor? result;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    result = await showStickyColorPicker(context);
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open dialog
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap custom swatch
      await tester.tap(find.bySemanticsLabel('Custom'));
      await tester.pumpAndSettle();

      // Enter invalid hex
      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);

      await tester.enterText(textFieldFinder, '#12GG45');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Verify error text is displayed
      expect(
        find.text('Please enter a valid hex color like #AABBCC'),
        findsOneWidget,
      );
      expect(result, isNull);

      // Enter valid hex
      await tester.enterText(textFieldFinder, '#1234AB');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Dialog closed and returned parsed color
      expect(result, isA<HexStickyColor>());
      expect((result as HexStickyColor).yamlValue, '#1234AB');
    });
  });
}
