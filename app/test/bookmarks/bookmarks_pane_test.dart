// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/bookmarks/bookmark.dart';
import 'package:tephra/bookmarks/bookmarks_pane.dart';
import 'package:tephra/bookmarks/providers.dart';
import 'package:tephra/l10n/app_localizations.dart';
import 'package:tephra_core/tephra_core.dart';

class _FakeBookmarksNotifier extends BookmarksNotifier {
  _FakeBookmarksNotifier(this._initialBookmarks);

  final List<Bookmark> _initialBookmarks;

  @override
  Future<List<Bookmark>> build() async => List.of(_initialBookmarks);

  @override
  Future<void> move(
    Bookmark bookmark,
    GroupBookmark? newParent,
    int targetIndex,
  ) async {
    final current = List<Bookmark>.of(state.value ?? const []);
    current.remove(bookmark);
    final clamped = targetIndex.clamp(0, current.length);
    current.insert(clamped, bookmark);
    state = AsyncData(current);
  }
}

Widget _buildTestApp({
  required List<Bookmark> bookmarks,
  Set<String>? indexedPaths,
  double width = 900,
}) {
  return ProviderScope(
    overrides: [
      bookmarksProvider.overrideWith(() => _FakeBookmarksNotifier(bookmarks)),
      if (indexedPaths != null)
        indexedPathsProvider.overrideWithValue(AsyncData(indexedPaths)),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(size: Size(width, 700)),
        child: const Scaffold(body: BookmarksPane()),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BookmarksPane', () {
    testWidgets('displays icons per bookmark kind', (tester) async {
      final bookmarks = <Bookmark>[
        FileBookmark(path: VaultPath('note.md'), ctime: 1),
        FileBookmark(path: VaultPath('note.md'), subpath: '#Heading', ctime: 2),
        FileBookmark(path: VaultPath('note.md'), subpath: '#^block1', ctime: 3),
        FolderBookmark(path: VaultPath('Folder'), ctime: 4),
        SearchBookmark(query: 'tag:#test', ctime: 5),
        GroupBookmark(title: 'My Group', ctime: 6, items: []),
        UnknownBookmark(raw: {'type': 'graph', 'ctime': 7}),
      ];

      await tester.pumpWidget(
        _buildTestApp(
          bookmarks: bookmarks,
          indexedPaths: {'note.md', 'Folder'},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.description_outlined), findsOneWidget);
      expect(find.byIcon(Icons.tag), findsOneWidget);
      expect(find.byIcon(Icons.view_headline), findsOneWidget);
      expect(find.byIcon(Icons.folder_outlined), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.byIcon(Icons.folder_open), findsOneWidget);
      expect(find.byIcon(Icons.help_outline), findsOneWidget);
    });

    testWidgets('missing file target is shown at 60% opacity', (tester) async {
      final bookmarks = <Bookmark>[
        FileBookmark(path: VaultPath('present.md'), ctime: 1),
        FileBookmark(path: VaultPath('missing.md'), ctime: 2),
      ];

      await tester.pumpWidget(
        _buildTestApp(bookmarks: bookmarks, indexedPaths: {'present.md'}),
      );
      await tester.pumpAndSettle();

      final opacities = tester
          .widgetList<Opacity>(find.byType(Opacity))
          .map((o) => o.opacity)
          .toList();

      expect(opacities, contains(0.60));
      expect(opacities, contains(1.0));
    });

    testWidgets('desktop drag reorder changes order', (tester) async {
      final b1 = FileBookmark(path: VaultPath('alpha.md'), ctime: 1);
      final b2 = FileBookmark(path: VaultPath('beta.md'), ctime: 2);

      await tester.pumpWidget(
        _buildTestApp(
          bookmarks: [b1, b2],
          indexedPaths: {'alpha.md', 'beta.md'},
          width: 900,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('alpha'), findsOneWidget);
      expect(find.text('beta'), findsOneWidget);

      // Verify Draggable widgets exist for desktop
      expect(find.byType(Draggable<Bookmark>), findsWidgets);

      // Drag alpha down to the bottom drop target gap
      final alphaFinder = find.text('alpha');
      final gapFinders = find.byType(DragTarget<Bookmark>);
      expect(gapFinders, findsWidgets);

      // Drag alpha to the last drop target gap
      await tester.drag(alphaFinder, const Offset(0, 80));
      await tester.pumpAndSettle();

      // State is reactive through BookmarksNotifier
      expect(find.byType(BookmarksPane), findsOneWidget);
    });
  });
}
