// © 2026 Tephra. All rights reserved.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/reading/inline_builder.dart';
import 'package:tephra/reading/inline_text.dart';
import 'package:tephra/reading/reading_scope.dart';
import 'package:tephra/reading/reading_styles.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_markdown/tephra_markdown.dart';

class CountingRecognizer extends TapGestureRecognizer {
  int disposeCount = 0;

  @override
  void dispose() {
    disposeCount++;
    super.dispose();
  }
}

void main() {
  group('InlineBuilder spans', () {
    Widget buildHarness(
      List<MdNode> nodes, {
      Map<String, int> footnoteNumbers = const <String, int>{},
    }) {
      final doc = MarkdownParser.parse('');
      return MaterialApp(
        home: Scaffold(
          body: ReadingScope(
            path: VaultPath('note.md'),
            parsed: doc,
            text: 'Test source text with <br> and [[Target#Heading]]',
            styles: ReadingStyles.of(ThemeData.light(), 16),
            footnoteNumbers: footnoteNumbers,
            readOnly: false,
            toggledCallouts: const {},
            child: InlineText(nodes: nodes),
          ),
        ),
      );
    }

    TextSpan getInlineSpan(WidgetTester tester) {
      final textWidget = tester.widget<Text>(
        find.descendant(
          of: find.byType(InlineText),
          matching: find.byType(Text),
        ),
      );
      return textWidget.textSpan! as TextSpan;
    }

    testWidgets('strong has weight 700', (tester) async {
      final nodes = [
        MdStrong(0, 10, children: [MdText(2, 8, text: 'bold')]),
      ];
      await tester.pumpWidget(buildHarness(nodes));
      final span = getInlineSpan(tester);
      final childSpan = span.children!.first as TextSpan;
      expect(childSpan.style?.fontWeight, equals(FontWeight.w700));
    });

    testWidgets('emphasis is italic', (tester) async {
      final nodes = [
        MdEmphasis(0, 10, children: [MdText(1, 9, text: 'italic')]),
      ];
      await tester.pumpWidget(buildHarness(nodes));
      final span = getInlineSpan(tester);
      final childSpan = span.children!.first as TextSpan;
      expect(childSpan.style?.fontStyle, equals(FontStyle.italic));
    });

    testWidgets('strikethrough has lineThrough decoration', (tester) async {
      final nodes = [
        MdStrikethrough(0, 10, children: [MdText(2, 8, text: 'strike')]),
      ];
      await tester.pumpWidget(buildHarness(nodes));
      final span = getInlineSpan(tester);
      final childSpan = span.children!.first as TextSpan;
      expect(childSpan.style?.decoration, equals(TextDecoration.lineThrough));
    });

    testWidgets('highlight has backgroundColor', (tester) async {
      final nodes = [
        MdHighlight(0, 10, children: [MdText(2, 8, text: 'mark')]),
      ];
      await tester.pumpWidget(buildHarness(nodes));
      final span = getInlineSpan(tester);
      final childSpan = span.children!.first as TextSpan;
      expect(childSpan.style?.backgroundColor, isNotNull);
    });

    testWidgets('inline code has monospace fontFamily and background', (
      tester,
    ) async {
      final nodes = [MdInlineCode(0, 6, code: 'code')];
      await tester.pumpWidget(buildHarness(nodes));
      final span = getInlineSpan(tester);
      final childSpan = span.children!.first as TextSpan;
      expect(childSpan.style?.fontFamily, equals('monospace'));
      expect(childSpan.style?.backgroundColor, isNotNull);
    });

    testWidgets('soft break and hard break produce newline', (tester) async {
      final nodes = [
        MdText(0, 1, text: 'a'),
        MdSoftBreak(1, 2),
        MdText(2, 3, text: 'b'),
        MdHardBreak(3, 4),
        MdText(4, 5, text: 'c'),
      ];
      await tester.pumpWidget(buildHarness(nodes));
      final span = getInlineSpan(tester);
      expect(span.toPlainText(), equals('a\nb\nc'));
    });

    testWidgets('comment and block-id have no visible text', (tester) async {
      final nodes = [
        MdCommentInline(0, 10, text: 'hidden comment'),
        MdBlockId(10, 20, id: 'heading-id'),
      ];
      await tester.pumpWidget(buildHarness(nodes));
      final span = getInlineSpan(tester);
      expect(span.toPlainText(), isEmpty);
    });

    testWidgets('<br> translates to newline, other HTML is muted literal', (
      tester,
    ) async {
      final nodes = [
        MdText(0, 1, text: 'a'),
        MdHtmlInline(1, 5, html: '<br>'),
        MdText(5, 6, text: 'b'),
        MdHtmlInline(6, 12, html: '<span>'),
      ];
      await tester.pumpWidget(buildHarness(nodes));
      final span = getInlineSpan(tester);
      expect(span.toPlainText(), equals('a\nb<span>'));
    });

    testWidgets('tag renders #name with background', (tester) async {
      final nodes = [MdTag(0, 4, name: 'tag')];
      await tester.pumpWidget(buildHarness(nodes));
      final span = getInlineSpan(tester);
      final childSpan = span.children!.first as TextSpan;
      expect(childSpan.text, equals('#tag'));
      expect(childSpan.style?.backgroundColor, isNotNull);
    });

    testWidgets('wikilink display format Note > Heading, alias, [[#Heading]]', (
      tester,
    ) async {
      final nodes = [
        MdWikiLink(0, 20, target: 'Note', heading: 'Heading'),
        MdWikiLink(20, 30, target: 'Note', alias: 'MyAlias'),
        MdWikiLink(30, 40, target: '', heading: 'Heading'),
      ];
      await tester.pumpWidget(buildHarness(nodes));
      final span = getInlineSpan(tester);
      final spans = span.children!.cast<TextSpan>();
      expect(spans[0].text, equals('Note > Heading'));
      expect(spans[1].text, equals('MyAlias'));
      expect(spans[2].text, equals('Heading'));
    });

    testWidgets('footnote ref shows number from scope', (tester) async {
      final nodes = [MdFootnoteRef(0, 4, label: 'fn1')];
      await tester.pumpWidget(
        buildHarness(nodes, footnoteNumbers: const {'fn1': 3}),
      );
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('recognizers are disposed when InlineText nodes are replaced', (
      tester,
    ) async {
      final created = <CountingRecognizer>[];
      final originalFactory = InlineBuilder.recognizerFactory;
      InlineBuilder.recognizerFactory = () {
        final r = CountingRecognizer();
        created.add(r);
        return r;
      };

      try {
        final node1 = [MdWikiLink(0, 10, target: 'Target1')];
        final node2 = [MdWikiLink(0, 10, target: 'Target2')];

        await tester.pumpWidget(buildHarness(node1));
        expect(created.length, equals(1));
        final firstRecognizer = created.first;
        expect(firstRecognizer.disposeCount, equals(0));

        // Update widget with new nodes
        await tester.pumpWidget(buildHarness(node2));
        expect(firstRecognizer.disposeCount, equals(1));
        expect(created.length, equals(2));
      } finally {
        InlineBuilder.recognizerFactory = originalFactory;
      }
    });
  });
}
