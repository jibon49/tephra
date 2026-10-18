// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/tephra_index.dart';
import 'package:test/test.dart';

void main() {
  group('LinkFormatter', () {
    late NameTable table;

    setUp(() {
      final filePaths = [
        'Note.md',
        'Folder/Note.md',
        'Folder/Other Note.md',
        'Images/a b.png',
        'Deep/x/y/Target.md',
        'Unique.md',
        'বাংলা নোট.md',
      ].map(VaultPath.new);

      table = NameTable.from(filePaths, const {});
    });

    test('case 1: shortest wiki Unique.md from X.md -> Unique', () {
      final formatter = LinkFormatter(
        table,
        const LinkFormatSettings(format: NewLinkFormat.shortest),
      );
      expect(
        formatter.linkPath(
          VaultPath('Unique.md'),
          from: VaultPath('X.md'),
          syntax: LinkSyntax.wiki,
        ),
        equals('Unique'),
      );
    });

    test('case 2: shortest wiki Folder/Note.md from X.md -> Folder/Note (bare Note resolves to root Note.md)', () {
      final formatter = LinkFormatter(
        table,
        const LinkFormatSettings(format: NewLinkFormat.shortest),
      );
      expect(
        formatter.linkPath(
          VaultPath('Folder/Note.md'),
          from: VaultPath('X.md'),
          syntax: LinkSyntax.wiki,
        ),
        equals('Folder/Note'),
      );
    });

    test('case 3: shortest wiki Note.md from Folder/Y.md -> Note', () {
      final formatter = LinkFormatter(
        table,
        const LinkFormatSettings(format: NewLinkFormat.shortest),
      );
      expect(
        formatter.linkPath(
          VaultPath('Note.md'),
          from: VaultPath('Folder/Y.md'),
          syntax: LinkSyntax.wiki,
        ),
        equals('Note'),
      );
    });

    test('case 4: shortest markdown Folder/Other Note.md from X.md -> Other%20Note.md', () {
      final formatter = LinkFormatter(
        table,
        const LinkFormatSettings(format: NewLinkFormat.shortest),
      );
      expect(
        formatter.linkPath(
          VaultPath('Folder/Other Note.md'),
          from: VaultPath('X.md'),
          syntax: LinkSyntax.markdown,
        ),
        equals('Other%20Note.md'),
      );
    });

    test('case 5: shortest wiki Images/a b.png -> a b.png', () {
      final formatter = LinkFormatter(
        table,
        const LinkFormatSettings(format: NewLinkFormat.shortest),
      );
      expect(
        formatter.linkPath(
          VaultPath('Images/a b.png'),
          from: VaultPath('X.md'),
          syntax: LinkSyntax.wiki,
        ),
        equals('a b.png'),
      );
    });

    test('case 6: shortest markdown Images/a b.png -> a%20b.png', () {
      final formatter = LinkFormatter(
        table,
        const LinkFormatSettings(format: NewLinkFormat.shortest),
      );
      expect(
        formatter.linkPath(
          VaultPath('Images/a b.png'),
          from: VaultPath('X.md'),
          syntax: LinkSyntax.markdown,
        ),
        equals('a%20b.png'),
      );
    });

    test('case 7: relative wiki Deep/x/y/Target.md from Folder/Y.md -> ../Deep/x/y/Target', () {
      final formatter = LinkFormatter(
        table,
        const LinkFormatSettings(format: NewLinkFormat.relative),
      );
      expect(
        formatter.linkPath(
          VaultPath('Deep/x/y/Target.md'),
          from: VaultPath('Folder/Y.md'),
          syntax: LinkSyntax.wiki,
        ),
        equals('../Deep/x/y/Target'),
      );
    });

    test('case 8: relative wiki Folder/Note.md from Folder/Y.md -> Note', () {
      final formatter = LinkFormatter(
        table,
        const LinkFormatSettings(format: NewLinkFormat.relative),
      );
      expect(
        formatter.linkPath(
          VaultPath('Folder/Note.md'),
          from: VaultPath('Folder/Y.md'),
          syntax: LinkSyntax.wiki,
        ),
        equals('Note'),
      );
    });

    test('case 9: relative markdown Note.md from Deep/x/y/Z.md -> ../../../Note.md', () {
      final formatter = LinkFormatter(
        table,
        const LinkFormatSettings(format: NewLinkFormat.relative),
      );
      expect(
        formatter.linkPath(
          VaultPath('Note.md'),
          from: VaultPath('Deep/x/y/Z.md'),
          syntax: LinkSyntax.markdown,
        ),
        equals('../../../Note.md'),
      );
    });

    test('case 10: absolute wiki Deep/x/y/Target.md -> Deep/x/y/Target', () {
      final formatter = LinkFormatter(
        table,
        const LinkFormatSettings(format: NewLinkFormat.absolute),
      );
      expect(
        formatter.linkPath(
          VaultPath('Deep/x/y/Target.md'),
          from: VaultPath('Folder/Y.md'),
          syntax: LinkSyntax.wiki,
        ),
        equals('Deep/x/y/Target'),
      );
    });

    test('case 11: absolute markdown Folder/Other Note.md -> Folder/Other%20Note.md', () {
      final formatter = LinkFormatter(
        table,
        const LinkFormatSettings(format: NewLinkFormat.absolute),
      );
      expect(
        formatter.linkPath(
          VaultPath('Folder/Other Note.md'),
          from: VaultPath('X.md'),
          syntax: LinkSyntax.markdown,
        ),
        equals('Folder/Other%20Note.md'),
      );
    });

    test('case 12: buildLink(Images/a b.png, embed: true, embedSize: 300) wiki -> ![[a b.png|300]]', () {
      final formatter = LinkFormatter(
        table,
        const LinkFormatSettings(
          format: NewLinkFormat.shortest,
          useMarkdownLinks: false,
        ),
      );
      expect(
        formatter.buildLink(
          VaultPath('Images/a b.png'),
          from: VaultPath('X.md'),
          embed: true,
          embedSize: '300',
        ),
        equals('![[a b.png|300]]'),
      );
    });

    test('case 13: buildLink(Unique.md, heading: Part Two, alias: shown) wiki -> [[Unique#Part Two|shown]]', () {
      final formatter = LinkFormatter(
        table,
        const LinkFormatSettings(
          format: NewLinkFormat.shortest,
          useMarkdownLinks: false,
        ),
      );
      expect(
        formatter.buildLink(
          VaultPath('Unique.md'),
          from: VaultPath('X.md'),
          heading: 'Part Two',
          alias: 'shown',
        ),
        equals('[[Unique#Part Two|shown]]'),
      );
    });

    test('case 14: buildLink(Unique.md, heading: Part Two) markdown -> [Unique](Unique.md#Part%20Two)', () {
      final formatter = LinkFormatter(
        table,
        const LinkFormatSettings(
          format: NewLinkFormat.shortest,
          useMarkdownLinks: true,
        ),
      );
      expect(
        formatter.buildLink(
          VaultPath('Unique.md'),
          from: VaultPath('X.md'),
          heading: 'Part Two',
        ),
        equals('[Unique](Unique.md#Part%20Two)'),
      );
    });

    test('case 15: encodeMarkdownPath((draft) 100%.md) / decode back -> %28draft%29%20100%25.md / original', () {
      const original = '(draft) 100%.md';
      final encoded = LinkFormatter.encodeMarkdownPath(original);
      expect(encoded, equals('%28draft%29%20100%25.md'));
      expect(LinkFormatter.decodeMarkdownPath(encoded), equals(original));
    });

    test('case 16: decodeMarkdownPath(%E0%A4) -> %E0%A4 (unchanged)', () {
      expect(LinkFormatter.decodeMarkdownPath('%E0%A4'), equals('%E0%A4'));
    });

    test('case 17: shortest markdown বাংলা নোট.md -> বাংলা%20নোট.md', () {
      final formatter = LinkFormatter(
        table,
        const LinkFormatSettings(format: NewLinkFormat.shortest),
      );
      expect(
        formatter.linkPath(
          VaultPath('বাংলা নোট.md'),
          from: VaultPath('X.md'),
          syntax: LinkSyntax.markdown,
        ),
        equals('বাংলা%20নোট.md'),
      );
    });

    test('case 18: buildLink(Unique.md, heading: A [b] | c) wiki -> [[Unique#A b c]]', () {
      final formatter = LinkFormatter(
        table,
        const LinkFormatSettings(
          format: NewLinkFormat.shortest,
          useMarkdownLinks: false,
        ),
      );
      expect(
        formatter.buildLink(
          VaultPath('Unique.md'),
          from: VaultPath('X.md'),
          heading: 'A [b] | c',
        ),
        equals('[[Unique#A b c]]'),
      );
    });

    test(
      'case 19: buildLink(Unique.md, blockRef: x1) wiki -> [[Unique#^x1]]',
      () {
        final formatter = LinkFormatter(
          table,
          const LinkFormatSettings(
            format: NewLinkFormat.shortest,
            useMarkdownLinks: false,
          ),
        );
        expect(
          formatter.buildLink(
            VaultPath('Unique.md'),
            from: VaultPath('X.md'),
            blockRef: 'x1',
          ),
          equals('[[Unique#^x1]]'),
        );
      },
    );
  });
}
