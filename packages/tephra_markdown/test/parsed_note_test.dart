// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:tephra_markdown/tephra_markdown.dart';
import 'package:test/test.dart';

void main() {
  group('ParsedNote and MarkdownParser', () {
    test('1. headings in order incl. nested', () {
      final note = MarkdownParser.parse('# A\n> ## B\n- ### C');
      expect(note.headings.length, 3);
      expect(note.headings[0].level, 1);
      expect(note.headings[1].level, 2);
      expect(note.headings[2].level, 3);
    });

    test('2. wikilinks and embeds collected', () {
      final note = MarkdownParser.parse('[[a]] ![[b.png]] [[c#h|x]]');
      expect(note.wikiLinks.length, 3);
      expect(note.wikiLinks.map((w) => w.embed).toList(), [false, true, false]);
    });

    test('3. links', () {
      final note = MarkdownParser.parse('[x](u) ![i](p.png) <http://z>');
      expect(note.links.length, 2);
      expect(note.links[0].image, false);
      expect(note.links[1].image, true);
    });

    test('4. inline tags then frontmatter tags, deduplicated', () {
      final note = MarkdownParser.parse('---\ntags: [b, "#c"]\n---\n#a #b');
      expect(note.tags, ['a', 'b', 'c']);
    });

    test('5. tags as string', () {
      final n1 = MarkdownParser.parse('---\ntags: "x, y z"\n---');
      expect(n1.tags, ['x', 'y', 'z']);

      final n2 = MarkdownParser.parse('---\ntag: solo\n---');
      expect(n2.tags, ['solo']);
    });

    test('6. aliases list and string', () {
      final n1 = MarkdownParser.parse('---\naliases: [A1, A2]\n---');
      expect(n1.aliases, ['A1', 'A2']);

      final n2 = MarkdownParser.parse('---\naliases: Solo\n---');
      expect(n2.aliases, ['Solo']);
    });

    test('7. frontmatter map and validity', () {
      final n1 = MarkdownParser.parse('---\ntitle: T\n---');
      expect(n1.frontmatter['title'], 'T');
      expect(n1.frontmatterValid, true);

      final n2 = MarkdownParser.parse('---\na: [1\n---');
      expect(n2.frontmatter, isEmpty);
      expect(n2.frontmatterValid, false);
      expect(n2.root.children.first, isA<MdFrontmatter>());

      final n3 = MarkdownParser.parse('No frontmatter');
      expect(n3.frontmatter, isEmpty);
      expect(n3.frontmatterValid, true);
    });

    test('8. block refs owners', () {
      final text =
          'Para ^p1\n\n- item ^i1\n  - child\n\n## Head ^h1\n\n> quote\n\n^q1';
      final note = MarkdownParser.parse(text);
      expect(note.blockIds.length, 4);

      final p1 = note.blockIds.firstWhere((b) => b.id == 'p1');
      final i1 = note.blockIds.firstWhere((b) => b.id == 'i1');
      final h1 = note.blockIds.firstWhere((b) => b.id == 'h1');
      final q1 = note.blockIds.firstWhere((b) => b.id == 'q1');

      for (final ref in note.blockIds) {
        expect(text.substring(ref.idStart, ref.idEnd), '^${ref.id}');
      }

      // Check owner ranges
      // p1 owner = the paragraph range
      final para = note.root.children.firstWhere((c) => c is MdParagraph);
      expect(p1.start, para.start);
      expect(p1.end, para.end);

      // i1 owner = the whole list item including - child
      final list = note.root.children.firstWhere((c) => c is MdList) as MdList;
      final item = list.children.first;
      expect(i1.start, item.start);
      expect(i1.end, item.end);

      // h1 owner = the heading
      final head = note.root.children.firstWhere((c) => c is MdHeading);
      expect(h1.start, head.start);
      expect(h1.end, head.end);

      // q1 owner = the block quote (previous sibling)
      final quote = note.root.children.firstWhere((c) => c is MdBlockQuote);
      expect(q1.start, quote.start);
      expect(q1.end, quote.end);
    });

    test('9. tasks', () {
      final note = MarkdownParser.parse('- [ ] a\n- [x] b ^t\n  - [/] c');
      expect(note.tasks.length, 3);
      expect(note.tasks.map((t) => t.status.char).toList(), [' ', 'x', '/']);
      expect(note.tasks[0].text, 'a');
      expect(note.tasks[1].text, 'b ^t');
      expect(note.tasks[2].text, 'c');
      expect(note.tasks.map((t) => t.line).toList(), [0, 1, 2]);
      expect(note.text[note.tasks[0].statusOffset], ' ');
      expect(note.text[note.tasks[1].statusOffset], 'x');
      expect(note.text[note.tasks[2].statusOffset], '/');
    });

    test('10. commonMark options give empty obsidian lists', () {
      final note = MarkdownParser.parseWith(
        '---\ntags: [a]\naliases: [b]\n---\n# H ^h1\n#tag\n[[link]]',
        const ParserOptions(obsidian: false),
      );
      expect(note.frontmatter, isEmpty);
      expect(note.tags, isEmpty);
      expect(note.aliases, isEmpty);
      expect(note.blockIds, isEmpty);
      expect(note.wikiLinks, isEmpty);
    });

    test('11. lines index matches text', () {
      final text = 'line 1\nline 2\nline 3';
      final note = MarkdownParser.parse(text);
      expect(note.lines.lineCount, 3);
    });

    test('12. huge note parses in time', () {
      // Find edge vault directory
      var edgeDir = Directory('../../test_vaults/edge');
      if (!edgeDir.existsSync()) {
        edgeDir = Directory('test_vaults/edge');
      }
      expect(edgeDir.existsSync(), isTrue);

      final hugeFile = File('${edgeDir.path}/huge-5000-lines.md');
      expect(hugeFile.existsSync(), isTrue);
      final hugeText = hugeFile.readAsStringSync();

      final swHuge = Stopwatch()..start();
      final parsedHuge = MarkdownParser.parse(hugeText);
      swHuge.stop();
      // ignore: avoid_print, required by phase 01.9 instructions to record duration for PROGRESS.md.
      print('HUGE_NOTE_PARSE_MS: ${swHuge.elapsedMilliseconds}');
      expect(swHuge.elapsedMilliseconds, lessThan(2000));
      expect(parsedHuge.lines.lineCount, greaterThan(4000));

      final longLineFile = File('${edgeDir.path}/long-line.md');
      expect(longLineFile.existsSync(), isTrue);
      final longLineText = longLineFile.readAsStringSync();

      final swLong = Stopwatch()..start();
      final parsedLong = MarkdownParser.parse(longLineText);
      swLong.stop();
      // ignore: avoid_print, required by phase 01.9 instructions to record duration for PROGRESS.md.
      print('LONG_LINE_PARSE_MS: ${swLong.elapsedMilliseconds}');
      expect(swLong.elapsedMilliseconds, lessThan(2000));
      expect(parsedLong.root.children, isNotEmpty);
    });
  });
}
