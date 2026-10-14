// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:math';

import 'package:tephra_markdown/tephra_markdown.dart';
import 'package:test/test.dart';

String _dumpTree(MdNode root) {
  final sb = StringBuffer();
  void visit(MdNode node, int depth) {
    sb.writeln('${'  ' * depth}${node.runtimeType}@${node.start}-${node.end}');
    for (final child in node.children) {
      visit(child, depth + 1);
    }
  }

  visit(root, 0);
  return sb.toString();
}

void _checkInvariants(MdNode node, int textLength) {
  expect(
    node.start,
    greaterThanOrEqualTo(0),
    reason: 'start < 0 for ${node.runtimeType}',
  );
  expect(
    node.end,
    greaterThanOrEqualTo(node.start),
    reason: 'end < start for ${node.runtimeType}',
  );
  expect(
    node.end,
    lessThanOrEqualTo(textLength),
    reason: 'end > text.length for ${node.runtimeType}',
  );

  for (var i = 0; i < node.children.length; i++) {
    final child = node.children[i];
    expect(
      child.start,
      greaterThanOrEqualTo(node.start),
      reason:
          'child ${child.runtimeType} start ${child.start} < parent ${node.runtimeType} start ${node.start}',
    );
    expect(
      child.end,
      lessThanOrEqualTo(node.end),
      reason:
          'child ${child.runtimeType} end ${child.end} > parent ${node.runtimeType} end ${node.end}',
    );

    if (i + 1 < node.children.length) {
      final next = node.children[i + 1];
      expect(
        child.end,
        lessThanOrEqualTo(next.start),
        reason:
            'siblings overlap: ${child.runtimeType}@${child.start}-${child.end} vs ${next.runtimeType}@${next.start}-${next.end}',
      );
    }

    _checkInvariants(child, textLength);
  }
}

const List<String> _fragments = [
  '#',
  '##',
  '- ',
  '1. ',
  '> ',
  '> [!note] ',
  '[[',
  ']]',
  '![[',
  '|',
  '**',
  '_',
  '==',
  '~~',
  '%%',
  r'$',
  r'$$',
  '`',
  '```',
  '---',
  '[^1]',
  '^id',
  '<div>',
  r'\',
  '&amp;',
  '\t',
  ' ',
  '  ',
  '    ',
  '\n',
  '\n\n',
  'বাংলা',
  'পরীক্ষা',
  '🌋',
  '🔥',
  '👨‍👩‍👧',
  'word',
  'a',
  'b',
  '123',
  'foo',
  'bar',
];

String _generateDoc(Random rng) {
  final count = 1 + rng.nextInt(60);
  final sb = StringBuffer();
  for (var i = 0; i < count; i++) {
    sb.write(_fragments[rng.nextInt(_fragments.length)]);
  }
  return sb.toString();
}

void main() {
  test('fuzz testing: 2,000 random documents with Obsidian options', () {
    const seed = 42;
    final rng = Random(seed);

    for (var docIdx = 0; docIdx < 2000; docIdx++) {
      final doc = _generateDoc(rng);
      try {
        final parsed1 = MarkdownParser.parse(doc);
        final dump1 = _dumpTree(parsed1.root);
        _checkInvariants(parsed1.root, doc.length);

        final parsed2 = MarkdownParser.parse(doc);
        final dump2 = _dumpTree(parsed2.root);

        expect(
          dump2,
          equals(dump1),
          reason: 'Non-deterministic AST dump on doc $docIdx',
        );
      } catch (e, st) {
        fail(
          'Fuzz failure at seed $seed, doc #$docIdx:\n'
          'Input: ${jsonEncode(doc)}\n'
          'Error: $e\n$st',
        );
      }
    }
  });

  test('fuzz testing: seed 7 with CommonMark options', () {
    const seed = 7;
    final rng = Random(seed);

    for (var docIdx = 0; docIdx < 500; docIdx++) {
      final doc = _generateDoc(rng);
      try {
        final parsed = MarkdownParser.parseWith(
          doc,
          const ParserOptions(obsidian: false, gfm: false),
        );
        _checkInvariants(parsed.root, doc.length);
      } catch (e, st) {
        fail(
          'Fuzz failure at seed $seed, doc #$docIdx:\n'
          'Input: ${jsonEncode(doc)}\n'
          'Error: $e\n$st',
        );
      }
    }
  });
}
