// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/properties/properties_exceptions.dart';
import 'package:tephra/properties/raw_yaml_editor.dart';

import '../helpers/test_app.dart';

void main() {
  group('RawYamlEditor', () {
    testWidgets(
      'Apply with valid text invokes onApply; Revert restores original text',
      (tester) async {
        const initial = 'title: Note\nstatus: draft';
        String? appliedText;
        var revertCalled = false;

        await tester.pumpWidget(
          testApp(
            Scaffold(
              body: RawYamlEditor(
                initialYaml: initial,
                onApply: (newYaml) {
                  appliedText = newYaml;
                },
                onRevert: () {
                  revertCalled = true;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find the TextField and check its initial text
        final textField = find.byType(TextField);
        expect(textField, findsOneWidget);
        expect(find.text(initial), findsOneWidget);

        // Edit text
        await tester.enterText(textField, 'title: Updated Note\nstatus: done');
        await tester.pumpAndSettle();

        // Tap Revert
        final revertButton = find.text('Revert');
        expect(revertButton, findsOneWidget);
        await tester.tap(revertButton);
        await tester.pumpAndSettle();

        expect(revertCalled, isTrue);
        expect(find.text(initial), findsOneWidget);

        // Edit text again
        await tester.enterText(textField, 'title: Applied Note');
        await tester.pumpAndSettle();

        // Tap Apply
        final applyButton = find.text('Apply');
        expect(applyButton, findsOneWidget);
        await tester.tap(applyButton);
        await tester.pumpAndSettle();

        expect(appliedText, 'title: Applied Note');
      },
    );

    testWidgets('PropertiesYamlException displays message with line number', (
      tester,
    ) async {
      const initial = 'key: value';

      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: RawYamlEditor(
              initialYaml: initial,
              onApply: (newYaml) {
                throw PropertiesYamlException('unexpected character', 1);
              },
              onRevert: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final applyButton = find.text('Apply');
      await tester.tap(applyButton);
      await tester.pumpAndSettle();

      // Error should show "unexpected character (line 2)"
      expect(
        find.textContaining('unexpected character (line 2)'),
        findsOneWidget,
      );
    });
  });
}
