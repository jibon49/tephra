// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/src/extract/note_extractor.dart';
import 'package:tephra_index/src/model/link_record.dart';
import 'package:tephra_markdown/tephra_markdown.dart';
import 'package:test/test.dart';

void main() {
  group('NoteExtractor', () {
    test('case 1: headings and wikilinks with embed sizes', () {
      const text = '# Title\nText [[Other]] and ![[img.png|300]].';
      final parsed = MarkdownParser.parse(text);
      final extracted = NoteExtractor.extract(
        VaultPath('notes/Sample.md'),
        parsed,
      );

      expect(extracted.headings.length, equals(1));
      expect(extracted.headings.first.text, equals('Title'));
      expect(extracted.headings.first.level, equals(1));
      expect(extracted.headings.first.line, equals(0));

      expect(extracted.links.length, equals(2));
      final l1 = extracted.links[0];
      expect(l1.targetRaw, equals('Other'));
      expect(l1.targetKey, equals('other'));
      expect(l1.kind, equals(LinkKind.link));
      expect(l1.syntax, equals(LinkSyntax.wiki));
      expect(l1.line, equals(1));

      final l2 = extracted.links[1];
      expect(l2.targetRaw, equals('img.png'));
      expect(l2.targetKey, equals('img.png'));
      expect(l2.kind, equals(LinkKind.embed));
      expect(l2.syntax, equals(LinkSyntax.wiki));
      expect(l2.embedSize, equals('300'));
    });

    test(
      'case 2: wikilinks with heading, alias, local heading, and blockRef',
      () {
        const text = '[[Note#Sec|Shown]] [[#Local]] [[Note#^abc]]';
        final parsed = MarkdownParser.parse(text);
        final extracted = NoteExtractor.extract(VaultPath('sample.md'), parsed);

        expect(extracted.links.length, equals(3));
        final l1 = extracted.links[0];
        expect(l1.targetRaw, equals('Note'));
        expect(l1.heading, equals('Sec'));
        expect(l1.alias, equals('Shown'));

        final l2 = extracted.links[1];
        expect(l2.targetRaw, equals(''));
        expect(l2.heading, equals('Local'));
        expect(l2.alias, isNull);

        final l3 = extracted.links[2];
        expect(l3.targetRaw, equals('Note'));
        expect(l3.blockRef, equals('abc'));
      },
    );

    test('case 3: markdown links with percent-encoded URLs, external filtering and images', () {
      const text =
          '[a](Folder/My%20Note.md#Part%20Two) [b](https://x.y) [c](mailto:a@b) ![i](pics/p.png)';
      final parsed = MarkdownParser.parse(text);
      final extracted = NoteExtractor.extract(VaultPath('sample.md'), parsed);

      expect(extracted.links.length, equals(2));
      final l1 = extracted.links[0];
      expect(l1.targetRaw, equals('Folder/My Note.md'));
      expect(l1.heading, equals('Part Two'));
      expect(l1.alias, equals('a'));
      expect(l1.syntax, equals(LinkSyntax.markdown));
      expect(l1.kind, equals(LinkKind.link));

      final l2 = extracted.links[1];
      expect(l2.targetRaw, equals('pics/p.png'));
      expect(l2.syntax, equals(LinkSyntax.markdown));
      expect(l2.kind, equals(LinkKind.embed));
    });

    test('case 4: frontmatter properties, tags and aliases', () {
      const text = '''---
tags: [a, "#b"]
aliases: First
status: draft
n: 3
done: true
d: 2026-10-11
dt: 2026-10-11T09:30
list: [x, y]
empty:
---
Body #c''';
      final parsed = MarkdownParser.parse(text);
      final extracted = NoteExtractor.extract(VaultPath('sample.md'), parsed);

      expect(extracted.aliases, equals(['First']));

      // Tags: a, b (frontmatter, start null), c (inline)
      final tagNames = extracted.tags.map((t) => t.tag).toList();
      expect(tagNames, containsAll(['a', 'b', 'c']));
      final inlineTag = extracted.tags.firstWhere((t) => t.tag == 'c');
      expect(inlineTag.start, isNotNull);
      expect(inlineTag.line, equals(11));

      final fmTags = extracted.tags.where((t) => t.tag == 'a' || t.tag == 'b');
      for (final t in fmTags) {
        expect(t.start, isNull);
        expect(t.line, isNull);
      }

      // Check properties
      expect(
        extracted.properties.any(
          (p) =>
              p.key == 'status' &&
              p.valueType == 'text' &&
              p.valueText == 'draft',
        ),
        isTrue,
      );
      expect(
        extracted.properties.any(
          (p) => p.key == 'n' && p.valueType == 'number' && p.valueNum == 3.0,
        ),
        isTrue,
      );
      expect(
        extracted.properties.any(
          (p) =>
              p.key == 'done' &&
              p.valueType == 'checkbox' &&
              p.valueBool == true,
        ),
        isTrue,
      );
      expect(
        extracted.properties.any(
          (p) =>
              p.key == 'd' &&
              p.valueType == 'date' &&
              p.valueDate == '2026-10-11',
        ),
        isTrue,
      );
      expect(
        extracted.properties.any(
          (p) =>
              p.key == 'dt' &&
              p.valueType == 'datetime' &&
              p.valueDate == '2026-10-11T09:30',
        ),
        isTrue,
      );
      expect(
        extracted.properties
            .where((p) => p.key == 'list' && p.valueType == 'multitext')
            .length,
        equals(2),
      );
      expect(
        extracted.properties.any(
          (p) =>
              p.key == 'empty' && p.valueType == 'text' && p.valueText == null,
        ),
        isTrue,
      );
      expect(
        extracted.properties
            .where((p) => p.key == 'tags' && p.valueType == 'tags')
            .length,
        equals(2),
      );
      expect(
        extracted.properties
            .where((p) => p.key == 'aliases' && p.valueType == 'aliases')
            .length,
        equals(1),
      );
    });

    test('case 5: task list items with checkboxes and due dates', () {
      const text = '- [ ] call Bob 📅 2026-10-20\n- [x] done\n- [/] half';
      final parsed = MarkdownParser.parse(text);
      final extracted = NoteExtractor.extract(VaultPath('sample.md'), parsed);

      expect(extracted.tasks.length, equals(3));
      expect(extracted.tasks[0].statusChar, equals(' '));
      expect(extracted.tasks[0].due, equals('2026-10-20'));
      expect(extracted.tasks[1].statusChar, equals('x'));
      expect(extracted.tasks[1].due, isNull);
      expect(extracted.tasks[2].statusChar, equals('/'));
    });

    test('case 6: block reference owner identification (paragraph, list item, table)', () {
      const text = 'Para one ^p1\n\n- item ^i1\n\n| a |\n|---|\n| b |\n^t1';
      final parsed = MarkdownParser.parse(text);
      final extracted = NoteExtractor.extract(VaultPath('sample.md'), parsed);

      expect(
        parsed.blockIds.map((b) => b.id).toList(),
        equals(['p1', 'i1', 't1']),
      );
      expect(extracted.blocks.length, equals(3));
      final bP1 = extracted.blocks.firstWhere((b) => b.id == 'p1');
      expect(bP1.preview, contains('Para one'));

      final bI1 = extracted.blocks.firstWhere((b) => b.id == 'i1');
      expect(bI1.preview, contains('item'));

      final bT1 = extracted.blocks.firstWhere((b) => b.id == 't1');
      expect(bT1.preview, contains('| a |'));
    });

    test('case 7: invalid YAML frontmatter produces valid fallback', () {
      const text = '---\na: [\n---\nx';
      final parsed = MarkdownParser.parse(text);
      final extracted = NoteExtractor.extract(VaultPath('sample.md'), parsed);

      expect(extracted.frontmatterValid, isFalse);
      expect(extracted.properties, isEmpty);
      expect(extracted.frontmatterJson, equals('{}'));
      expect(extracted.aliases, isEmpty);
    });

    test('case 8: code blocks and inline code ignore links', () {
      const text = '`[[NotALink]]`\n```\n[[Nope]]\n```';
      final parsed = MarkdownParser.parse(text);
      final extracted = NoteExtractor.extract(VaultPath('sample.md'), parsed);

      expect(extracted.links, isEmpty);
    });
  });
}
