// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/src/links/heading_matcher.dart';
import 'package:tephra_index/src/model/block_record.dart';
import 'package:tephra_index/src/model/heading_record.dart';
import 'package:test/test.dart';

void main() {
  group('heading_matcher', () {
    test('normalizeHeading cleans characters and collapses whitespace', () {
      expect(
        normalizeHeading('  My: [Big]  Heading '),
        equals('my big heading'),
      );
      expect(normalizeHeading('A#B|C^D'), equals('abcd'));
      expect(normalizeHeading('A%%B'), equals('ab'));
    });

    test('findHeading resolves simple and chained headings by level', () {
      final samplePath = VaultPath('note.md');
      final headings = [
        HeadingRecord(
          path: samplePath,
          level: 1,
          text: 'Intro',
          start: 0,
          end: 10,
          line: 0,
          ordinal: 0,
        ),
        HeadingRecord(
          path: samplePath,
          level: 2,
          text: 'Setup',
          start: 11,
          end: 20,
          line: 2,
          ordinal: 1,
        ),
        HeadingRecord(
          path: samplePath,
          level: 1,
          text: 'Usage',
          start: 21,
          end: 30,
          line: 4,
          ordinal: 2,
        ),
        HeadingRecord(
          path: samplePath,
          level: 2,
          text: 'Setup',
          start: 31,
          end: 40,
          line: 6,
          ordinal: 3,
        ),
      ];

      final setupMatch = findHeading(headings, 'setup');
      expect(setupMatch, isNotNull);
      expect(setupMatch!.ordinal, equals(1));

      final usageSetupMatch = findHeading(headings, 'Usage#Setup');
      expect(usageSetupMatch, isNotNull);
      expect(usageSetupMatch!.ordinal, equals(3));

      final introUsageMatch = findHeading(headings, 'Intro#Usage');
      expect(introUsageMatch, isNull);

      final missingMatch = findHeading(headings, 'Missing');
      expect(missingMatch, isNull);
    });

    test('findBlock finds block id case-insensitively with or without leading caret', () {
      final samplePath = VaultPath('note.md');
      final blocks = [
        BlockRecord(
          path: samplePath,
          id: 'abc',
          start: 10,
          end: 30,
          line: 2,
          preview: 'Hello block',
        ),
        BlockRecord(
          path: samplePath,
          id: 'xyz',
          start: 35,
          end: 60,
          line: 5,
          preview: 'Another block',
        ),
      ];

      expect(findBlock(blocks, '^ABC'), isNotNull);
      expect(findBlock(blocks, '^ABC')!.id, equals('abc'));
      expect(findBlock(blocks, 'abc')!.id, equals('abc'));
      expect(findBlock(blocks, '^XYZ')!.id, equals('xyz'));
      expect(findBlock(blocks, 'missing'), isNull);
    });

    test('sectionRange computes boundary from current heading to next heading of equal/higher level', () {
      final samplePath = VaultPath('note.md');
      final h1Intro = HeadingRecord(
        path: samplePath,
        level: 1,
        text: 'Intro',
        start: 0,
        end: 10,
        line: 0,
        ordinal: 0,
      );
      final h2Setup1 = HeadingRecord(
        path: samplePath,
        level: 2,
        text: 'Setup',
        start: 11,
        end: 20,
        line: 2,
        ordinal: 1,
      );
      final h1Usage = HeadingRecord(
        path: samplePath,
        level: 1,
        text: 'Usage',
        start: 25,
        end: 35,
        line: 4,
        ordinal: 2,
      );
      final h2Setup2 = HeadingRecord(
        path: samplePath,
        level: 2,
        text: 'Setup',
        start: 40,
        end: 50,
        line: 6,
        ordinal: 3,
      );

      final headings = [h1Intro, h2Setup1, h1Usage, h2Setup2];
      const textLength = 100;

      final introRange = sectionRange(headings, h1Intro, textLength);
      expect(introRange, equals((h1Intro.start, h1Usage.start)));

      final lastSetupRange = sectionRange(headings, h2Setup2, textLength);
      expect(lastSetupRange, equals((h2Setup2.start, textLength)));
    });
  });
}
