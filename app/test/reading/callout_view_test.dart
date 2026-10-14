// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/reading/callout_styles.dart';
import 'package:tephra/reading/callout_view.dart';
import 'package:tephra/reading/reading_scope.dart';
import 'package:tephra/reading/reading_styles.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_markdown/tephra_markdown.dart';

void main() {
  group('CalloutStyle', () {
    test('returns exact style for all 27 documented types and aliases', () {
      const expected = <String, (int, IconData)>{
        'note': (0xFF086DDD, Icons.edit_outlined),
        'abstract': (0xFF00BFBC, Icons.assignment_outlined),
        'summary': (0xFF00BFBC, Icons.assignment_outlined),
        'tldr': (0xFF00BFBC, Icons.assignment_outlined),
        'info': (0xFF086DDD, Icons.info_outline),
        'todo': (0xFF086DDD, Icons.check_circle_outline),
        'tip': (0xFF00BFBC, Icons.local_fire_department_outlined),
        'hint': (0xFF00BFBC, Icons.local_fire_department_outlined),
        'important': (0xFF00BFBC, Icons.local_fire_department_outlined),
        'success': (0xFF08B94E, Icons.check),
        'check': (0xFF08B94E, Icons.check),
        'done': (0xFF08B94E, Icons.check),
        'question': (0xFFDB7800, Icons.help_outline),
        'help': (0xFFDB7800, Icons.help_outline),
        'faq': (0xFFDB7800, Icons.help_outline),
        'warning': (0xFFDB7800, Icons.warning_amber_outlined),
        'caution': (0xFFDB7800, Icons.warning_amber_outlined),
        'attention': (0xFFDB7800, Icons.warning_amber_outlined),
        'failure': (0xFFE9314C, Icons.close),
        'fail': (0xFFE9314C, Icons.close),
        'missing': (0xFFE9314C, Icons.close),
        'danger': (0xFFE9314C, Icons.bolt),
        'error': (0xFFE9314C, Icons.bolt),
        'bug': (0xFFE9314C, Icons.bug_report_outlined),
        'example': (0xFF7852EE, Icons.format_list_bulleted),
        'quote': (0xFF9E9E9E, Icons.format_quote),
        'cite': (0xFF9E9E9E, Icons.format_quote),
      };

      expect(expected.length, equals(27));

      for (final entry in expected.entries) {
        final style = calloutStyleFor(entry.key);
        expect(
          style.color.toARGB32(),
          equals(entry.value.$1),
          reason: 'Color for ${entry.key}',
        );
        expect(
          style.icon,
          equals(entry.value.$2),
          reason: 'Icon for ${entry.key}',
        );
      }
    });

    test('case-insensitivity and fallback to note style for unknown', () {
      final warningStyle = calloutStyleFor('WARNING');
      expect(warningStyle.color.toARGB32(), equals(0xFFDB7800));
      expect(warningStyle.icon, equals(Icons.warning_amber_outlined));

      final unknownStyle = calloutStyleFor('custom-unknown');
      final noteStyle = calloutStyleFor('note');
      expect(unknownStyle.color, equals(noteStyle.color));
      expect(unknownStyle.icon, equals(noteStyle.icon));
    });
  });

  group('CalloutView widget', () {
    Widget buildTestHarness({
      required MdCallout callout,
      Set<int> toggledCallouts = const {},
      void Function(int)? onToggleCallout,
    }) {
      final doc = MarkdownParser.parse('');
      return MaterialApp(
        home: Scaffold(
          body: ReadingScope(
            path: VaultPath('test.md'),
            parsed: doc,
            text: '',
            styles: ReadingStyles.of(ThemeData.light(), 16),
            footnoteNumbers: const <String, int>{},
            readOnly: false,
            toggledCallouts: toggledCallouts,
            onToggleCallout: onToggleCallout,
            child: CalloutView(node: callout),
          ),
        ),
      );
    }

    testWidgets('renders custom default title with first letter capitalised', (
      tester,
    ) async {
      final callout = MdCallout(
        0,
        20,
        type: 'custom-type',
        title: null,
        children: [
          MdParagraph(10, 20, children: [MdText(10, 20, text: 'Body')]),
        ],
      );

      await tester.pumpWidget(buildTestHarness(callout: callout));
      expect(find.text('Custom-type'), findsOneWidget);
      expect(find.text('Body'), findsOneWidget);
    });

    testWidgets(
      'foldable expanded callout starts expanded and toggling calls callback',
      (tester) async {
        int? toggledOffset;
        final callout = MdCallout(
          100,
          150,
          type: 'note',
          title: 'Expandable',
          fold: CalloutFold.expanded,
          children: [
            MdParagraph(
              110,
              150,
              children: [MdText(110, 150, text: 'Inner content')],
            ),
          ],
        );

        await tester.pumpWidget(
          buildTestHarness(
            callout: callout,
            onToggleCallout: (offset) => toggledOffset = offset,
          ),
        );

        expect(find.text('Inner content'), findsOneWidget);
        expect(find.byIcon(Icons.expand_more), findsOneWidget);

        await tester.tap(find.text('Expandable'));
        expect(toggledOffset, equals(100));
      },
    );

    testWidgets('foldable collapsed callout starts collapsed and hides body', (
      tester,
    ) async {
      final callout = MdCallout(
        200,
        250,
        type: 'faq',
        title: 'Questions',
        fold: CalloutFold.collapsed,
        children: [
          MdParagraph(
            210,
            250,
            children: [MdText(210, 250, text: 'Hidden body')],
          ),
        ],
      );

      await tester.pumpWidget(buildTestHarness(callout: callout));
      expect(find.text('Hidden body'), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('fold == none ignores taps', (tester) async {
      bool tapped = false;
      final callout = MdCallout(
        300,
        350,
        type: 'note',
        title: 'Static',
        fold: CalloutFold.none,
        children: [
          MdParagraph(310, 350, children: [MdText(310, 350, text: 'Body')]),
        ],
      );

      await tester.pumpWidget(
        buildTestHarness(
          callout: callout,
          onToggleCallout: (_) => tapped = true,
        ),
      );

      await tester.tap(find.text('Static'));
      expect(tapped, isFalse);
    });

    testWidgets('nested callout renders properly', (tester) async {
      final inner = MdCallout(
        420,
        450,
        type: 'question',
        title: 'Inner Q',
        children: [
          MdParagraph(430, 450, children: [MdText(430, 450, text: 'Answer')]),
        ],
      );
      final outer = MdCallout(
        400,
        460,
        type: 'note',
        title: 'Outer Note',
        children: [inner],
      );

      await tester.pumpWidget(buildTestHarness(callout: outer));
      expect(find.text('Outer Note'), findsOneWidget);
      expect(find.text('Inner Q'), findsOneWidget);
      expect(find.text('Answer'), findsOneWidget);
    });

    testWidgets('toggle state survives scrolling out of view and back', (
      tester,
    ) async {
      final toggled = <int>{500};
      final callout = MdCallout(
        500,
        550,
        type: 'note',
        title: 'Scroll Callout',
        fold: CalloutFold.collapsed,
        children: [
          MdParagraph(
            510,
            550,
            children: [MdText(510, 550, text: 'Revealed on toggle')],
          ),
        ],
      );

      final scrollController = ScrollController();
      final doc = MarkdownParser.parse('');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReadingScope(
              path: VaultPath('test.md'),
              parsed: doc,
              text: '',
              styles: ReadingStyles.of(ThemeData.light(), 16),
              footnoteNumbers: const <String, int>{},
              readOnly: false,
              toggledCallouts: toggled,
              child: ListView(
                controller: scrollController,
                children: [
                  CalloutView(node: callout),
                  const SizedBox(height: 2000),
                  const Text('Bottom marker'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Revealed on toggle'), findsOneWidget);

      // Scroll to bottom
      scrollController.jumpTo(1500);
      await tester.pumpAndSettle();
      expect(find.text('Scroll Callout'), findsNothing);

      // Scroll back to top
      scrollController.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.text('Scroll Callout'), findsOneWidget);
      expect(find.text('Revealed on toggle'), findsOneWidget);
    });
  });
}
