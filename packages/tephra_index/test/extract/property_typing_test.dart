// © 2026 Tephra. All rights reserved.

import 'package:tephra_index/src/extract/property_typing.dart';
import 'package:test/test.dart';

void main() {
  group('property_typing', () {
    test('tags and tag keys produce tags valueType', () {
      final rows = inferPropertyRows('tags', [
        'alpha',
        '#beta',
        'gamma, delta',
      ]);
      expect(rows.length, equals(4));
      expect(rows.every((r) => r.valueType == 'tags'), isTrue);
      expect(
        rows.map((r) => r.valueText).toList(),
        equals(['alpha', 'beta', 'gamma', 'delta']),
      );
    });

    test('aliases and alias keys produce aliases valueType', () {
      final rows = inferPropertyRows('aliases', [
        'Main Title',
        'main title',
        'Alt',
      ]);
      expect(rows.length, equals(2)); // deduplicated case-insensitively
      expect(rows.every((r) => r.valueType == 'aliases'), isTrue);
      expect(
        rows.map((r) => r.valueText).toList(),
        equals(['Main Title', 'Alt']),
      );
    });

    test('boolean produces checkbox valueType', () {
      final rows = inferPropertyRows('done', true);
      expect(rows.length, equals(1));
      expect(rows.first.valueType, equals('checkbox'));
      expect(rows.first.valueBool, isTrue);
      expect(rows.first.valueText, equals('true'));
    });

    test('numeric types produce number valueType', () {
      final rows = inferPropertyRows('count', 42);
      expect(rows.length, equals(1));
      expect(rows.first.valueType, equals('number'));
      expect(rows.first.valueNum, equals(42.0));
      expect(rows.first.valueText, equals('42'));
    });

    test('date string produces date valueType', () {
      final rows = inferPropertyRows('due', '2026-10-14');
      expect(rows.length, equals(1));
      expect(rows.first.valueType, equals('date'));
      expect(rows.first.valueDate, equals('2026-10-14'));
      expect(rows.first.valueText, equals('2026-10-14'));
    });

    test('datetime string produces datetime valueType', () {
      final rows = inferPropertyRows('meeting', '2026-10-14T14:30:00');
      expect(rows.length, equals(1));
      expect(rows.first.valueType, equals('datetime'));
      expect(rows.first.valueDate, equals('2026-10-14T14:30:00'));
      expect(rows.first.valueText, equals('2026-10-14T14:30:00'));
    });

    test('arbitrary string produces text valueType', () {
      final rows = inferPropertyRows('author', 'Arthur Conan Doyle');
      expect(rows.length, equals(1));
      expect(rows.first.valueType, equals('text'));
      expect(rows.first.valueText, equals('Arthur Conan Doyle'));
    });

    test('non-empty list produces multitext valueType with ordinals', () {
      final rows = inferPropertyRows('items', ['apple', 'banana']);
      expect(rows.length, equals(2));
      expect(rows.every((r) => r.valueType == 'multitext'), isTrue);
      expect(rows[0].ordinal, equals(0));
      expect(rows[0].valueText, equals('apple'));
      expect(rows[1].ordinal, equals(1));
      expect(rows[1].valueText, equals('banana'));
    });

    test('empty list produces multitext with null valueText', () {
      final rows = inferPropertyRows('empty_list', []);
      expect(rows.length, equals(1));
      expect(rows.first.valueType, equals('multitext'));
      expect(rows.first.valueText, isNull);
    });

    test('null value produces text with null valueText', () {
      final rows = inferPropertyRows('empty_field', null);
      expect(rows.length, equals(1));
      expect(rows.first.valueType, equals('text'));
      expect(rows.first.valueText, isNull);
    });

    test('map produces jsonEncoded text', () {
      final rows = inferPropertyRows('obj', {'k': 1});
      expect(rows.length, equals(1));
      expect(rows.first.valueType, equals('text'));
      expect(rows.first.valueText, equals('{"k":1}'));
    });
  });
}
