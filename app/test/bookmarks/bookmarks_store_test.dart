// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/bookmarks/bookmark.dart';
import 'package:tephra/bookmarks/bookmarks_store.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

void main() {
  group('BookmarksStore', () {
    late MemoryVaultFileSystem fs;
    late BookmarksStore store;

    setUp(() {
      fs = MemoryVaultFileSystem();
      store = BookmarksStore(fs);
    });

    test('add/remove/move/rename persist across store reloads', () async {
      await store.load();
      expect(store.items, isEmpty);

      // Add a file bookmark
      final b1 = FileBookmark(
        ctime: 100,
        path: VaultPath('Note1.md'),
        title: 'My Note 1',
      );
      await store.add(b1);
      expect(store.items.length, equals(1));
      expect(store.isBookmarked(VaultPath('Note1.md')), isTrue);

      // Add a group bookmark
      final group = GroupBookmark(
        ctime: 200,
        title: 'Group A',
        items: const [],
      );
      await store.add(group);
      expect(store.items.length, equals(2));

      // Add a search bookmark into group
      final searchB = SearchBookmark(ctime: 300, query: 'tag:#work');
      await store.add(searchB, into: group);

      // Reload store from fs to verify persistence
      final store2 = BookmarksStore(fs);
      await store2.load();
      expect(store2.items.length, equals(2));
      final reloadedGroup = store2.items[1] as GroupBookmark;
      expect(reloadedGroup.items.length, equals(1));
      expect(reloadedGroup.items.first, isA<SearchBookmark>());

      // Move search bookmark to root
      final currentSearchB = reloadedGroup.items.first;
      await store2.move(currentSearchB, null, 0);
      expect(store2.items.length, equals(3));
      expect(store2.items.first, equals(currentSearchB));

      // Rename bookmark
      await store2.rename(b1, 'Renamed Note');
      final updatedB1 = store2.items.firstWhere(
        (i) => i is FileBookmark && i.path == VaultPath('Note1.md'),
      );
      expect(updatedB1.title, equals('Renamed Note'));

      // Remove bookmark
      await store2.remove(updatedB1);
      expect(store2.items.length, equals(2));
      expect(store2.isBookmarked(VaultPath('Note1.md')), isFalse);
    });

    test('retarget updates file and folder bookmarks after renames', () async {
      await store.load();

      final f1 = FileBookmark(ctime: 1, path: VaultPath('Docs/Old.md'));
      final folder1 = FolderBookmark(ctime: 2, path: VaultPath('Docs'));
      final fInside = FileBookmark(
        ctime: 3,
        path: VaultPath('Docs/Sub/Inside.md'),
      );
      final group = GroupBookmark(
        ctime: 4,
        title: 'MyGroup',
        items: [FileBookmark(ctime: 5, path: VaultPath('Old2.md'))],
      );

      await store.add(f1);
      await store.add(folder1);
      await store.add(fInside);
      await store.add(group);

      // Retarget individual file move: Old2.md -> New2.md
      await store.retarget({VaultPath('Old2.md'): VaultPath('New2.md')});
      final updatedGroup = store.items.last as GroupBookmark;
      expect(
        (updatedGroup.items.first as FileBookmark).path,
        equals(VaultPath('New2.md')),
      );

      // Retarget folder move: Docs -> Archive/Docs
      await store.retarget(
        {},
        folderMove: (VaultPath('Docs'), VaultPath('Archive/Docs')),
      );

      final updatedF1 = store.items[0] as FileBookmark;
      expect(updatedF1.path, equals(VaultPath('Archive/Docs/Old.md')));

      final updatedFolder1 = store.items[1] as FolderBookmark;
      expect(updatedFolder1.path, equals(VaultPath('Archive/Docs')));

      final updatedFInside = store.items[2] as FileBookmark;
      expect(
        updatedFInside.path,
        equals(VaultPath('Archive/Docs/Sub/Inside.md')),
      );
    });

    test('undo restores previous bookmarks JSON exactly', () async {
      await store.load();

      final b1 = FileBookmark(ctime: 1, path: VaultPath('A.md'));
      await store.add(b1);

      // Save raw JSON before rename/change
      final savedRaw = await store.rawJson();
      expect(savedRaw, isNotNull);

      // Mutate bookmarks
      await store.retarget({VaultPath('A.md'): VaultPath('B.md')});
      expect(
        (store.items.first as FileBookmark).path,
        equals(VaultPath('B.md')),
      );

      // Undo / restore
      await store.restoreJson(savedRaw!);
      expect(
        (store.items.first as FileBookmark).path,
        equals(VaultPath('A.md')),
      );
    });
  });
}
