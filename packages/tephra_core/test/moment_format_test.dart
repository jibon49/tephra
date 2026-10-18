// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';
import 'package:test/test.dart';

void main() {
  group('formatMoment', () {
    final t = DateTime(2026, 10, 11, 14, 5, 9);

    test('YYYY-MM-DD', () {
      expect(formatMoment(t, 'YYYY-MM-DD'), equals('2026-10-11'));
    });

    test('YY/M/D', () {
      expect(formatMoment(t, 'YY/M/D'), equals('26/10/11'));
    });

    test('dddd, MMMM Do YYYY', () {
      expect(
        formatMoment(t, 'dddd, MMMM Do YYYY'),
        equals('Sunday, October 11th 2026'),
      );
    });

    test('ddd MMM D', () {
      expect(formatMoment(t, 'ddd MMM D'), equals('Sun Oct 11'));
    });

    test('HH:mm:ss', () {
      expect(formatMoment(t, 'HH:mm:ss'), equals('14:05:09'));
    });

    test('hh:mm A', () {
      expect(formatMoment(t, 'hh:mm A'), equals('02:05 PM'));
    });

    test('h:m a', () {
      expect(formatMoment(t, 'h:m a'), equals('2:5 pm'));
    });

    test('[Week] D', () {
      expect(formatMoment(t, '[Week] D'), equals('Week 11'));
    });

    test('YYYY-MM-DD[T]HH:mm', () {
      expect(formatMoment(t, 'YYYY-MM-DD[T]HH:mm'), equals('2026-10-11T14:05'));
    });

    test('unknown tokens copied as written (Q)', () {
      expect(formatMoment(t, 'Q'), equals('Q'));
    });

    test(
      'ordinals 1st, 2nd, 3rd, 4th, 11th, 12th, 13th, 21st, 22nd, 23rd, 31st',
      () {
        String ord(int day) => formatMoment(DateTime(2026, 1, day), 'Do');
        expect(ord(1), equals('1st'));
        expect(ord(2), equals('2nd'));
        expect(ord(3), equals('3rd'));
        expect(ord(4), equals('4th'));
        expect(ord(11), equals('11th'));
        expect(ord(12), equals('12th'));
        expect(ord(13), equals('13th'));
        expect(ord(21), equals('21st'));
        expect(ord(22), equals('22nd'));
        expect(ord(23), equals('23rd'));
        expect(ord(31), equals('31st'));
      },
    );

    test('midnight h -> 12, hh -> 12, A -> AM; noon A -> PM', () {
      final midnight = DateTime(2026, 10, 11, 0, 0, 0);
      expect(formatMoment(midnight, 'h'), equals('12'));
      expect(formatMoment(midnight, 'hh'), equals('12'));
      expect(formatMoment(midnight, 'A'), equals('AM'));

      final noon = DateTime(2026, 10, 11, 12, 0, 0);
      expect(formatMoment(noon, 'h'), equals('12'));
      expect(formatMoment(noon, 'hh'), equals('12'));
      expect(formatMoment(noon, 'A'), equals('PM'));
    });
  });

  group('parseMoment', () {
    test('YYYY-MM-DD', () {
      expect(
        parseMoment('2026-10-11', 'YYYY-MM-DD'),
        equals(DateTime(2026, 10, 11)),
      );
    });

    test('dddd, MMMM Do YYYY', () {
      expect(
        parseMoment('Sunday, October 11th 2026', 'dddd, MMMM Do YYYY'),
        equals(DateTime(2026, 10, 11)),
      );
    });

    test('invalid date returns null (2026-02-30)', () {
      expect(parseMoment('2026-02-30', 'YYYY-MM-DD'), isNull);
    });

    test('YYYY-MM-DD hh:mm A with PM adds 12', () {
      expect(
        parseMoment('2026-10-11 02:05 PM', 'YYYY-MM-DD hh:mm A'),
        equals(DateTime(2026, 10, 11, 14, 5)),
      );
    });

    test('missing required tokens or non-matching string returns null', () {
      expect(parseMoment('x', 'YYYY'), isNull);
      expect(parseMoment('2026-10-11', 'YYYY-MM'), isNull); // missing day
    });
  });

  group('validateMomentFormat', () {
    test('empty string -> empty', () {
      expect(validateMomentFormat(''), equals(MomentFormatError.empty));
    });

    test('unbalanced bracket [abc -> unbalancedBracket', () {
      expect(
        validateMomentFormat('[abc'),
        equals(MomentFormatError.unbalancedBracket),
      );
    });

    test('YYYY:MM with forFileName: true -> forbiddenCharacter', () {
      expect(
        validateMomentFormat('YYYY:MM', forFileName: true),
        equals(MomentFormatError.forbiddenCharacter),
      );
    });

    test('YYYY/MM/DD with forFileName: true, requireDate: true -> null', () {
      expect(
        validateMomentFormat(
          'YYYY/MM/DD',
          forFileName: true,
          requireDate: true,
        ),
        isNull,
      );
    });

    test('HH:mm with forFileName: true -> forbiddenCharacter', () {
      expect(
        validateMomentFormat('HH:mm', forFileName: true),
        equals(MomentFormatError.forbiddenCharacter),
      );
    });

    test('YYYY-MM with requireDate: true -> noDateTokens', () {
      expect(
        validateMomentFormat('YYYY-MM', requireDate: true),
        equals(MomentFormatError.noDateTokens),
      );
    });

    test('HHmm with forFileName: true (no requireDate) -> null', () {
      expect(validateMomentFormat('HHmm', forFileName: true), isNull);
    });
  });
}
