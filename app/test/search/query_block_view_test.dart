// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/search/providers.dart';
import 'package:tephra/search/query_block_view.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_search/tephra_search.dart';

import '../helpers/test_app.dart';

void main() {
  group('QueryBlockView', () {
    testWidgets('valid query renders the count and titles', (tester) async {
      final fakeResults = [
        SearchResult(VaultPath('Alpha.md'), const [
          SearchMatch(
            line: 0,
            start: 0,
            end: 4,
            snippet: 'Snippet 1 in Alpha',
            snippetStart: 0,
            snippetEnd: 4,
          ),
        ]),
        SearchResult(VaultPath('Folder/Beta.md'), const [
          SearchMatch(
            line: 1,
            start: 0,
            end: 4,
            snippet: 'Snippet 2 in Beta',
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
          const Scaffold(
            body: SingleChildScrollView(
              child: QueryBlockView(query: 'test query'),
            ),
          ),
          overrides: [searchRunnerProvider.overrideWithValue(fakeRunner)],
        ),
      );
      await tester.pumpAndSettle();

      // Header with count
      expect(find.text('2 results'), findsOneWidget);

      // Note titles
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);

      // Snippets
      expect(find.text('Snippet 1 in Alpha'), findsOneWidget);
      expect(find.text('Snippet 2 in Beta'), findsOneWidget);
    });

    testWidgets('(a renders the error box', (tester) async {
      await tester.pumpWidget(
        testApp(
          const Scaffold(
            body: SingleChildScrollView(child: QueryBlockView(query: '(a')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Error icon
      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      // Error message contains syntax exception
      expect(find.textContaining('SearchSyntaxException'), findsOneWidget);
    });

    testWidgets('60 results → 50 rows + "Show all 60 results"', (tester) async {
      final fake60 = List.generate(
        60,
        (i) => SearchResult(VaultPath('Note$i.md'), [
          SearchMatch(
            line: 0,
            start: 0,
            end: 4,
            snippet: 'Snippet in note $i',
            snippetStart: 0,
            snippetEnd: 4,
          ),
        ]),
      );

      Stream<SearchResult> fakeRunner(
        SearchExpr expr, {
        CancelToken? cancel,
        SearchSort sort = SearchSort.fileNameAsc,
        bool matchCase = false,
      }) {
        return Stream.fromIterable(fake60);
      }

      await tester.pumpWidget(
        testApp(
          const Scaffold(
            body: SingleChildScrollView(
              child: QueryBlockView(query: 'all notes'),
            ),
          ),
          overrides: [searchRunnerProvider.overrideWithValue(fakeRunner)],
        ),
      );
      await tester.pumpAndSettle();

      // Header shows total count
      expect(find.text('60 results'), findsOneWidget);

      // First and 50th items are displayed
      expect(find.text('Note0'), findsOneWidget);
      expect(find.text('Note49'), findsOneWidget);

      // 51st item (index 50) is not displayed
      expect(find.text('Note50'), findsNothing);

      // Button to show all
      expect(find.text('Show all 60 results'), findsOneWidget);
    });
  });
}
