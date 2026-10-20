// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import 'package:tephra_sync/src/crypto/base32.dart';
import 'package:test/test.dart';

void main() {
  group('Base32 RFC 4648 §10 test vectors (no padding)', () {
    final vectors = {
      '': '',
      'f': 'MY',
      'fo': 'MZXQ',
      'foo': 'MZXW6',
      'foob': 'MZXW6YQ',
      'fooba': 'MZXW6YTB',
      'foobar': 'MZXW6YTBOI',
    };

    for (final entry in vectors.entries) {
      test('encode "${entry.key}" -> "${entry.value}"', () {
        final encoded = base32Encode(utf8.encode(entry.key));
        expect(encoded, equals(entry.value));
      });

      test('decode "${entry.value}" -> "${entry.key}"', () {
        final decoded = base32Decode(entry.value);
        expect(utf8.decode(decoded), equals(entry.key));
      });
    }

    test('case insensitivity on decode', () {
      expect(utf8.decode(base32Decode('my')), equals('f'));
      expect(utf8.decode(base32Decode('mzxw6ytboi')), equals('foobar'));
    });

    test('invalid characters throw FormatException', () {
      expect(
        () => base32Decode('MZXW8'),
        throwsFormatException,
      ); // 8 is invalid in Base32
      expect(
        () => base32Decode('MZXW0'),
        throwsFormatException,
      ); // 0 is invalid in Base32
      expect(
        () => base32Decode('MZXW1'),
        throwsFormatException,
      ); // 1 is invalid in Base32
      expect(
        () => base32Decode('MZXW='),
        throwsFormatException,
      ); // padding not accepted
    });
  });
}
