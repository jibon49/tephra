// © 2026 Tephra. All rights reserved.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/editor/autocomplete/autocomplete_context.dart';
import 'package:tephra/editor/autocomplete/autocomplete_insertion.dart';
import 'package:tephra/editor/autocomplete/autocomplete_item.dart';
import 'package:tephra/editor/autocomplete/block_candidates.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/tephra_index.dart';

void main() {
  group('buildLinkInsertion', () {
    final uniquePath = VaultPath('Unique.md');
    final otherPath = VaultPath('Folder/Other Note.md');
    final fromPath = VaultPath('From.md');

    final nameTable = NameTable.from([uniquePath, otherPath, fromPath], {});

    final wikiSettings = const LinkFormatSettings(
      format: NewLinkFormat.shortest,
      useMarkdownLinks: false,
    );
    final wikiFormatter = LinkFormatter(nameTable, wikiSettings);

    final mdSettings = const LinkFormatSettings(
      format: NewLinkFormat.shortest,
      useMarkdownLinks: true,
    );
    final mdFormatter = LinkFormatter(nameTable, mdSettings);

    (String, int) parseCaret(String input) {
      final idx = input.lastIndexOf('|');
      expect(idx, isNot(-1), reason: 'input must contain "|" indicating caret');
      final text = input.substring(0, idx) + input.substring(idx + 1);
      return (text, idx);
    }

    String applyInsertion(String text, Insertion ins) {
      // Apply edits in descending offset order so earlier indices remain valid
      var res = text;
      final sortedEdits = List<TextEdit>.from(ins.edits)
        ..sort((a, b) => b.start.compareTo(a.start));
      for (final e in sortedEdits) {
        res = res.substring(0, e.start) + e.replacement + res.substring(e.end);
      }
      return res;
    }

    test('Enter on Unique in [[Uni| -> text [[Unique]], caret after ]]', () {
      final (text, caret) = parseCaret('[[Uni|');
      final ctx = detectAutocompleteContext(text, caret)!;
      final item = AcItem(
        kind: AcKind.note,
        primary: 'Unique',
        score: 1000,
        matchRanges: const [],
        payload: uniquePath,
      );

      final ins = buildLinkInsertion(
        text,
        ctx,
        item,
        formatter: wikiFormatter,
        from: fromPath,
        continueIntoSubpath: false,
      );

      final result = applyInsertion(text, ins);
      expect(result, equals('[[Unique]]'));
      expect(ins.caretAfter, equals(result.length));
    });

    test(
      'with an existing ]] ([[Uni|]]) -> still [[Unique]], caret after ]]',
      () {
        final (text, caret) = parseCaret('[[Uni|]]');
        final ctx = detectAutocompleteContext(text, caret)!;
        final item = AcItem(
          kind: AcKind.note,
          primary: 'Unique',
          score: 1000,
          matchRanges: const [],
          payload: uniquePath,
        );

        final ins = buildLinkInsertion(
          text,
          ctx,
          item,
          formatter: wikiFormatter,
          from: fromPath,
          continueIntoSubpath: false,
        );

        final result = applyInsertion(text, ins);
        expect(result, equals('[[Unique]]'));
        expect(ins.caretAfter, equals(result.length));
      },
    );

    test('Tab -> [[Unique#|]], continueCompletion: true', () {
      final (text, caret) = parseCaret('[[Uni|');
      final ctx = detectAutocompleteContext(text, caret)!;
      final item = AcItem(
        kind: AcKind.note,
        primary: 'Unique',
        score: 1000,
        matchRanges: const [],
        payload: uniquePath,
      );

      final ins = buildLinkInsertion(
        text,
        ctx,
        item,
        formatter: wikiFormatter,
        from: fromPath,
        continueIntoSubpath: true,
      );

      final result = applyInsertion(text, ins);
      expect(result, equals('[[Unique#]]'));
      expect(ins.continueCompletion, isTrue);
      // caret is right after '#' (index 9)
      expect(ins.caretAfter, equals(9));
    });

    test('markdown mode -> [Unique](Unique.md)', () {
      final (text, caret) = parseCaret('[[Uni|');
      final ctx = detectAutocompleteContext(text, caret)!;
      final item = AcItem(
        kind: AcKind.note,
        primary: 'Unique',
        score: 1000,
        matchRanges: const [],
        payload: uniquePath,
      );

      final ins = buildLinkInsertion(
        text,
        ctx,
        item,
        formatter: mdFormatter,
        from: fromPath,
        continueIntoSubpath: false,
      );

      final result = applyInsertion(text, ins);
      expect(result, equals('[Unique](Unique.md)'));
      expect(ins.caretAfter, equals(result.length));
    });

    test('heading row Part Two in [[Unique#Pa| -> [[Unique#Part Two]]', () {
      final (text, caret) = parseCaret('[[Unique#Pa|');
      final ctx = detectAutocompleteContext(text, caret)!;
      final item = AcItem(
        kind: AcKind.heading,
        primary: 'Part Two',
        score: 1000,
        matchRanges: const [],
        payload: HeadingRecord(
          path: uniquePath,
          level: 2,
          text: 'Part Two',
          start: 10,
          end: 20,
          line: 2,
          ordinal: 1,
        ),
      );

      final ins = buildLinkInsertion(
        text,
        ctx,
        item,
        formatter: wikiFormatter,
        from: fromPath,
        continueIntoSubpath: false,
      );

      final result = applyInsertion(text, ins);
      expect(result, equals('[[Unique#Part Two]]'));
      expect(ins.caretAfter, equals(result.length));
    });

    test('alias row -> [[Unique|Short]]', () {
      final (text, caret) = parseCaret('[[Uni|');
      final ctx = detectAutocompleteContext(text, caret)!;
      final item = AcItem(
        kind: AcKind.alias,
        primary: 'Short',
        score: 1000,
        matchRanges: const [],
        payload: (uniquePath, 'Short'),
      );

      final ins = buildLinkInsertion(
        text,
        ctx,
        item,
        formatter: wikiFormatter,
        from: fromPath,
        continueIntoSubpath: false,
      );

      final result = applyInsertion(text, ins);
      expect(result, equals('[[Unique|Short]]'));
      expect(ins.caretAfter, equals(result.length));
    });

    test('block with existing id -> [[Unique#^keep]] and no side effect', () {
      final (text, caret) = parseCaret('[[Unique#^ke|');
      final ctx = detectAutocompleteContext(text, caret)!;
      final candidate = const BlockCandidate(
        start: 0,
        end: 10,
        line: 1,
        kind: BlockKind.paragraph,
        existingId: 'keep',
        preview: 'target paragraph',
      );
      final item = AcItem(
        kind: AcKind.block,
        primary: 'target paragraph',
        secondary: '^keep',
        score: 1000,
        matchRanges: const [],
        payload: candidate,
      );

      final ins = buildLinkInsertion(
        text,
        ctx,
        item,
        formatter: wikiFormatter,
        from: fromPath,
        continueIntoSubpath: false,
        targetNotePath: uniquePath,
      );

      final result = applyInsertion(text, ins);
      expect(result, equals('[[Unique#^keep]]'));
      expect(ins.sideEffects, isEmpty);
      expect(ins.edits.length, equals(1));
    });

    test(
      'block without id in the current note -> one edits list of 2 edits',
      () {
        const docText = 'Paragraph one to reference\n\nLink here: [[^pa';
        final caret = docText.length;
        final ctx = detectAutocompleteContext(docText, caret)!;

        final candidate = const BlockCandidate(
          start: 0,
          end: 26,
          line: 1,
          kind: BlockKind.paragraph,
          existingId: null,
          preview: 'Paragraph one to reference',
        );
        final item = AcItem(
          kind: AcKind.block,
          primary: 'Paragraph one to reference',
          score: 1000,
          matchRanges: const [],
          payload: candidate,
        );

        final ins = buildLinkInsertion(
          docText,
          ctx,
          item,
          formatter: wikiFormatter,
          from: fromPath,
          continueIntoSubpath: false,
          targetNotePath: fromPath, // current note
          rng: Random(42),
        );

        expect(ins.edits.length, equals(2));
        final result = applyInsertion(docText, ins);
        expect(result, contains('Paragraph one to reference ^'));
        expect(result, contains('Link here: [[#^'));
        expect(result, endsWith(']]'));
      },
    );

    test('typing [[Note^ab| then accepting -> [[Note#^id]]', () {
      final (text, caret) = parseCaret('[[Note^ab|');
      final ctx = detectAutocompleteContext(text, caret)!;
      final candidate = const BlockCandidate(
        start: 0,
        end: 10,
        line: 1,
        kind: BlockKind.paragraph,
        existingId: 'id123',
        preview: 'block content',
      );
      final item = AcItem(
        kind: AcKind.block,
        primary: 'block content',
        score: 1000,
        matchRanges: const [],
        payload: candidate,
      );

      final ins = buildLinkInsertion(
        text,
        ctx,
        item,
        formatter: wikiFormatter,
        from: fromPath,
        continueIntoSubpath: false,
        targetNotePath: VaultPath('Note.md'),
      );

      final result = applyInsertion(text, ins);
      expect(result, equals('[[Note#^id123]]'));
    });

    test('the middle-of-link case [[Un|ique]] inserts only the path', () {
      final (text, caret) = parseCaret('[[Un|ique]]');
      final ctx = detectAutocompleteContext(text, caret)!;
      final item = AcItem(
        kind: AcKind.note,
        primary: 'Unique',
        score: 1000,
        matchRanges: const [],
        payload: uniquePath,
      );

      final ins = buildLinkInsertion(
        text,
        ctx,
        item,
        formatter: wikiFormatter,
        from: fromPath,
        continueIntoSubpath: false,
      );

      final result = applyInsertion(text, ins);
      expect(result, equals('[[Uniqueique]]'));
      expect(ins.caretAfter, equals(8));
    });
  });
}
