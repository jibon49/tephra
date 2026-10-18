// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/l10n/app_localizations.dart';
import 'package:tephra/search/providers.dart';
import 'package:tephra/tags/providers.dart';
import 'package:tephra/tags/tags_pane.dart';
import 'package:tephra_index/tephra_index.dart';

void main() {
  testWidgets('tags_pane shows tree and tapping a tag sets search query', (
    tester,
  ) async {
    const sampleTags = [
      TagCount(tag: 'a', tagLower: 'a', count: 2, directCount: 0),
      TagCount(tag: 'a/b', tagLower: 'a/b', count: 1, directCount: 1),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tagListProvider.overrideWith((ref) => Future.value(sampleTags)),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: TagsPane()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Root tag 'a' is displayed
    expect(find.text('#a'), findsOneWidget);

    // Expand node 'a' by tapping chevron
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    // Child 'b' is visible
    expect(find.text('#b'), findsOneWidget);

    final element = tester.element(find.byType(TagsPane));
    final container = ProviderScope.containerOf(element);

    // Tap child 'b'
    await tester.tap(find.text('#b'));
    await tester.pumpAndSettle();

    // Verify search controller query was set to 'tag:#a/b'
    expect(container.read(searchControllerProvider).query, equals('tag:#a/b'));
  });

  testWidgets('tags_pane toggles between nested and flat modes', (
    tester,
  ) async {
    const sampleTags = [
      TagCount(tag: 'a', tagLower: 'a', count: 2, directCount: 0),
      TagCount(tag: 'a/b', tagLower: 'a/b', count: 1, directCount: 1),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tagListProvider.overrideWith((ref) => Future.value(sampleTags)),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: TagsPane()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Toggle flat mode
    await tester.tap(find.byIcon(Icons.account_tree_outlined));
    await tester.pumpAndSettle();

    // In flat mode, both 'a' and 'a/b' are directly visible without expanding
    expect(find.text('#a'), findsOneWidget);
    expect(find.text('#a/b'), findsOneWidget);
  });
}
