// © 2026 Tephra. All rights reserved.

import 'package:tephra_markdown/src/util/unicode.dart';
import 'package:test/test.dart';

void main() {
  group('Unicode utilities', () {
    test('isUnicodePunctuation', () {
      expect(isUnicodePunctuation('!'.codeUnitAt(0)), isTrue);
      expect(isUnicodePunctuation(0x2014), isTrue); // '—' em dash
      expect(
        isUnicodePunctuation('。'.runes.first),
        isTrue,
      ); // ideographic full stop
      expect(
        isUnicodePunctuation('€'.runes.first),
        isTrue,
      ); // euro symbol (S category)

      expect(isUnicodePunctuation('a'.codeUnitAt(0)), isFalse);
      expect(isUnicodePunctuation('5'.codeUnitAt(0)), isFalse);
      expect(isUnicodePunctuation(' '.codeUnitAt(0)), isFalse);
    });

    test('isUnicodeWhitespace', () {
      expect(isUnicodeWhitespace(0x00A0), isTrue); // NBSP
      expect(isUnicodeWhitespace(0x3000), isTrue); // ideographic space
      expect(isUnicodeWhitespace('\t'.codeUnitAt(0)), isTrue);
      expect(isUnicodeWhitespace('\n'.codeUnitAt(0)), isTrue);
      expect(isUnicodeWhitespace(' '.codeUnitAt(0)), isTrue);

      expect(
        isUnicodeWhitespace(0x0085),
        isFalse,
      ); // NEL is explicitly not included
      expect(isUnicodeWhitespace('a'.codeUnitAt(0)), isFalse);
    });

    test('isLetterOrDigit', () {
      expect(isLetterOrDigit('a'.codeUnitAt(0)), isTrue);
      expect(isLetterOrDigit('Z'.codeUnitAt(0)), isTrue);
      expect(isLetterOrDigit('9'.codeUnitAt(0)), isTrue);
      expect(isLetterOrDigit('é'.runes.first), isTrue);
      expect(isLetterOrDigit('!'.codeUnitAt(0)), isFalse);
    });

    test('caseFold', () {
      expect(caseFold('ẞ'), equals('ss'));
      expect(caseFold('ß'), equals('ss'));
      expect(caseFold('Hello WORLD'), equals('hello world'));
    });

    test('normalizeLabel', () {
      expect(normalizeLabel('  Foo \n BAR '), equals('foo bar'));
      expect(normalizeLabel('  [Test]  Label  '), equals('[test] label'));
      expect(
        normalizeLabel('Stra\u00DFe'),
        equals('strasse'),
      ); // Straße -> strasse
    });
  });
}
