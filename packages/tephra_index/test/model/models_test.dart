// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/tephra_index.dart';
import 'package:test/test.dart';

void main() {
  group('Index Models', () {
    test('LinkRecord equality, hashCode and field variance', () {
      final a = LinkRecord(
        source: VaultPath('notes/A.md'),
        targetRaw: 'B',
        targetPath: VaultPath('notes/B.md'),
        kind: LinkKind.link,
        syntax: LinkSyntax.wiki,
        heading: 'Intro',
        blockRef: null,
        alias: 'Page B',
        embedSize: null,
        start: 10,
        end: 25,
        line: 2,
        resolved: true,
        viaAlias: false,
      );

      final b = LinkRecord(
        source: VaultPath('notes/A.md'),
        targetRaw: 'B',
        targetPath: VaultPath('notes/B.md'),
        kind: LinkKind.link,
        syntax: LinkSyntax.wiki,
        heading: 'Intro',
        blockRef: null,
        alias: 'Page B',
        embedSize: null,
        start: 10,
        end: 25,
        line: 2,
        resolved: true,
        viaAlias: false,
      );

      final c = LinkRecord(
        source: VaultPath('notes/A.md'),
        targetRaw: 'B',
        targetPath: VaultPath('notes/B.md'),
        kind: LinkKind.link,
        syntax: LinkSyntax.wiki,
        heading: 'Intro',
        blockRef: null,
        alias: 'Page B',
        embedSize: null,
        start: 10,
        end: 25,
        line: 2,
        resolved: false, // differ
        viaAlias: false,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, isNot(equals(c.hashCode)));
    });

    test('TaskRecord done property behavior', () {
      final doneTask = TaskRecord(
        path: VaultPath('todo.md'),
        line: 1,
        statusChar: 'x',
        text: 'Clean room',
        start: 0,
        end: 15,
      );

      final openTask = TaskRecord(
        path: VaultPath('todo.md'),
        line: 2,
        statusChar: ' ',
        text: 'Buy groceries',
        start: 16,
        end: 32,
      );

      final customStatusTask = TaskRecord(
        path: VaultPath('todo.md'),
        line: 3,
        statusChar: '-',
        text: 'Cancelled item',
        start: 33,
        end: 50,
      );

      expect(doneTask.done, isTrue);
      expect(openTask.done, isFalse);
      expect(customStatusTask.done, isTrue);
    });

    test('IndexOptions excluded folders lookup', () {
      final options = IndexOptions(
        excludedFolders: ['Archive', 'Templates/Daily'],
      );

      expect(options.isExcluded(VaultPath('Archive/Old.md')), isTrue);
      expect(options.isExcluded(VaultPath('Templates/Daily/2026.md')), isTrue);
      expect(options.isExcluded(VaultPath('Notes/General.md')), isFalse);
    });

    test('NoteSummary and FileRecord value equality', () {
      final now = DateTime.now();
      final s1 = NoteSummary(
        path: VaultPath('A.md'),
        title: 'A',
        size: 100,
        modified: now,
        wordCount: 20,
        aliases: ['Alpha'],
        tags: ['tag1'],
      );
      final s2 = NoteSummary(
        path: VaultPath('A.md'),
        title: 'A',
        size: 100,
        modified: now,
        wordCount: 20,
        aliases: ['Alpha'],
        tags: ['tag1'],
      );
      expect(s1, equals(s2));
      expect(s1.hashCode, equals(s2.hashCode));

      final f1 = FileRecord(
        path: VaultPath('img.png'),
        size: 2048,
        modified: now,
        isNote: false,
      );
      final f2 = FileRecord(
        path: VaultPath('img.png'),
        size: 2048,
        modified: now,
        isNote: false,
      );
      expect(f1, equals(f2));
    });
  });
}
