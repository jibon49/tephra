// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:tephra_markdown/tephra_markdown.dart';
import 'package:test/test.dart';

extension on MdNode {
  Iterable<MdNode> get descendants sync* {
    for (final child in children) {
      yield child;
      yield* child.descendants;
    }
  }
}

Directory _findSyntaxVaultDir() {
  var dir = Directory('../../test_vaults/syntax');
  if (dir.existsSync()) return dir;
  dir = Directory('test_vaults/syntax');
  if (dir.existsSync()) return dir;
  throw StateError('test_vaults/syntax not found');
}

void main() {
  final vaultDir = _findSyntaxVaultDir();

  String readNote(String relativePath) {
    final file = File('${vaultDir.path}/$relativePath');
    if (!file.existsSync()) {
      throw StateError('Note not found: ${file.path}');
    }
    return file.readAsStringSync();
  }

  test('01-headings.md', () {
    final text = readNote('01-headings.md');
    final note = MarkdownParser.parse(text);

    // 6 ATX + 2 setext + 2 more ## = 10 headings
    expect(note.headings.length, equals(10));
    expect(
      note.headings.map((h) => h.level).toList(),
      equals([1, 2, 3, 4, 5, 6, 1, 2, 2, 2]),
    );

    // #NotAHeadingButATag is a paragraph with one tag
    expect(note.tags, contains('NotAHeadingButATag'));

    // ####### Seven… is a paragraph
    final paras = note.root.descendants.whereType<MdParagraph>().toList();
    expect(
      paras.any((p) => text.substring(p.start, p.end).contains('Seven hashes')),
      isTrue,
    );

    // heading with ^heading-id has blockId == 'heading-id' and a BlockRef
    final blockIdHeading = note.headings.firstWhere(
      (h) => h.blockId == 'heading-id',
    );
    expect(blockIdHeading.blockId, equals('heading-id'));
    expect(note.blockIds.any((b) => b.id == 'heading-id'), isTrue);
  });

  test('02-paragraphs.md', () {
    final text = readNote('02-paragraphs.md');
    final note = MarkdownParser.parse(text);

    final hardBreaks = note.root.descendants.whereType<MdHardBreak>().toList();
    final softBreaks = note.root.descendants.whereType<MdSoftBreak>().toList();
    expect(hardBreaks.length, greaterThanOrEqualTo(1));
    expect(softBreaks.length, greaterThanOrEqualTo(1));
  });

  test('03-emphasis.md', () {
    final text = readNote('03-emphasis.md');
    final note = MarkdownParser.parse(text);

    final highlights = note.root.descendants.whereType<MdHighlight>().toList();
    final strikethroughs = note.root.descendants
        .whereType<MdStrikethrough>()
        .toList();
    expect(highlights.length, equals(2));
    expect(strikethroughs.length, equals(1));

    // No emphasis inside snake_case_words_stay_plain
    final emNodes = note.root.descendants.whereType<MdEmphasis>().toList();
    for (final em in emNodes) {
      final emText = text.substring(em.start, em.end);
      expect(emText.contains('snake_case'), isFalse);
    }
  });

  test('04-lists.md', () {
    final text = readNote('04-lists.md');
    final note = MarkdownParser.parse(text);

    final lists = note.root.descendants.whereType<MdList>().toList();
    // In 04-lists.md, '7. Starts at seven' follows '3. Third' after a blank line.
    // Per CommonMark 5.3, items with matching delimiter continue as a loose list
    // with startNumber == 1 (per phase note line 1305: assert real number in file).
    expect(lists.any((l) => l.ordered && l.startNumber == 1), isTrue);
    expect(lists.any((l) => !l.tight), isTrue);

    // Nested list of depth 3
    var maxDepth = 0;
    void checkDepth(MdNode node, int depth) {
      if (node is MdList) {
        if (depth > maxDepth) maxDepth = depth;
        for (final child in node.children) {
          checkDepth(child, depth + 1);
        }
      } else {
        for (final child in node.children) {
          checkDepth(child, depth);
        }
      }
    }

    checkDepth(note.root, 1);
    expect(maxDepth, greaterThanOrEqualTo(3));
  });

  test('05-tasks.md', () {
    final text = readNote('05-tasks.md');
    final note = MarkdownParser.parse(text);

    final statuses = note.tasks.map((t) => t.status.char).toList();
    expect(
      statuses.take(13).toList(),
      equals([' ', 'x', 'X', '/', '-', '>', '<', '?', '!', ' ', ' ', 'x', ' ']),
    );
    // '- [ ]Not a task...' is not a task
    expect(note.tasks.any((t) => t.text.contains('Not a task')), isFalse);
    expect(note.tasks.length, equals(14));
  });

  test('06-blockquotes.md', () {
    final text = readNote('06-blockquotes.md');
    final note = MarkdownParser.parse(text);

    final topLevelQuotes = note.root.children
        .whereType<MdBlockQuote>()
        .toList();
    expect(topLevelQuotes.length, equals(4));

    // One nested quote
    final allQuotes = note.root.descendants.whereType<MdBlockQuote>().toList();
    expect(allQuotes.length, greaterThan(topLevelQuotes.length));
  });

  test('07-callouts.md', () {
    final text = readNote('07-callouts.md');
    final note = MarkdownParser.parse(text);

    final callouts = note.root.descendants.whereType<MdCallout>().toList();
    const expected27 = [
      'note',
      'abstract',
      'summary',
      'tldr',
      'info',
      'todo',
      'tip',
      'hint',
      'important',
      'success',
      'check',
      'done',
      'question',
      'help',
      'faq',
      'warning',
      'caution',
      'attention',
      'failure',
      'fail',
      'missing',
      'danger',
      'error',
      'bug',
      'example',
      'quote',
      'cite',
    ];
    final first27Types = callouts.take(27).map((c) => c.type).toList();
    expect(first27Types, equals(expected27));

    // Foldable callout values: note (none), tip (expanded), warning (collapsed)
    final tipFoldable = callouts.firstWhere(
      (c) => c.type == 'tip' && c.fold != CalloutFold.none,
    );
    expect(tipFoldable.fold, equals(CalloutFold.expanded));

    final warnFoldable = callouts.firstWhere(
      (c) => c.type == 'warning' && c.fold != CalloutFold.none,
    );
    expect(warnFoldable.fold, equals(CalloutFold.collapsed));

    // Nested callout has a child MdCallout of type question
    final nestedOuter = callouts.firstWhere(
      (c) => c.descendants.whereType<MdCallout>().any(
        (inner) => inner.type == 'question',
      ),
    );
    expect(nestedOuter, isNotNull);

    // [!WARNING] gives type == 'warning'
    expect(callouts.any((c) => c.type == 'warning'), isTrue);

    // custom-type is a callout
    expect(callouts.any((c) => c.type == 'custom-type'), isTrue);
  });

  test('08-code.md', () {
    final text = readNote('08-code.md');
    final note = MarkdownParser.parse(text);

    final fencedBlocks = note.root.descendants
        .whereType<MdCodeBlock>()
        .where((c) => c.fenced)
        .toList();
    final languages = fencedBlocks.map((c) => c.language).toList();
    expect(languages, contains('dart'));
    expect(languages, contains('python'));
    expect(languages, contains(null));

    // codeBlocks length equals number of fences in the file divided by 2
    final fenceLineCount = text
        .split('\n')
        .where((l) => l.startsWith('```') || l.startsWith('~~~'))
        .length;
    expect(fencedBlocks.length, equals(fenceLineCount ~/ 2));
  });

  test('09-tables.md', () {
    final text = readNote('09-tables.md');
    final note = MarkdownParser.parse(text);

    final tables = note.root.descendants.whereType<MdTable>().toList();
    expect(tables.length, greaterThanOrEqualTo(2));

    expect(
      tables.any(
        (t) =>
            t.aligns.length >= 3 &&
            t.aligns[0] == TableAlign.left &&
            t.aligns[1] == TableAlign.center &&
            t.aligns[2] == TableAlign.right,
      ),
      isTrue,
    );

    // One cell containing an escaped pipe (a | b)
    final cells = note.root.descendants.whereType<MdTableCell>().toList();
    expect(
      cells.any((c) => text.substring(c.start, c.end).contains(r'\|')),
      isTrue,
    );
  });

  test('10-links.md', () {
    final text = readNote('10-links.md');
    final note = MarkdownParser.parse(text);

    expect(note.links.where((l) => !l.image).length, greaterThanOrEqualTo(1));
    expect(
      note.root.descendants.whereType<MdAutolink>().length,
      greaterThanOrEqualTo(1),
    );
    expect(note.links.where((l) => l.image).length, greaterThanOrEqualTo(1));
  });

  test('11-wikilinks.md', () {
    final text = readNote('11-wikilinks.md');
    final note = MarkdownParser.parse(text);

    expect(note.wikiLinks.length, greaterThanOrEqualTo(8));
    expect(note.wikiLinks.any((w) => w.heading != null), isTrue);
    expect(note.wikiLinks.any((w) => w.blockRef != null), isTrue);
    expect(note.wikiLinks.any((w) => w.alias != null), isTrue);
  });

  test('Folder/Nested Note.md', () {
    final text = readNote('Folder/Nested Note.md');
    final note = MarkdownParser.parse(text);
    expect(note.headings.length, equals(1));
    expect(note.headings.first.level, equals(1));
  });

  test('12-embeds.md', () {
    final text = readNote('12-embeds.md');
    final note = MarkdownParser.parse(text);

    final embeds = note.wikiLinks.where((w) => w.embed).toList();
    expect(
      embeds.any(
        (e) => e.size != null && e.size!.width == 300 && e.size!.height == 200,
      ),
      isTrue,
    );
    expect(embeds.any((e) => e.pdfPage == '3'), isTrue);
  });

  test('13-tags.md', () {
    final text = readNote('13-tags.md');
    final note = MarkdownParser.parse(text);

    expect(note.tags.any((t) => t.contains('nested/tag')), isTrue);
    expect(note.tags.contains('123'), isFalse);
  });

  test('14-comments.md', () {
    final text = readNote('14-comments.md');
    final note = MarkdownParser.parse(text);

    expect(
      note.root.descendants.whereType<MdCommentInline>().length,
      greaterThanOrEqualTo(1),
    );
    expect(
      note.root.descendants.whereType<MdCommentBlock>().length,
      greaterThanOrEqualTo(1),
    );
  });

  test('15-block-ids.md', () {
    final text = readNote('15-block-ids.md');
    final note = MarkdownParser.parse(text);

    expect(note.blockIds.length, greaterThanOrEqualTo(3));
  });

  test('16-math.md', () {
    final text = readNote('16-math.md');
    final note = MarkdownParser.parse(text);

    expect(
      note.root.descendants.whereType<MdInlineMath>().length,
      greaterThanOrEqualTo(1),
    );
    expect(
      note.root.descendants.whereType<MdMathBlock>().length,
      greaterThanOrEqualTo(1),
    );

    // "$5 and $10" produces none
    for (final math in note.root.descendants.whereType<MdInlineMath>()) {
      expect(math.tex.contains('5'), isFalse);
      expect(math.tex.contains('10'), isFalse);
    }
  });

  test('17-footnotes.md', () {
    final text = readNote('17-footnotes.md');
    final note = MarkdownParser.parse(text);

    expect(
      note.root.descendants.whereType<MdFootnoteRef>().length,
      greaterThanOrEqualTo(1),
    );
    expect(
      note.root.descendants.whereType<MdFootnoteDefinition>().length,
      greaterThanOrEqualTo(1),
    );
    expect(
      note.root.descendants.whereType<MdInlineFootnote>().length,
      greaterThanOrEqualTo(1),
    );
  });

  test('18-frontmatter.md', () {
    final text = readNote('18-frontmatter.md');
    final note = MarkdownParser.parse(text);

    expect(note.frontmatterValid, isTrue);
    expect(note.frontmatter, isNotEmpty);
    expect(note.root.children.first, isA<MdFrontmatter>());
  });

  test('19-html.md', () {
    final text = readNote('19-html.md');
    final note = MarkdownParser.parse(text);

    expect(
      note.root.descendants.whereType<MdHtmlBlock>().length,
      greaterThanOrEqualTo(1),
    );
    expect(
      note.root.descendants.whereType<MdHtmlInline>().length,
      greaterThanOrEqualTo(1),
    );
  });

  test('20-thematic-breaks.md', () {
    final text = readNote('20-thematic-breaks.md');
    final note = MarkdownParser.parse(text);

    expect(
      note.root.descendants.whereType<MdThematicBreak>().length,
      greaterThanOrEqualTo(3),
    );
  });

  test('21-escapes-entities.md', () {
    final text = readNote('21-escapes-entities.md');
    expect(() => MarkdownParser.parse(text), returnsNormally);
  });

  test('22-mixed.md', () {
    final text = readNote('22-mixed.md');
    expect(() => MarkdownParser.parse(text), returnsNormally);
  });

  test('23-unicode.md', () {
    final text = readNote('23-unicode.md');
    expect(() => MarkdownParser.parse(text), returnsNormally);
    final tagNote = MarkdownParser.parse(readNote('13-tags.md'));
    expect(tagNote.tags, contains('বাংলা'));
  });
}
