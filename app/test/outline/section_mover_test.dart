// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/outline/section_mover.dart';
import 'package:tephra_index/tephra_index.dart';
import 'package:tephra_markdown/tephra_markdown.dart';

void main() {
  group('section_mover', () {
    const text = '# A\na\n## B\nb\n# C\nc';
    final parsed = MarkdownParser.parse(text);
    final headings = parsed.headings;

    test('sectionOf ranges match expected substrings', () {
      // headings[0] = # A, headings[1] = ## B, headings[2] = # C
      final (sB, eB) = sectionOf(headings, 1, text.length);
      expect(text.substring(sB, eB), equals('## B\nb\n'));

      final (sA, eA) = sectionOf(headings, 0, text.length);
      expect(text.substring(sA, eA), equals('# A\na\n## B\nb\n'));

      final (sC, eC) = sectionOf(headings, 2, text.length);
      expect(text.substring(sC, eC), equals('# C\nc'));
    });

    test('Move C before A -> # C\\nc\\n# A\\na\\n## B\\nb\\n', () {
      final edits = moveSectionEdits(text, headings, 2, 0);
      expect(edits, isNotNull);
      final applied = applyTextEdits(text, edits!);
      expect(applied, equals('# C\nc\n# A\na\n## B\nb\n'));
    });

    test('Move B to end -> # A\\na\\n# C\\nc\\n## B\\nb\\n', () {
      final edits = moveSectionEdits(text, headings, 1, text.length);
      expect(edits, isNotNull);
      final applied = applyTextEdits(text, edits!);
      expect(applied, equals('# A\na\n# C\nc\n## B\nb\n'));
    });

    test('Move A to insertAt = B.start -> null', () {
      final edits = moveSectionEdits(text, headings, 0, headings[1].start);
      expect(edits, isNull);
    });

    test('Move A to end -> # C\\nc\\n# A\\na\\n## B\\nb\\n', () {
      final edits = moveSectionEdits(text, headings, 0, text.length);
      expect(edits, isNotNull);
      final applied = applyTextEdits(text, edits!);
      expect(applied, equals('# C\nc\n# A\na\n## B\nb\n'));
    });

    test('Move to own start or end returns null', () {
      final (s, e) = sectionOf(headings, 1, text.length);
      expect(moveSectionEdits(text, headings, 1, s), isNull);
      expect(moveSectionEdits(text, headings, 1, e), isNull);
    });

    test('Move invalid index or out-of-range insertAt returns null', () {
      expect(moveSectionEdits(text, headings, -1, 0), isNull);
      expect(moveSectionEdits(text, headings, 99, 0), isNull);
      expect(moveSectionEdits(text, headings, 1, -1), isNull);
      expect(moveSectionEdits(text, headings, 1, text.length + 10), isNull);
    });
  });
}
