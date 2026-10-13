// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:tephra_markdown/tephra_markdown.dart';
import 'package:test/test.dart';

import 'helpers/dump.dart';

void main() {
  group('Obsidian cases table (~200 cases)', () {
    var fixtureFile = File('test/fixtures/obsidian_cases.txt');
    if (!fixtureFile.existsSync()) {
      fixtureFile = File(
        'packages/tephra_markdown/test/fixtures/obsidian_cases.txt',
      );
    }
    if (!fixtureFile.existsSync()) {
      throw StateError('Fixture file not found: ${fixtureFile.path}');
    }

    final lines = fixtureFile.readAsLinesSync();
    var currentGroup = 'general';

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().isEmpty) continue;
      if (line.startsWith('#')) {
        currentGroup = line.substring(1).trim();
        continue;
      }

      final arrowIdx = line.indexOf(' ⇒ ');
      if (arrowIdx == -1) continue;

      final rawInput = line.substring(0, arrowIdx);
      final expected = line.substring(arrowIdx + 3).trim();

      final input = rawInput.replaceAll('⏎', '\n').replaceAll('→', '\t');

      test('$currentGroup: $rawInput', () {
        final parsed = MarkdownParser.parse(input);
        final actual = dump(parsed.root);
        expect(actual, expected, reason: 'Failed for input: "$rawInput"');
      });
    }
  });
}
