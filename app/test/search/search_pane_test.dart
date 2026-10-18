// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/commands/builtin_commands.dart';
import 'package:tephra/commands/command_registry.dart';
import 'package:tephra/search/providers.dart';
import 'package:tephra/search/search_pane.dart';
import 'package:tephra/search/search_screen.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_search/tephra_search.dart';

import '../helpers/test_app.dart';

void main() {
  group('SearchPane', () {
    testWidgets('results grouped with counts', (tester) async {
      final fakeResults = [
        SearchResult(VaultPath('Alpha.md'), const [
          SearchMatch(
            line: 0,
            start: 0,
            end: 4,
            snippet: 'First snippet in Alpha',
            snippetStart: 0,
            snippetEnd: 4,
          ),
          SearchMatch(
            line: 1,
            start: 10,
            end: 15,
            snippet: 'Second snippet in Alpha',
            snippetStart: 0,
            snippetEnd: 5,
          ),
        ]),
        SearchResult(VaultPath('Folder/Beta.md'), const [
          SearchMatch(
            line: 5,
            start: 20,
            end: 25,
            snippet: 'Only snippet in Beta',
            snippetStart: 0,
            snippetEnd: 5,
          ),
        ]),
      ];

      Stream<SearchResult> fakeRunner(
        SearchExpr expr, {
        CancelToken? cancel,
        SearchSort sort = SearchSort.fileNameAsc,
        bool matchCase = false,
      }) {
        return Stream.fromIterable(fakeResults);
      }

      await tester.pumpWidget(
        testApp(
          const Scaffold(body: SearchPane()),
          overrides: [searchRunnerProvider.overrideWithValue(fakeRunner)],
        ),
      );
      await tester.pumpAndSettle();

      // Enter query
      await tester.enterText(find.byType(TextField), 'test');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Note titles
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      expect(find.text('Folder'), findsOneWidget);

      // Match count badges
      expect(find.text('2'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);

      // Match snippets
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is RichText &&
              w.text.toPlainText().contains('First snippet in Alpha'),
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is RichText &&
              w.text.toPlainText().contains('Second snippet in Alpha'),
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is RichText &&
              w.text.toPlainText().contains('Only snippet in Beta'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('"Collapse results" hides match rows', (tester) async {
      final fakeResults = [
        SearchResult(VaultPath('Alpha.md'), const [
          SearchMatch(
            line: 0,
            start: 0,
            end: 4,
            snippet: 'Collapsible snippet in Alpha',
            snippetStart: 0,
            snippetEnd: 4,
          ),
        ]),
      ];

      Stream<SearchResult> fakeRunner(
        SearchExpr expr, {
        CancelToken? cancel,
        SearchSort sort = SearchSort.fileNameAsc,
        bool matchCase = false,
      }) {
        return Stream.fromIterable(fakeResults);
      }

      await tester.pumpWidget(
        testApp(
          const Scaffold(body: SearchPane()),
          overrides: [searchRunnerProvider.overrideWithValue(fakeRunner)],
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'test');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is RichText &&
              w.text.toPlainText().contains('Collapsible snippet in Alpha'),
        ),
        findsOneWidget,
      );

      // Tap collapse all button
      final collapseIcon = find.byIcon(Icons.unfold_less);
      expect(collapseIcon, findsOneWidget);
      await tester.tap(collapseIcon);
      await tester.pumpAndSettle();

      // Snippet should now be hidden
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is RichText &&
              w.text.toPlainText().contains('Collapsible snippet in Alpha'),
        ),
        findsNothing,
      );

      // Tap expand all button
      final expandIcon = find.byIcon(Icons.unfold_more);
      expect(expandIcon, findsOneWidget);
      await tester.tap(expandIcon);
      await tester.pumpAndSettle();

      // Snippet should be visible again
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is RichText &&
              w.text.toPlainText().contains('Collapsible snippet in Alpha'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('history list shown for an empty focused field', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          const Scaffold(body: SearchPane()),
          overrides: [
            searchHistoryProvider.overrideWith(
              () => _TestSearchHistoryNotifier(['meeting notes', 'todo query']),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Initially unfocused, history is not visible
      expect(find.text('Recent searches'), findsNothing);
      expect(find.text('meeting notes'), findsNothing);

      // Focus text field
      await tester.showKeyboard(find.byType(TextField));
      await tester.pumpAndSettle();

      // Now history is visible
      expect(find.text('Recent searches'), findsOneWidget);
      expect(find.text('meeting notes'), findsOneWidget);
      expect(find.text('todo query'), findsOneWidget);

      // Tap history item
      await tester.tap(find.text('meeting notes'));
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, equals('meeting notes'));
    });

    testWidgets('at 400 dp the command pushes SearchScreen', (tester) async {
      final registry = CommandRegistry();
      registerBuiltinCommands(registry);

      await tester.pumpWidget(
        testApp(
          Consumer(
            builder: (context, ref, _) {
              return ElevatedButton(
                onPressed: () {
                  registry.byId('search.open')!.run(ref, context);
                },
                child: const Text('Open Search'),
              );
            },
          ),
          size: const Size(400, 800),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Search'));
      await tester.pumpAndSettle();

      expect(find.byType(SearchScreen), findsOneWidget);
    });
  });
}

class _TestSearchHistoryNotifier extends SearchHistoryNotifier {
  _TestSearchHistoryNotifier(this._initialQueries);

  final List<String> _initialQueries;

  @override
  Future<List<String>> build() async {
    return _initialQueries;
  }
}
