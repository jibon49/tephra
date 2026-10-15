// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/editor/autocomplete/autocomplete_context.dart';
import 'package:tephra/editor/autocomplete/autocomplete_insertion.dart';
import 'package:tephra/editor/autocomplete/autocomplete_item.dart';
import 'package:tephra/editor/autocomplete/autocomplete_ranker.dart';
import 'package:tephra/editor/autocomplete/frontmatter_scanner.dart';
import 'package:tephra_index/tephra_index.dart';

void main() {
  group('Tag and Property Autocomplete Insertion', () {
    (String, int) parseCaret(String input) {
      final idx = input.lastIndexOf('|');
      expect(idx, isNot(-1), reason: 'input must contain "|" indicating caret');
      final text = input.substring(0, idx) + input.substring(idx + 1);
      return (text, idx);
    }

    test('accepting project/alpha for #pro| -> #project/alpha', () {
      final (text, caret) = parseCaret('Text #pro|');
      final ctx = detectAutocompleteContext(text, caret);
      expect(ctx, isA<TagContext>());

      final item = const AcItem(
        kind: AcKind.tag,
        primary: '#project/alpha',
        score: 100,
        payload: TagCount(
          tag: 'project/alpha',
          tagLower: 'project/alpha',
          count: 5,
          directCount: 5,
        ),
      );

      final ins = buildTagInsertion(text, ctx as TagContext, item);
      final newText = applyTextEdits(text, ins.edits);
      expect(newText, equals('Text #project/alpha'));
      expect(ins.caretAfter, equals('Text #project/alpha'.length));
    });

    test('accepting key tags -> tags:\\n  - with the caret at the end', () {
      final (text, caret) = parseCaret('---\nsta|\n---\n');
      final ctx = detectAutocompleteContext(text, caret);
      expect(ctx, isA<PropertyKeyContext>());

      final item = const AcItem(
        kind: AcKind.propertyKey,
        primary: 'tags',
        score: 100,
        payload: PropertyKeyCount(key: 'tags', valueType: 'tags', count: 0),
      );

      final ins = buildPropertyKeyInsertion(
        text,
        ctx as PropertyKeyContext,
        item,
      );
      final newText = applyTextEdits(text, ins.edits);
      expect(newText, equals('---\ntags:\n  - \n---\n'));
      expect(ins.caretAfter, equals('---\ntags:\n  - '.length));
      expect(ins.continueCompletion, isTrue);
    });

    test('accepting key status -> status: and next detection is forced value context listing values by count', () {
      final (text, caret) = parseCaret('---\nsta|\n---\n');
      final ctx = detectAutocompleteContext(text, caret);
      expect(ctx, isA<PropertyKeyContext>());

      final item = const AcItem(
        kind: AcKind.propertyKey,
        primary: 'status',
        score: 100,
        payload: PropertyKeyCount(key: 'status', valueType: 'text', count: 3),
      );

      final ins = buildPropertyKeyInsertion(
        text,
        ctx as PropertyKeyContext,
        item,
      );
      final newText = applyTextEdits(text, ins.edits);
      expect(newText, equals('---\nstatus: \n---\n'));
      expect(ins.caretAfter, equals('---\nstatus: '.length));

      // Next detection with forceEmpty at caretAfter
      final nextCtx = detectAutocompleteContext(
        newText,
        ins.caretAfter,
        forceEmpty: true,
      );
      expect(nextCtx, isA<PropertyValueContext>());
      final pvc = nextCtx as PropertyValueContext;
      expect(pvc.key, equals('status'));
      expect(pvc.query, equals(''));

      // Values listed by count (done 5x, draft 2x)
      final ranked = AutocompleteRanker.rankPropertyValues('', [
        'done',
        'draft',
      ]);
      expect(ranked.map((e) => e.primary).toList(), equals(['done', 'draft']));
    });

    test(
      'accepting value in progress -> in progress (plain: spaces inside safe)',
      () {
        final (text, caret) = parseCaret('---\nstatus: in|\n---\n');
        final ctx = detectAutocompleteContext(text, caret);
        expect(ctx, isA<PropertyValueContext>());

        final item = const AcItem(
          kind: AcKind.propertyValue,
          primary: 'in progress',
          score: 100,
          payload: 'in progress',
        );

        final ins = buildPropertyValueInsertion(
          text,
          ctx as PropertyValueContext,
          item,
        );
        final newText = applyTextEdits(text, ins.edits);
        expect(newText, equals('---\nstatus: in progress\n---\n'));
        expect(ins.caretAfter, equals('---\nstatus: in progress'.length));
      },
    );

    test('keys already in the note are not offered', () {
      const text = '---\nstatus: done\nsta\n---\n';
      final fm = frontmatterRange(text);
      expect(fm, isNotNull);

      final existingKeys = extractFrontmatterKeys(text, fm!);
      expect(existingKeys, contains('status'));

      const allKeys = [
        PropertyKeyCount(key: 'status', valueType: 'text', count: 5),
        PropertyKeyCount(key: 'stage', valueType: 'text', count: 2),
      ];

      final available = allKeys
          .where((k) => !existingKeys.contains(k.key.toLowerCase()))
          .toList();

      expect(available.length, equals(1));
      expect(available.first.key, equals('stage'));
    });
  });
}
