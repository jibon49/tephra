// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/reading/reading_view.dart';
import 'package:tephra_core/tephra_core.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('renders heading and paragraph with semantics', (tester) async {
    const markdown = '# Heading One\n\nParagraph text';

    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: ReadingView(path: VaultPath('test.md'), text: markdown),
        ),
        size: const Size(600, 800),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Heading One'), findsOneWidget);
    expect(find.text('Paragraph text'), findsOneWidget);

    final headingSemantics = tester.widget<Semantics>(
      find
          .ancestor(
            of: find.text('Heading One'),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(headingSemantics.properties.header, isTrue);
  });

  testWidgets('renders list markers (bullet, numbers, nested bullet)', (
    tester,
  ) async {
    const markdown = '''
- Top bullet
  - Nested bullet
1. First
2. Second
''';

    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: ReadingView(path: VaultPath('test.md'), text: markdown),
        ),
        size: const Size(600, 800),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('•'), findsOneWidget);
    expect(find.text('◦'), findsOneWidget);
    expect(find.text('1.'), findsOneWidget);
    expect(find.text('2.'), findsOneWidget);
  });

  testWidgets('renders ordered list starting at custom number', (tester) async {
    const markdown = '7. Seventh\n8. Eighth';

    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: ReadingView(path: VaultPath('test.md'), text: markdown),
        ),
        size: const Size(600, 800),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('7.'), findsOneWidget);
    expect(find.text('8.'), findsOneWidget);
  });

  testWidgets('loose list has larger vertical gap than tight list', (
    tester,
  ) async {
    const tightMarkdown = '1. Tight 1\n2. Tight 2';
    const looseMarkdown = '1. Loose 1\n\n2. Loose 2';

    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: ReadingView(path: VaultPath('test.md'), text: tightMarkdown),
        ),
        size: const Size(600, 800),
      ),
    );
    await tester.pumpAndSettle();

    final tightPos1 = tester.getTopLeft(find.text('1.'));
    final tightPos2 = tester.getTopLeft(find.text('2.'));
    final tightDelta = (tightPos2.dy - tightPos1.dy).abs();

    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: ReadingView(path: VaultPath('test.md'), text: looseMarkdown),
        ),
        size: const Size(600, 800),
      ),
    );
    await tester.pumpAndSettle();

    final loosePos1 = tester.getTopLeft(find.text('1.'));
    final loosePos2 = tester.getTopLeft(find.text('2.'));
    final looseDelta = (loosePos2.dy - loosePos1.dy).abs();

    expect(looseDelta, greaterThan(tightDelta));
  });

  testWidgets('blockquote renders container with quote key and border', (
    tester,
  ) async {
    const markdown = '> Quoted speech';

    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: ReadingView(path: VaultPath('test.md'), text: markdown),
        ),
        size: const Size(600, 800),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('quote:0')), findsOneWidget);
    expect(find.text('Quoted speech'), findsOneWidget);
  });

  testWidgets('thematic break renders a Divider', (tester) async {
    const markdown = 'Above\n\n---\n\nBelow';

    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: ReadingView(path: VaultPath('test.md'), text: markdown),
        ),
        size: const Size(600, 800),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Divider), findsOneWidget);
  });

  testWidgets('math block is visible in mono font', (tester) async {
    const markdown = '\$\$\nx = y^2\n\$\$';

    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: ReadingView(path: VaultPath('test.md'), text: markdown),
        ),
        size: const Size(600, 800),
      ),
    );
    await tester.pumpAndSettle();

    final mathTextFinder = find.text('x = y^2');
    expect(mathTextFinder, findsOneWidget);
    final mathText = tester.widget<Text>(mathTextFinder);
    expect(mathText.style?.fontFamily, equals('monospace'));
  });

  testWidgets(
    'html block shows raw text, comment-only HTML block is not rendered',
    (tester) async {
      const markdown =
          '<div>visible html</div>\n\n<!-- hidden html comment -->';

      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: ReadingView(path: VaultPath('test.md'), text: markdown),
          ),
          size: const Size(600, 800),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('<div>visible html</div>'), findsOneWidget);
      expect(find.text('<!-- hidden html comment -->'), findsNothing);
    },
  );

  testWidgets('frontmatter and comment blocks are not rendered', (
    tester,
  ) async {
    const markdown = '''---
title: Secret
---

%%
hidden comment
%%

Visible content
''';

    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: ReadingView(path: VaultPath('test.md'), text: markdown),
        ),
        size: const Size(600, 800),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('title: Secret'), findsNothing);
    expect(find.text('hidden comment'), findsNothing);
    expect(find.text('Visible content'), findsOneWidget);
  });

  testWidgets(
    'footnote section appears only with references and numbers by first reference',
    (tester) async {
      const markdown = '''
Reference [^b] and [^a].

Unused footnote definition:

[^unused]: Never referenced.

[^a]: Definition of A.
[^b]: Definition of B.
''';

      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: ReadingView(path: VaultPath('test.md'), text: markdown),
          ),
          size: const Size(600, 800),
        ),
      );
      await tester.pumpAndSettle();

      // In markdown, [^b] is referenced first, then [^a].
      // So [^b] receives number 1, [^a] receives number 2.
      expect(find.byKey(const Key('footnote:b')), findsOneWidget);
      expect(find.byKey(const Key('footnote:a')), findsOneWidget);
      expect(find.byKey(const Key('footnote:unused')), findsNothing);

      expect(find.text('Definition of B.'), findsOneWidget);
      expect(find.text('Definition of A.'), findsOneWidget);
      expect(find.text('Never referenced.'), findsNothing);
    },
  );
}
