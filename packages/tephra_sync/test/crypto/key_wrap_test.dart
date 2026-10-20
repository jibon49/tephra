// © 2026 Tephra. All rights reserved.

import 'dart:math';

import 'package:tephra_sync/tephra_sync.dart';
import 'package:test/test.dart';

void main() {
  group('WrappedKey and KeyWrap tests', () {
    const vaultId = '11111111-2222-3333-4444-555555555555';
    late MasterKey masterKey;
    late SecretKey passwordKek;
    late SecretKey wrongPasswordKek;
    late SecretKey recoveryKek;

    setUp(() async {
      masterKey = MasterKey.generate(random: Random(100));
      passwordKek = SecretKey(List<int>.generate(32, (i) => i));
      wrongPasswordKek = SecretKey(List<int>.generate(32, (i) => i ^ 0xFF));
      recoveryKek = SecretKey(List<int>.generate(32, (i) => (i * 7) & 0xFF));
    });

    test('wrap and unwrap master key with password KEK', () async {
      final wrapped = await WrappedKey.wrap(
        kek: passwordKek,
        masterKey: masterKey,
        vaultId: vaultId,
        purpose: 'password',
      );

      expect(wrapped.alg, equals('aes-256-gcm'));
      expect(wrapped.nonce.length, equals(12));
      expect(wrapped.ciphertext.length, equals(48)); // 32 master key + 16 tag
      expect(wrapped.salt, isNull);

      final unwrapped = await wrapped.unwrap(
        kek: passwordKek,
        vaultId: vaultId,
        purpose: 'password',
      );

      expect(unwrapped.bytes, equals(masterKey.bytes));
    });

    test('wrap and unwrap master key with recovery KEK', () async {
      final recoverySalt = List<int>.generate(16, (i) => i + 1);
      final wrapped = await WrappedKey.wrap(
        kek: recoveryKek,
        masterKey: masterKey,
        vaultId: vaultId,
        purpose: 'recovery',
        salt: recoverySalt,
      );

      expect(wrapped.salt, equals(recoverySalt));

      final unwrapped = await wrapped.unwrap(
        kek: recoveryKek,
        vaultId: vaultId,
        purpose: 'recovery',
      );

      expect(unwrapped.bytes, equals(masterKey.bytes));
    });

    test('wrong password KEK throws WrongPasswordException', () async {
      final wrapped = await WrappedKey.wrap(
        kek: passwordKek,
        masterKey: masterKey,
        vaultId: vaultId,
        purpose: 'password',
      );

      expect(
        () => wrapped.unwrap(
          kek: wrongPasswordKek,
          vaultId: vaultId,
          purpose: 'password',
        ),
        throwsA(isA<WrongPasswordException>()),
      );
    });

    test('wrong recovery KEK throws WrongRecoveryKeyException', () async {
      final wrapped = await WrappedKey.wrap(
        kek: recoveryKek,
        masterKey: masterKey,
        vaultId: vaultId,
        purpose: 'recovery',
      );

      expect(
        () => wrapped.unwrap(
          kek: wrongPasswordKek,
          vaultId: vaultId,
          purpose: 'recovery',
        ),
        throwsA(isA<WrongRecoveryKeyException>()),
      );
    });

    test(
      'changing AAD purpose (password vs recovery) fails unwrapping',
      () async {
        final wrappedForPassword = await WrappedKey.wrap(
          kek: passwordKek,
          masterKey: masterKey,
          vaultId: vaultId,
          purpose: 'password',
        );

        // Attempting to unwrap with purpose 'recovery' mismatches AAD
        expect(
          () => wrappedForPassword.unwrap(
            kek: passwordKek,
            vaultId: vaultId,
            purpose: 'recovery',
          ),
          throwsA(isA<WrongRecoveryKeyException>()),
        );
      },
    );

    test('changing vaultId fails unwrapping', () async {
      final wrapped = await WrappedKey.wrap(
        kek: passwordKek,
        masterKey: masterKey,
        vaultId: vaultId,
        purpose: 'password',
      );

      expect(
        () => wrapped.unwrap(
          kek: passwordKek,
          vaultId: 'wrong-vault-id',
          purpose: 'password',
        ),
        throwsA(isA<WrongPasswordException>()),
      );
    });

    test('JSON serialization round trip', () async {
      final wrappedPassword = await WrappedKey.wrap(
        kek: passwordKek,
        masterKey: masterKey,
        vaultId: vaultId,
        purpose: 'password',
      );

      final json1 = wrappedPassword.toJson();
      final roundTrip1 = WrappedKey.fromJson(json1);
      expect(roundTrip1, equals(wrappedPassword));

      final recoverySalt = List<int>.generate(16, (i) => i * 3);
      final wrappedRecovery = await WrappedKey.wrap(
        kek: recoveryKek,
        masterKey: masterKey,
        vaultId: vaultId,
        purpose: 'recovery',
        salt: recoverySalt,
      );

      final json2 = wrappedRecovery.toJson();
      final roundTrip2 = WrappedKey.fromJson(json2);
      expect(roundTrip2, equals(wrappedRecovery));
      expect(roundTrip2.salt, equals(recoverySalt));
    });
  });
}
