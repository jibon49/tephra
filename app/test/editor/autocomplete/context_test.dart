// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/editor/autocomplete/autocomplete_context.dart';

void main() {
  group('detectAutocompleteContext', () {
    (String, int) parseCaret(String input) {
      final idx = input.lastIndexOf('|');
      expect(idx, isNot(-1), reason: 'input must contain "|" indicating caret');
      final text = input.substring(0, idx) + input.substring(idx + 1);
      return (text, idx);
    }

    test('[[ab| -> NoteLinkContext', () {
      final (text, caret) = parseCaret('[[ab|');
      final ctx = detectAutocompleteContext(text, caret);
      expect(ctx, isA<NoteLinkContext>());
      final nc = ctx as NoteLinkContext;
      expect(nc.query, equals('ab'));
      expect(nc.embed, isFalse);
      expect(nc.replaceStart, equals(2));
      expect(nc.closerPresent, isFalse);
    });

    test('![[ab| -> embed: true', () {
      final (text, caret) = parseCaret('![[ab|');
      final ctx = detectAutocompleteContext(text, caret);
      expect(ctx, isA<NoteLinkContext>());
      final nc = ctx as NoteLinkContext;
      expect(nc.embed, isTrue);
      expect(nc.openStart, equals(0));
      expect(nc.replaceStart, equals(3));
    });

    test('[[ab|]] -> closerPresent: true', () {
      final (text, caret) = parseCaret('[[ab|]]');
      final ctx = detectAutocompleteContext(text, caret);
      expect(ctx, isA<NoteLinkContext>());
      final nc = ctx as NoteLinkContext;
      expect(nc.closerPresent, isTrue);
      expect(nc.query, equals('ab'));
    });

    test('[[Note#He| -> HeadingLinkContext', () {
      final (text, caret) = parseCaret('[[Note#He|');
      final ctx = detectAutocompleteContext(text, caret);
      expect(ctx, isA<HeadingLinkContext>());
      final hc = ctx as HeadingLinkContext;
      expect(hc.noteText, equals('Note'));
      expect(hc.query, equals('He'));
    });

    test('[[#He| -> noteText: empty', () {
      final (text, caret) = parseCaret('[[#He|');
      final ctx = detectAutocompleteContext(text, caret);
      expect(ctx, isA<HeadingLinkContext>());
      final hc = ctx as HeadingLinkContext;
      expect(hc.noteText, equals(''));
      expect(hc.query, equals('He'));
    });

    test('[[A#B#C| -> HeadingLinkContext(noteText: "A", query: "C")', () {
      final (text, caret) = parseCaret('[[A#B#C|');
      final ctx = detectAutocompleteContext(text, caret);
      expect(ctx, isA<HeadingLinkContext>());
      final hc = ctx as HeadingLinkContext;
      expect(hc.noteText, equals('A'));
      expect(hc.query, equals('C'));
    });

    test('[[Note#^ab| -> BlockLinkContext(query: "ab")', () {
      final (text, caret) = parseCaret('[[Note#^ab|');
      final ctx = detectAutocompleteContext(text, caret);
      expect(ctx, isA<BlockLinkContext>());
      final bc = ctx as BlockLinkContext;
      expect(bc.noteText, equals('Note'));
      expect(bc.query, equals('ab'));
    });

    test('[[Note^ab| -> BlockLinkContext(noteText: "Note", query: "ab")', () {
      final (text, caret) = parseCaret('[[Note^ab|');
      final ctx = detectAutocompleteContext(text, caret);
      expect(ctx, isA<BlockLinkContext>());
      final bc = ctx as BlockLinkContext;
      expect(bc.noteText, equals('Note'));
      expect(bc.query, equals('ab'));
    });

    test('[[^ab| -> noteText: empty', () {
      final (text, caret) = parseCaret('[[^ab|');
      final ctx = detectAutocompleteContext(text, caret);
      expect(ctx, isA<BlockLinkContext>());
      final bc = ctx as BlockLinkContext;
      expect(bc.noteText, equals(''));
      expect(bc.query, equals('ab'));
    });

    test('[[Note|Al| -> AliasLinkContext(noteText: "Note", query: "Al")', () {
      final (text, caret) = parseCaret('[[Note|Al|');
      final ctx = detectAutocompleteContext(text, caret);
      expect(ctx, isA<AliasLinkContext>());
      final ac = ctx as AliasLinkContext;
      expect(ac.noteText, equals('Note'));
      expect(ac.query, equals('Al'));
      expect(ac.heading, isNull);
    });

    test('[[Note#Head|Al| -> heading: "Head"', () {
      final (text, caret) = parseCaret('[[Note#Head|Al|');
      final ctx = detectAutocompleteContext(text, caret);
      expect(ctx, isA<AliasLinkContext>());
      final ac = ctx as AliasLinkContext;
      expect(ac.noteText, equals('Note'));
      expect(ac.heading, equals('Head'));
      expect(ac.query, equals('Al'));
    });

    test('[[a]] b| -> null', () {
      final (text, caret) = parseCaret('[[a]] b|');
      final ctx = detectAutocompleteContext(text, caret);
      expect(ctx, isNull);
    });

    test('[[a]]| -> null', () {
      final (text, caret) = parseCaret('[[a]]|');
      final ctx = detectAutocompleteContext(text, caret);
      expect(ctx, isNull);
    });

    test('inside inline code -> null', () {
      final (text, caret) = parseCaret('`[[a|`');
      final ctx = detectAutocompleteContext(text, caret);
      expect(ctx, isNull);
    });

    test('inside code fence -> null', () {
      final (text, caret) = parseCaret('```\n[[a|\n```');
      final ctx = detectAutocompleteContext(text, caret);
      expect(ctx, isNull);
    });

    test('in frontmatter -> null', () {
      final (text, caret) = parseCaret('---\n[[a|\n---\nBody');
      final ctx = detectAutocompleteContext(text, caret);
      expect(ctx, isNull);
    });
  });
}
