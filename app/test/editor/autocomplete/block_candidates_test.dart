// © 2026 Tephra. All rights reserved.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/editor/autocomplete/block_candidates.dart';
import 'package:tephra_markdown/tephra_markdown.dart';

class _FakeRandom implements Random {
  _FakeRandom(this._values);
  final List<int> _values;
  int _idx = 0;

  @override
  int nextInt(int max) {
    final v = _values[_idx % _values.length];
    _idx++;
    return v % max;
  }

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0.0;
}

void main() {
  group('block_candidates', () {
    const sampleText = '''
Para one

- item a
  - nested b ^keep

> quote line

| a | b |
|---|---|
| 1 | 2 |

```
code
```
''';

    test('listBlockCandidates extracts candidates in order with correct kinds and ids', () {
      final parsed = MarkdownParser.parse(sampleText);
      final candidates = listBlockCandidates(sampleText, parsed);

      expect(candidates.map((c) => c.kind).toList(), [
        BlockKind.paragraph,
        BlockKind.listItem,
        BlockKind.listItem,
        BlockKind.quote,
        BlockKind.table,
        BlockKind.code,
      ]);

      expect(candidates[0].preview, equals('Para one'));
      expect(candidates[0].existingId, isNull);

      expect(candidates[1].preview, equals('- item a'));
      expect(candidates[1].existingId, isNull);

      expect(candidates[2].preview, equals('- nested b'));
      expect(candidates[2].existingId, equals('keep'));

      expect(candidates[3].preview, equals('> quote line'));
      expect(candidates[3].existingId, isNull);

      expect(candidates[4].kind, equals(BlockKind.table));
      expect(candidates[5].kind, equals(BlockKind.code));
    });

    test('blockIdEdit on paragraph appends ^id', () {
      final parsed = MarkdownParser.parse(sampleText);
      final candidates = listBlockCandidates(sampleText, parsed);
      final para = candidates[0];

      final edit = blockIdEdit(sampleText, para, 'x1y2z3');
      final newText =
          sampleText.substring(0, edit.start) +
          edit.replacement +
          sampleText.substring(edit.end);

      expect(newText, startsWith('Para one ^x1y2z3\n\n'));
    });

    test('blockIdEdit on list item a places ^id before nested item', () {
      final parsed = MarkdownParser.parse(sampleText);
      final candidates = listBlockCandidates(sampleText, parsed);
      final itemA = candidates[1];

      final edit = blockIdEdit(sampleText, itemA, 'x1y2z3');
      final newText =
          sampleText.substring(0, edit.start) +
          edit.replacement +
          sampleText.substring(edit.end);

      expect(newText, contains('- item a ^x1y2z3\n  - nested b ^keep'));
    });

    test(
      'blockIdEdit on table inserts newline and ^id directly after table',
      () {
        final parsed = MarkdownParser.parse(sampleText);
        final candidates = listBlockCandidates(sampleText, parsed);
        final table = candidates[4];

        final edit = blockIdEdit(sampleText, table, 'x1y2z3');
        final newText =
            sampleText.substring(0, edit.start) +
            edit.replacement +
            sampleText.substring(edit.end);

        expect(newText, contains('| 1 | 2 |\n^x1y2z3\n\n```'));
      },
    );

    test('blockIdEdit on code block inserts newline and ^id directly after closing fence', () {
      final parsed = MarkdownParser.parse(sampleText);
      final candidates = listBlockCandidates(sampleText, parsed);
      final code = candidates[5];

      final edit = blockIdEdit(sampleText, code, 'x1y2z3');
      final newText =
          sampleText.substring(0, edit.start) +
          edit.replacement +
          sampleText.substring(edit.end);

      expect(newText, contains('```\n^x1y2z3'));
    });

    test('generateBlockId has length 6 and valid chars', () {
      final id = generateBlockId(Random(1), {});
      expect(id.length, equals(6));
      expect(RegExp(r'^[a-z0-9]{6}$').hasMatch(id), isTrue);
    });

    test('generateBlockId handles clash by regenerating different id', () {
      // Repeat the exact same 6 indices twice
      final fake = _FakeRandom([
        0,
        1,
        2,
        3,
        4,
        5,
        0,
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
        10,
        11,
      ]);
      final id1 = generateBlockId(fake, {});
      expect(id1.length, equals(6));

      // With taken containing id1, fake produces id1 again, clashes, then generates next
      final id2 = generateBlockId(fake, {id1});
      expect(id2, isNot(equals(id1)));
    });
  });
}
