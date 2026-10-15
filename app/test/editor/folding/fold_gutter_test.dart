// © 2026 Tephra. All rights reserved.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/editor/folding/fold_controller.dart';
import 'package:tephra/editor/folding/fold_gutter.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_markdown/tephra_markdown.dart';

void main() {
  group('FoldGutter', () {
    const text = '''# Heading 1
Line 1
Line 2
''';

    late ParsedNote parsed;
    late FoldController controller;

    setUp(() {
      parsed = MarkdownParser.parse(text);
      controller = FoldController(tabId: 'tab-1', path: VaultPath('note.md'));
      controller.updateParse(text, parsed);
    });

    testWidgets('at 1200 dp a chevron appears on hover for a heading line', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FoldGutter(
              controller: controller,
              lineCount: parsed.lines.lineCount,
              lineHeight: 30.0,
            ),
          ),
        ),
      );

      final iconFinder = find.byIcon(Icons.keyboard_arrow_down);
      expect(iconFinder, findsOneWidget);

      // Initially on desktop, not hovered and not folded -> opacity is 0.0
      var opacityWidget = tester.widget<Opacity>(
        find.ancestor(of: iconFinder, matching: find.byType(Opacity)),
      );
      expect(opacityWidget.opacity, 0.0);

      // Hover over the heading line (line 0, y ~ 15)
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: const Offset(10, 15));
      await tester.pump();

      opacityWidget = tester.widget<Opacity>(
        find.ancestor(of: iconFinder, matching: find.byType(Opacity)),
      );
      expect(opacityWidget.opacity, 1.0);

      // Tap toggles the fold
      await gesture.down(const Offset(10, 15));
      await gesture.up();
      await tester.pump();

      expect(controller.isFolded(0), isTrue);

      // After folding, chevron is right arrow and remains visible even when pointer moves away
      final foldedIconFinder = find.byIcon(Icons.keyboard_arrow_right);
      expect(foldedIconFinder, findsOneWidget);

      await gesture.moveTo(const Offset(500, 500));
      await tester.pump();

      opacityWidget = tester.widget<Opacity>(
        find.ancestor(of: foldedIconFinder, matching: find.byType(Opacity)),
      );
      expect(opacityWidget.opacity, 1.0);

      await gesture.removePointer();
    });

    testWidgets(
      'at 400 dp chevrons are always present with a 48 dp hit area; tapping toggles',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FoldGutter(
                controller: controller,
                lineCount: parsed.lines.lineCount,
                lineHeight: 48.0,
              ),
            ),
          ),
        );

        final iconFinder = find.byIcon(Icons.keyboard_arrow_down);
        expect(iconFinder, findsOneWidget);

        // Always visible without hover on phone
        final opacityWidget = tester.widget<Opacity>(
          find.ancestor(of: iconFinder, matching: find.byType(Opacity)),
        );
        expect(opacityWidget.opacity, 1.0);

        // Verify 48x48 dp hit area box exists in hierarchy
        final hitAreaBoxFinder = find.byWidgetPredicate(
          (w) => w is SizedBox && w.width == 48 && w.height == 48,
        );
        expect(hitAreaBoxFinder, findsWidgets);

        // Tap the hit area to toggle
        expect(controller.isFolded(0), isFalse);
        await tester.tap(iconFinder);
        await tester.pump();

        expect(controller.isFolded(0), isTrue);
        expect(find.byIcon(Icons.keyboard_arrow_right), findsOneWidget);
      },
    );
  });
}
