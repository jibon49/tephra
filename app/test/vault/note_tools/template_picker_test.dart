// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/l10n/app_localizations.dart';
import 'package:tephra/vault/note_tools/template_picker.dart';
import 'package:tephra_core/tephra_core.dart';

void main() {
  group('TemplatePicker', () {
    final templates = [
      VaultPath('Templates/meeting-notes.md'),
      VaultPath('Templates/daily-standup.md'),
      VaultPath('Templates/project-spec.md'),
    ];

    testWidgets('filter input scores by stem', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TemplatePicker(templates: templates, onSelected: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('meeting-notes'), findsOneWidget);
      expect(find.text('daily-standup'), findsOneWidget);
      expect(find.text('project-spec'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'met');
      await tester.pumpAndSettle();

      expect(find.text('meeting-notes'), findsOneWidget);
      expect(find.text('daily-standup'), findsNothing);
      expect(find.text('project-spec'), findsNothing);
    });

    testWidgets('arrow keys and Enter selects template', (tester) async {
      VaultPath? selected;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TemplatePicker(
              templates: templates,
              onSelected: (p) => selected = p,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Arrow down moves selection from index 0 (meeting-notes) to index 1 (daily-standup)
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      // Enter to select
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(selected, VaultPath('Templates/daily-standup.md'));
    });

    testWidgets('on phone width (<600dp), items have min 48dp height', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TemplatePicker(templates: templates, onSelected: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final firstRow = find.byType(ListTile).first;
      final size = tester.getSize(firstRow);
      expect(size.height, greaterThanOrEqualTo(48.0));
    });
  });
}
