// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/tags/tag_tree.dart';
import 'package:tephra_index/tephra_index.dart';

void main() {
  group('TagTree', () {
    final tags = [
      const TagCount(tag: 'a', tagLower: 'a', count: 2, directCount: 0),
      const TagCount(tag: 'a/b', tagLower: 'a/b', count: 1, directCount: 1),
      const TagCount(tag: 'A/c', tagLower: 'a/c', count: 1, directCount: 1),
    ];

    test('tags a(2), a/b(1), A/c(1) -> root a count 2, children b, c', () {
      final tree = buildTagTree(tags);

      expect(tree.length, equals(1));
      final root = tree.first;
      expect(root.segment.toLowerCase(), equals('a'));
      expect(root.count, equals(2));
      expect(root.children.length, equals(2));

      final childB = root.children.firstWhere((c) => c.segment == 'b');
      expect(childB.count, equals(1));
      expect(childB.fullTag, equals('a/b'));
      expect(childB.children, isEmpty);

      final childC = root.children.firstWhere((c) => c.segment == 'c');
      expect(childC.count, equals(1));
      expect(childC.fullTag, equals('A/c'));
      expect(childC.children, isEmpty);
    });

    test('flat mode lists 3 tags', () {
      final flat = buildFlatTagList(tags);

      expect(flat.length, equals(3));
      final names = flat.map((n) => n.segment).toList();
      expect(names, containsAll(['a', 'a/b', 'A/c']));
    });

    test('frequency sort ranks highest count first with tie break', () {
      final sample = [
        const TagCount(
          tag: 'zebra',
          tagLower: 'zebra',
          count: 1,
          directCount: 1,
        ),
        const TagCount(
          tag: 'alpha',
          tagLower: 'alpha',
          count: 5,
          directCount: 5,
        ),
        const TagCount(tag: 'beta', tagLower: 'beta', count: 5, directCount: 5),
      ];

      final tree = buildTagTree(sample, sortMode: TagSortMode.frequency);
      expect(
        tree.map((n) => n.segment).toList(),
        equals(['alpha', 'beta', 'zebra']),
      );
    });

    test('alphabetical sort ranks A to Z', () {
      final sample = [
        const TagCount(
          tag: 'zebra',
          tagLower: 'zebra',
          count: 10,
          directCount: 10,
        ),
        const TagCount(
          tag: 'alpha',
          tagLower: 'alpha',
          count: 1,
          directCount: 1,
        ),
        const TagCount(tag: 'beta', tagLower: 'beta', count: 5, directCount: 5),
      ];

      final tree = buildTagTree(sample, sortMode: TagSortMode.nameAZ);
      expect(
        tree.map((n) => n.segment).toList(),
        equals(['alpha', 'beta', 'zebra']),
      );
    });
  });
}
