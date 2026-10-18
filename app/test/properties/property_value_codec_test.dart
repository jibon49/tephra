// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/properties/property_type.dart';
import 'package:tephra/properties/property_value_codec.dart';

void main() {
  group('property_value_codec', () {
    test('convert("a, b", multitext) = [a, b]', () {
      final res = convert('a, b', PropertyType.multitext);
      expect(res.ok, isTrue);
      expect(res.value, equals(['a', 'b']));
    });

    test('convert("#x y", tags) = [x, y]', () {
      final res = convert('#x y', PropertyType.tags);
      expect(res.ok, isTrue);
      expect(res.value, equals(['x', 'y']));
    });

    test('convert("12", number) = 12', () {
      final res = convert('12', PropertyType.number);
      expect(res.ok, isTrue);
      expect(res.value, equals(12));
    });

    test('convert("abc", number).ok == false', () {
      final res = convert('abc', PropertyType.number);
      expect(res.ok, isFalse);
      expect(res.value, equals('abc'));
    });

    test('convert("yes", checkbox) = true', () {
      final res = convert('yes', PropertyType.checkbox);
      expect(res.ok, isTrue);
      expect(res.value, equals(true));
    });

    test('convert("2026-10-11T09:30", date) = "2026-10-11"', () {
      final res = convert('2026-10-11T09:30', PropertyType.date);
      expect(res.ok, isTrue);
      expect(res.value, equals('2026-10-11'));
    });

    test('convert("2026-10-11", datetime) = "2026-10-11T00:00"', () {
      final res = convert('2026-10-11', PropertyType.datetime);
      expect(res.ok, isTrue);
      expect(res.value, equals('2026-10-11T00:00'));
    });

    test('convert(["a", "b"], text) = "a, b"', () {
      final res = convert(['a', 'b'], PropertyType.text);
      expect(res.ok, isTrue);
      expect(res.value, equals('a, b'));
    });
  });
}
