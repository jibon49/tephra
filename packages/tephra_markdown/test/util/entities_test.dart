// © 2026 Tephra. All rights reserved.

import 'package:tephra_markdown/src/util/entities.dart';
import 'package:test/test.dart';

void main() {
  group('HTML entities', () {
    test('exact entity count is 256 (252 HTML 4.01 + 4 CommonMark)', () {
      expect(htmlEntities.length, equals(256));
    });

    test(
      'decodeEntity resolves known entities and returns null for unknown',
      () {
        expect(decodeEntity('amp'), equals('&'));
        expect(decodeEntity('copy'), equals('©'));
        expect(decodeEntity('frac34'), equals('¾'));
        expect(decodeEntity('ngE'), equals('≧̸'));
        expect(decodeEntity('HilbertSpace'), equals('\u210B'));
        expect(decodeEntity('DifferentialD'), equals('\u2146'));
        expect(decodeEntity('ClockwiseContourIntegral'), equals('\u2232'));
        expect(decodeEntity('nosuch'), isNull);
        expect(decodeEntity(''), isNull);
      },
    );

    test('parseNumericEntity decimal and hex forms', () {
      expect(parseNumericEntity('#35'), equals(35));
      expect(parseNumericEntity('#x41'), equals(65));
      expect(parseNumericEntity('#X41'), equals(65));
      expect(parseNumericEntity('#0'), equals(0xFFFD));
      expect(parseNumericEntity('#xD800'), equals(0xFFFD));
      expect(parseNumericEntity('#xDFFF'), equals(0xFFFD));
      expect(parseNumericEntity('#x110000'), equals(0xFFFD));
      expect(parseNumericEntity('#12345678'), isNull); // 8 digits exceeds max 7
      expect(
        parseNumericEntity('#x1234567'),
        isNull,
      ); // 7 hex digits exceeds max 6
      expect(parseNumericEntity('#xyz'), isNull);
      expect(parseNumericEntity('notnumeric'), isNull);
    });
  });
}
