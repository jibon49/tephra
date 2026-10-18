// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/tephra_index.dart';
import 'package:test/test.dart';

void main() {
  group('applyTextEdits', () {
    test('applies edits cleanly in order', () {
      const text = 'Hello world, beautiful world!';
      final edits = [
        const TextEdit(6, 11, 'there'),
        const TextEdit(23, 28, 'earth'),
      ];
      expect(applyTextEdits(text, edits), 'Hello there, beautiful earth!');
    });

    test('overlapping edits throw ArgumentError', () {
      const text = 'Hello world!';
      final edits = [const TextEdit(0, 5, 'Hi'), const TextEdit(3, 7, 'there')];
      expect(() => applyTextEdits(text, edits), throwsArgumentError);
    });

    test('identical start offsets throw ArgumentError', () {
      const text = 'Hello world!';
      final edits = [const TextEdit(5, 5, 'a'), const TextEdit(5, 5, 'b')];
      expect(() => applyTextEdits(text, edits), throwsArgumentError);
    });

    test('out of range edits throw ArgumentError', () {
      const text = 'Hello';
      expect(
        () => applyTextEdits(text, [const TextEdit(0, 10, 'x')]),
        throwsArgumentError,
      );
      expect(
        () => applyTextEdits(text, [const TextEdit(-1, 2, 'x')]),
        throwsArgumentError,
      );
      expect(
        () => applyTextEdits(text, [const TextEdit(3, 2, 'x')]),
        throwsArgumentError,
      );
    });
  });

  group('RenamePlanner', () {
    test(
      'full rename matrix on S.md with Target.md -> Folder/Renamed Note.md',
      () {
        final table = NameTable();
        table.addFile(VaultPath('Target.md'));
        table.setAliases(VaultPath('Target.md'), ['A1']);
        table.addFile(VaultPath('Other.md'));
        table.addFile(VaultPath('Note.md'));
        table.addFile(VaultPath('Folder/Sibling.md'));
        table.addFile(VaultPath('Folder/Src.md'));

        const settings = LinkFormatSettings(
          format: NewLinkFormat.shortest,
          useMarkdownLinks: false,
        );

        final planner = RenamePlanner(before: table, settings: settings);

        final cases = <String, String>{
          '[[Target]]': '[[Renamed Note]]',
          '[[target|Alias]]': '[[Renamed Note|Alias]]',
          '[[Target#Head]]': '[[Renamed Note#Head]]',
          '[[Target#^b1]]': '[[Renamed Note#^b1]]',
          '![[Target]]': '![[Renamed Note]]',
          '![[Target|300]]': '![[Renamed Note|300]]',
          '[t](Target.md)': '[t](Renamed%20Note.md)',
          '[t](Target.md#Head%20Two)': '[t](Renamed%20Note.md#Head%20Two)',
          '[t](<Target.md>)': '[t](<Renamed Note.md>)',
          '[t](Target.md "title")': '[t](Renamed%20Note.md "title")',
          '| [[Target\\|x]] |': '| [[Renamed Note\\|x]] |',
          '[[A1]]': '[[A1]]',
          '[[Other]]': '[[Other]]',
          '[[Missing]]': '[[Missing]]',
          '`[[Target]]`': '`[[Target]]`',
        };

        for (final entry in cases.entries) {
          final original = entry.key;
          final expected = entry.value;

          final plan = planner.plan(
            {VaultPath('Target.md'): VaultPath('Folder/Renamed Note.md')},
            {VaultPath('S.md'): original},
          );

          if (original == expected) {
            expect(
              plan.fileEdits,
              isEmpty,
              reason: 'Expected no edits for "$original"',
            );
          } else {
            expect(
              plan.fileEdits.length,
              1,
              reason: 'Expected 1 file edit for "$original"',
            );
            final applied = applyTextEdits(
              original,
              plan.fileEdits.first.edits,
            );
            expect(
              applied,
              expected,
              reason: 'Failed transform for "$original"',
            );
          }
        }
      },
    );

    test('simple move Target.md -> Archive/Target.md with no duplicate stays unchanged', () {
      final table = NameTable();
      table.addFile(VaultPath('Target.md'));

      final planner = RenamePlanner(
        before: table,
        settings: const LinkFormatSettings(),
      );
      final plan = planner.plan(
        {VaultPath('Target.md'): VaultPath('Archive/Target.md')},
        {VaultPath('S.md'): '[[Target]]'},
      );
      expect(plan.fileEdits, isEmpty);
    });

    test('tie-break move root Target.md -> Archive/Target.md with Other/Target.md stays unchanged', () {
      final table = NameTable();
      table.addFile(VaultPath('Target.md'));
      table.addFile(VaultPath('Other/Target.md'));

      final planner = RenamePlanner(
        before: table,
        settings: const LinkFormatSettings(),
      );
      final plan = planner.plan(
        {VaultPath('Target.md'): VaultPath('Archive/Target.md')},
        {VaultPath('S.md'): '[[Target]]'},
      );
      expect(plan.fileEdits, isEmpty);
    });

    test('move root Target.md -> Zzz/Target.md with Aaa/Target.md rewrites to [[Zzz/Target]]', () {
      final table = NameTable();
      table.addFile(VaultPath('Target.md'));
      table.addFile(VaultPath('Aaa/Target.md'));

      final planner = RenamePlanner(
        before: table,
        settings: const LinkFormatSettings(format: NewLinkFormat.shortest),
      );
      final plan = planner.plan(
        {VaultPath('Target.md'): VaultPath('Zzz/Target.md')},
        {VaultPath('S.md'): '[[Target]]'},
      );
      expect(plan.fileEdits.length, 1);
      final applied = applyTextEdits('[[Target]]', plan.fileEdits.first.edits);
      expect(applied, '[[Zzz/Target]]');
    });

    test('format absolute on simple move Target.md -> Archive/Target.md leaves [[Target]] unchanged', () {
      final table = NameTable();
      table.addFile(VaultPath('Target.md'));

      final planner = RenamePlanner(
        before: table,
        settings: const LinkFormatSettings(format: NewLinkFormat.absolute),
      );
      final plan = planner.plan(
        {VaultPath('Target.md'): VaultPath('Archive/Target.md')},
        {VaultPath('S.md'): '[[Target]]'},
      );
      expect(plan.fileEdits, isEmpty);
    });

    test("moved note's own links: Folder/Src.md moved to Deep/x/Src.md", () {
      final table = NameTable();
      table.addFile(VaultPath('Folder/Src.md'));
      table.addFile(VaultPath('Note.md'));
      table.addFile(VaultPath('Folder/Sibling.md'));

      final planner = RenamePlanner(
        before: table,
        settings: const LinkFormatSettings(format: NewLinkFormat.shortest),
      );
      const srcText = '[x](../Note.md) [[Sibling]]';
      final plan = planner.plan(
        {VaultPath('Folder/Src.md'): VaultPath('Deep/x/Src.md')},
        {VaultPath('Folder/Src.md'): srcText},
      );

      expect(plan.fileEdits.length, 1);
      final applied = applyTextEdits(srcText, plan.fileEdits.first.edits);
      expect(applied, '[x](Note.md) [[Sibling]]');
    });

    test('folder rename Folder -> Renamed with X.md = [[Folder/Sibling]] -> [[Sibling]]', () {
      final table = NameTable();
      table.addFile(VaultPath('Folder/Sibling.md'));

      final planner = RenamePlanner(
        before: table,
        settings: const LinkFormatSettings(format: NewLinkFormat.shortest),
      );
      const text = '[[Folder/Sibling]]';
      final plan = planner.plan(
        {VaultPath('Folder/Sibling.md'): VaultPath('Renamed/Sibling.md')},
        {VaultPath('X.md'): text},
      );

      expect(plan.fileEdits.length, 1);
      final applied = applyTextEdits(text, plan.fileEdits.first.edits);
      expect(applied, '[[Sibling]]');
    });
  });
}
