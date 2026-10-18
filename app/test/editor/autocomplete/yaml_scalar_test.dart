// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/editor/autocomplete/yaml_scalar.dart';

void main() {
  group('yamlScalarForInsert', () {
    test('draft -> draft (plain safe string)', () {
      expect(yamlScalarForInsert('draft'), equals('draft'));
    });

    test('a: b -> "a: b" (contains colon followed by space)', () {
      expect(yamlScalarForInsert('a: b'), equals('"a: b"'));
    });

    test('true -> "true" (boolean literal)', () {
      expect(yamlScalarForInsert('true'), equals('"true"'));
      expect(yamlScalarForInsert('False'), equals('"False"'));
      expect(yamlScalarForInsert('yes'), equals('"yes"'));
      expect(yamlScalarForInsert('null'), equals('"null"'));
    });

    test('2026-10-11 for a text key -> "2026-10-11"', () {
      expect(
        yamlScalarForInsert('2026-10-11', keyType: 'text'),
        equals('"2026-10-11"'),
      );
      // For date key, plain is allowed
      expect(
        yamlScalarForInsert('2026-10-11', keyType: 'date'),
        equals('2026-10-11'),
      );
    });

    test('-x -> "-x" (starts with hyphen)', () {
      expect(yamlScalarForInsert('-x'), equals('"-x"'));
      expect(yamlScalarForInsert('#tag'), equals('"#tag"'));
      expect(yamlScalarForInsert('?query'), equals('"?query"'));
    });

    test('say "hi" -> "say \\"hi\\"" (contains quotes)', () {
      expect(yamlScalarForInsert('say "hi"'), equals(r'"say \"hi\""'));
    });

    test('বাংলা -> plain (Bengali unicode text)', () {
      expect(yamlScalarForInsert('বাংলা'), equals('বাংলা'));
    });

    test('empty string -> ""', () {
      expect(yamlScalarForInsert(''), equals('""'));
    });

    test('leading or trailing spaces -> quoted', () {
      expect(yamlScalarForInsert(' padded '), equals('" padded "'));
    });

    test('numeric string for non-number key -> quoted', () {
      expect(yamlScalarForInsert('123', keyType: 'text'), equals('"123"'));
      expect(yamlScalarForInsert('123', keyType: 'number'), equals('123'));
    });
  });
}
