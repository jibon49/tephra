// © 2026 Tephra. All rights reserved.

import 'package:tephra_markdown/tephra_markdown.dart';
import 'package:test/test.dart';

void main() {
  group('splitFrontmatter', () {
    test('standard note frontmatter', () {
      const text = '---\ntitle: T\n---\nBody';
      final split = splitFrontmatter(text);
      expect(split, isNotNull);
      expect(split!.start, equals(0));
      expect(split.contentStart, equals(4));
      expect(split.yaml, equals('title: T'));
      expect(split.end, equals(16));
      expect(split.bodyStart, equals(17));
    });

    test('empty yaml block adjacent delimiters', () {
      const text = '---\n---\nx';
      final split = splitFrontmatter(text);
      expect(split, isNotNull);
      expect(split!.yaml, equals(''));
      expect(split.contentStart, equals(4));
      expect(split.end, equals(7));
      expect(split.bodyStart, equals(8));
    });

    test('delimiters with trailing spaces and tabs are accepted', () {
      const text = '---   \na: 1\n---  \nx';
      final split = splitFrontmatter(text);
      expect(split, isNotNull);
      expect(split!.yaml, equals('a: 1'));
    });

    test('unclosed frontmatter returns null', () {
      const text = '---\na: 1';
      expect(splitFrontmatter(text), isNull);
    });

    test('frontmatter not at line 0 returns null', () {
      const text = '\n---\na: 1\n---';
      expect(splitFrontmatter(text), isNull);
    });

    test('opening delimiter with text after dashes is rejected', () {
      const text = '--- x\na\n---';
      expect(splitFrontmatter(text), isNull);
    });

    test('closing delimiter at EOF without trailing newline sets bodyStart to text.length', () {
      const text = '---\na: 1\n---';
      final split = splitFrontmatter(text);
      expect(split, isNotNull);
      expect(split!.bodyStart, equals(text.length));
      expect(split.yaml, equals('a: 1'));
    });
  });

  group('decodeFrontmatterYaml', () {
    test('decodes maps, lists, strings, and nested maps', () {
      const yaml = 'tags: [a, b]\naliases: X\nn: {k: 1}';
      final map = decodeFrontmatterYaml(yaml);
      expect(map, isNotNull);
      expect(map!['tags'], equals(['a', 'b']));
      expect(map['aliases'], equals('X'));
      expect(map['n'], equals({'k': 1}));
    });

    test('malformed YAML returns null', () {
      const yaml = 'a: [1';
      expect(decodeFrontmatterYaml(yaml), isNull);
    });

    test('empty string returns empty map', () {
      expect(decodeFrontmatterYaml(''), equals(<String, Object?>{}));
      expect(decodeFrontmatterYaml('   \n  '), equals(<String, Object?>{}));
    });

    test('comment-only YAML returns empty map', () {
      expect(
        decodeFrontmatterYaml('# only comment'),
        equals(<String, Object?>{}),
      );
    });

    test('top-level non-map returns null', () {
      expect(decodeFrontmatterYaml('- a\n- b'), isNull);
      expect(decodeFrontmatterYaml('scalar string'), isNull);
    });

    test('dates stay strings', () {
      const yaml = 'd: 2026-01-01';
      final map = decodeFrontmatterYaml(yaml);
      expect(map, isNotNull);
      expect(map!['d'], isA<String>());
      expect(map['d'], equals('2026-01-01'));
    });
  });
}
