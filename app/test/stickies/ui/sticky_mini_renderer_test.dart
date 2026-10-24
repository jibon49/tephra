// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/stickies/model/sticky_color.dart';
import 'package:tephra/stickies/model/sticky_meta.dart';
import 'package:tephra/stickies/ui/sticky_card.dart';
import 'package:tephra/stickies/ui/sticky_mini_renderer.dart';

void main() {
  group('StickyMiniRenderer', () {
    testWidgets('renders heading paragraph and task', (tester) async {
      const markdown = '''
# Heading 1
This is a paragraph text.
- [ ] First task
''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StickyMiniRenderer(text: markdown, textColor: Colors.black),
          ),
        ),
      );

      expect(find.text('Heading 1'), findsOneWidget);
      expect(find.text('This is a paragraph text.'), findsOneWidget);
      expect(find.text('First task'), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);
    });

    testWidgets('tap checkbox reports source line', (tester) async {
      const markdown = '---\ntephra-sticky: true\n---\n# T\n- [ ] a\n- [x] b\n';
      int? reportedLine;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StickyMiniRenderer(
              text: markdown,
              textColor: Colors.black,
              onToggleTask: (line) {
                reportedLine = line;
              },
            ),
          ),
        ),
      );

      final checkboxes = find.byType(Checkbox);
      expect(checkboxes, findsNWidgets(2));

      await tester.tap(checkboxes.first);
      await tester.pump();

      expect(reportedLine, 4);
    });

    testWidgets('locked has no tappable checkbox', (tester) async {
      const markdown = '---\ntephra-sticky: true\n---\n# T\n- [ ] a\n';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StickyMiniRenderer(
              text: markdown,
              textColor: Colors.black,
              onToggleTask: null, // locked
            ),
          ),
        ),
      );

      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.onChanged, isNull);
    });

    testWidgets('frontmatter is not shown', (tester) async {
      const markdown = '''---
tephra-sticky: true
sticky-color: yellow
secret-meta: hidden
---
Visible content
''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StickyMiniRenderer(text: markdown, textColor: Colors.black),
          ),
        ),
      );

      expect(find.text('Visible content'), findsOneWidget);
      expect(find.textContaining('tephra-sticky'), findsNothing);
      expect(find.textContaining('secret-meta'), findsNothing);
      expect(find.textContaining('sticky-color'), findsNothing);
    });

    testWidgets('comments hidden', (tester) async {
      const markdown = '''
Visible line 1 %%inline comment%% and after

%%
This is a hidden block comment
%%

Visible line 2
''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StickyMiniRenderer(text: markdown, textColor: Colors.black),
          ),
        ),
      );

      expect(find.textContaining('Visible line 1'), findsOneWidget);
      expect(find.textContaining('Visible line 2'), findsOneWidget);
      expect(find.textContaining('inline comment'), findsNothing);
      expect(find.textContaining('hidden block comment'), findsNothing);
    });
  });

  group('StickyCard Goldens', () {
    const goldenKey = ValueKey('sticky_card_golden_root');

    testWidgets('golden sticky_card_yellow.png', (tester) async {
      tester.view.physicalSize = const Size(320, 260);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      const text = '''---
tephra-sticky: true
sticky-color: yellow
---
# Shopping
- [ ] Apples
- [x] Oat milk
- [ ] Bread
''';

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: const Color(0xFFEEEEEE),
            body: Center(
              child: RepaintBoundary(
                key: goldenKey,
                child: SizedBox(
                  width: 280,
                  height: 220,
                  child: StickyCard(
                    title: 'Shopping List',
                    text: text,
                    color: NamedStickyColor.yellow,
                    pinned: true,
                    locked: false,
                    remind: const LocalDateTime(2026, 10, 12, 14, 30),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await expectLater(
        find.byKey(goldenKey),
        matchesGoldenFile('goldens/sticky_card_yellow.png'),
      );
    }, tags: 'golden');

    testWidgets('golden sticky_card_hex_dark.png', (tester) async {
      tester.view.physicalSize = const Size(320, 260);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      const text = '''---
tephra-sticky: true
sticky-color: "#2C3E50"
---
## Deep Work
Concentrate on high-value tasks.
> Quality is not an act, it is a habit.
''';

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: const Color(0xFF1E1E1E),
            body: Center(
              child: RepaintBoundary(
                key: goldenKey,
                child: SizedBox(
                  width: 280,
                  height: 220,
                  child: const StickyCard(
                    title: 'Midnight Thoughts',
                    text: text,
                    color: HexStickyColor(0xFF2C3E50),
                    pinned: false,
                    locked: true,
                    remind: null,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await expectLater(
        find.byKey(goldenKey),
        matchesGoldenFile('goldens/sticky_card_hex_dark.png'),
      );
    }, tags: 'golden');
  });
}
