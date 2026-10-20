// © 2026 Tephra. All rights reserved.

import 'dart:math';

import 'package:tephra_sync/tephra_sync.dart';
import 'package:test/test.dart';

void main() {
  group('RecoveryKey tests', () {
    test('format regex and display string structure', () {
      final key = RecoveryKey.generate(random: Random(42));
      final display = key.displayString;

      expect(RecoveryKey.formatRegex.hasMatch(display), isTrue);
      final groups = display.split('-');
      expect(groups.length, equals(8));
      for (final g in groups) {
        expect(g.length, equals(4));
      }
    });

    test('round trip: generate -> displayString -> parse', () {
      for (var seed = 0; seed < 20; seed++) {
        final original = RecoveryKey.generate(random: Random(seed));
        final str = original.displayString;
        final parsed = RecoveryKey.parse(str);
        expect(parsed.bytes, equals(original.bytes));
      }
    });

    test('parse tolerates lowercase, spaces, missing dashes', () {
      final key = RecoveryKey.generate(random: Random(123));
      final standard = key.displayString;

      // Lowercase
      final lower = standard.toLowerCase();
      expect(RecoveryKey.parse(lower).bytes, equals(key.bytes));

      // With extra spaces
      final withSpaces = '  ${standard.replaceAll('-', '   ')}  ';
      expect(RecoveryKey.parse(withSpaces).bytes, equals(key.bytes));

      // Without any dashes
      final noDashes = standard.replaceAll('-', '');
      expect(RecoveryKey.parse(noDashes).bytes, equals(key.bytes));
    });

    test('parse maps common visual misreads (0->O, 1->I, 8->B)', () {
      final raw16 = List<int>.generate(16, (i) => i * 17);
      final knownKey = RecoveryKey(raw16);
      final knownDisplay = knownKey.displayString;

      var replaced = knownDisplay;
      if (replaced.contains('O')) replaced = replaced.replaceAll('O', '0');
      if (replaced.contains('I')) replaced = replaced.replaceAll('I', '1');
      if (replaced.contains('B')) replaced = replaced.replaceAll('B', '8');

      final parsed = RecoveryKey.parse(replaced);
      expect(parsed.bytes, equals(knownKey.bytes));
    });

    test('changing any single character throws WrongRecoveryKeyException', () {
      final key = RecoveryKey.generate(random: Random(789));
      final standard = key.displayString.replaceAll('-', '');

      for (var i = 0; i < standard.length; i++) {
        final originalChar = standard[i];
        final changedChar = originalChar == 'A' ? 'Z' : 'A';
        final corrupted =
            standard.substring(0, i) + changedChar + standard.substring(i + 1);

        expect(
          () => RecoveryKey.parse(corrupted),
          throwsA(isA<WrongRecoveryKeyException>()),
          reason:
              'Corrupted character at index $i did not trigger WrongRecoveryKeyException',
        );
      }
    });

    test(
      'invalid length or non-base32 characters throw WrongRecoveryKeyException',
      () {
        expect(
          () => RecoveryKey.parse('ABCD-EFGH'),
          throwsA(isA<WrongRecoveryKeyException>()),
        );
        expect(
          () =>
              RecoveryKey.parse('ABCD-EFGH-IJKL-MNOP-QRST-UVWX-YZ23-4567-8900'),
          throwsA(isA<WrongRecoveryKeyException>()),
        );
        // 9 is not valid in RFC 4648 Base32 and not mapped
        expect(
          () => RecoveryKey.parse('9999-EFGH-IJKL-MNOP-QRST-UVWX-YZ23-4567'),
          throwsA(isA<WrongRecoveryKeyException>()),
        );
      },
    );

    test('deriveRecoveryKek derives 32-byte key via HKDF', () async {
      final key = RecoveryKey.generate(random: Random(999));
      final salt = List<int>.generate(16, (i) => i);
      final kek = await key.deriveRecoveryKek(recoverySalt: salt);
      final bytes = await kek.extractBytes();

      expect(bytes.length, equals(32));
    });
  });
}
