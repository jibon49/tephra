// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/bookmarks/bookmark.dart';
import 'package:tephra_core/tephra_core.dart';

void main() {
  group('Bookmark JSON Serialization', () {
    test('Obsidian sample round-trips to identical decoded map', () {
      const rawJson =
          '{"items":[{"type":"file","ctime":1,"path":"A.md"},{"type":"file","ctime":2,"path":"A.md","subpath":"#Intro","title":"Intro"},{"type":"group","ctime":3,"title":"G","items":[{"type":"search","ctime":4,"query":"tag:#x"},{"type":"folder","ctime":5,"path":"F"}]},{"type":"graph","ctime":6,"options":{"a":1}}],"custom":true}';

      final Map<String, Object?> originalMap = (jsonDecode(rawJson) as Map)
          .cast<String, Object?>();

      final doc = BookmarksDocument.fromJson(originalMap);

      expect(doc.extra['custom'], equals(true));
      expect(doc.items.length, equals(4));

      // 1. File bookmark
      final b1 = doc.items[0] as FileBookmark;
      expect(b1.ctime, equals(1));
      expect(b1.path, equals(VaultPath('A.md')));
      expect(b1.subpath, isNull);
      expect(b1.title, isNull);

      // 2. File bookmark with subpath and title
      final b2 = doc.items[1] as FileBookmark;
      expect(b2.ctime, equals(2));
      expect(b2.path, equals(VaultPath('A.md')));
      expect(b2.subpath, equals('#Intro'));
      expect(b2.title, equals('Intro'));

      // 3. Group bookmark
      final b3 = doc.items[2] as GroupBookmark;
      expect(b3.ctime, equals(3));
      expect(b3.title, equals('G'));
      expect(b3.items.length, equals(2));

      final g1 = b3.items[0] as SearchBookmark;
      expect(g1.ctime, equals(4));
      expect(g1.query, equals('tag:#x'));

      final g2 = b3.items[1] as FolderBookmark;
      expect(g2.ctime, equals(5));
      expect(g2.path, equals(VaultPath('F')));

      // 4. Unknown bookmark (type 'graph' with extra options)
      final b4 = doc.items[3] as UnknownBookmark;
      expect(b4.ctime, equals(6));
      expect(b4.raw['type'], equals('graph'));
      expect(b4.raw['options'], equals({'a': 1}));

      // Serialize back to JSON and compare decoded maps
      final serializedMap = doc.toJson();
      expect(serializedMap, equals(originalMap));
    });
  });
}
