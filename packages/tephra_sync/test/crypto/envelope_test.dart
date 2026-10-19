// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:tephra_sync/tephra_sync.dart';
import 'package:test/test.dart';

String bytesToHex(List<int> bytes) {
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

void main() {
  group('Tph1Envelope tests', () {
    const vaultId = '00000000-0000-4000-8000-000000000000';
    final masterKeyBytes = List<int>.generate(32, (i) => i);
    final masterKey = SecretKey(masterKeyBytes);

    test('frozen envelope vector (format regression guard)', () async {
      // PROTECTS THE WIRE FORMAT FROM ACCIDENTAL CHANGE.
      // This golden hex is computed from Random(42), master key 0..31,
      // vaultId 00000000-0000-4000-8000-000000000000, purpose blob,
      // plaintext "hello tephra".
      final sealed = await Tph1Envelope.seal(
        plaintext: utf8.encode('hello tephra'),
        purpose: ObjectPurpose.blob,
        masterKey: masterKey,
        vaultId: vaultId,
        random: Random(42),
      );

      final hex = bytesToHex(sealed);

      // Verify that opening recovers original plaintext
      final decrypted = await Tph1Envelope.open(
        stored: sealed,
        expectedPurpose: ObjectPurpose.blob,
        masterKey: masterKey,
        vaultId: vaultId,
      );
      expect(utf8.decode(decrypted), equals('hello tephra'));

      // Assert exact frozen hex constant
      expect(
        hex,
        equals(
          '54504831010133aec45db5688f3d30b8ffe433734d1aa759e7aea41a4f205a646e5090fde6605f14f2835bd0747aa66820353f2b7515bf8c21444ae9219f',
        ),
      );
    });

    test('round trip for 0 B, 1 B, 1 MiB', () async {
      final cipher = EncryptingObjectCipher(
        masterKey: masterKey,
        vaultId: vaultId,
      );

      // 0 B
      final emptyPlain = Uint8List(0);
      final sealedEmpty = await cipher.seal(emptyPlain, ObjectPurpose.blob);
      expect(sealedEmpty.length, equals(50)); // 34 header + 0 cipher + 16 tag
      final openedEmpty = await cipher.open(sealedEmpty, ObjectPurpose.blob);
      expect(openedEmpty, isEmpty);

      // 1 B
      final oneBytePlain = Uint8List.fromList([0x42]);
      final sealedOne = await cipher.seal(oneBytePlain, ObjectPurpose.journal);
      expect(sealedOne.length, equals(51));
      final openedOne = await cipher.open(sealedOne, ObjectPurpose.journal);
      expect(openedOne, equals([0x42]));

      // 1 MiB (1,048,576 bytes)
      final largePlain = Uint8List(1048576);
      for (var i = 0; i < largePlain.length; i++) {
        largePlain[i] = i & 0xFF;
      }
      final sealedLarge = await cipher.seal(largePlain, ObjectPurpose.blob);
      expect(sealedLarge.length, equals(34 + 1048576 + 16));
      final openedLarge = await cipher.open(sealedLarge, ObjectPurpose.blob);
      expect(openedLarge, equals(largePlain));
    });

    test(
      'two seals of identical plaintext produce distinct ciphertexts',
      () async {
        final cipher = EncryptingObjectCipher(
          masterKey: masterKey,
          vaultId: vaultId,
        );

        final text = utf8.encode('identical content');
        final seal1 = await cipher.seal(text, ObjectPurpose.blob);
        final seal2 = await cipher.seal(text, ObjectPurpose.blob);

        expect(seal1, isNot(equals(seal2)));
      },
    );

    test('wrong purpose throws UnsupportedEnvelopeException', () async {
      final cipher = EncryptingObjectCipher(
        masterKey: masterKey,
        vaultId: vaultId,
      );

      final sealed = await cipher.seal(utf8.encode('test'), ObjectPurpose.blob);

      expect(
        () => cipher.open(sealed, ObjectPurpose.journal),
        throwsA(isA<UnsupportedEnvelopeException>()),
      );
    });

    test('wrong vaultId throws TamperedDataException', () async {
      final cipher1 = EncryptingObjectCipher(
        masterKey: masterKey,
        vaultId: 'vault-alpha',
      );
      final cipher2 = EncryptingObjectCipher(
        masterKey: masterKey,
        vaultId: 'vault-beta',
      );

      final sealed = await cipher1.seal(
        utf8.encode('test'),
        ObjectPurpose.blob,
      );

      expect(
        () => cipher2.open(sealed, ObjectPurpose.blob),
        throwsA(isA<TamperedDataException>()),
      );
    });

    test('flipping any byte in header throws exception', () async {
      final cipher = EncryptingObjectCipher(
        masterKey: masterKey,
        vaultId: vaultId,
      );
      final sealed = await cipher.seal(
        utf8.encode('hello'),
        ObjectPurpose.blob,
      );

      // Byte 0 (magic 'T')
      var corrupted = Uint8List.fromList(sealed);
      corrupted[0] ^= 0x01;
      expect(
        () => cipher.open(corrupted, ObjectPurpose.blob),
        throwsA(isA<UnsupportedEnvelopeException>()),
      );

      // Byte 4 (version)
      corrupted = Uint8List.fromList(sealed);
      corrupted[4] ^= 0x01;
      expect(
        () => cipher.open(corrupted, ObjectPurpose.blob),
        throwsA(isA<UnsupportedEnvelopeException>()),
      );

      // Byte 5 (purpose code)
      corrupted = Uint8List.fromList(sealed);
      corrupted[5] ^= 0x01;
      expect(
        () => cipher.open(corrupted, ObjectPurpose.blob),
        throwsA(isA<UnsupportedEnvelopeException>()),
      );

      // Byte 10 (salt) -> corrupting salt causes key derivation mismatch -> TamperedDataException
      corrupted = Uint8List.fromList(sealed);
      corrupted[10] ^= 0x01;
      expect(
        () => cipher.open(corrupted, ObjectPurpose.blob),
        throwsA(isA<TamperedDataException>()),
      );

      // Byte 25 (nonce) -> corrupting nonce causes GCM auth failure -> TamperedDataException
      corrupted = Uint8List.fromList(sealed);
      corrupted[25] ^= 0x01;
      expect(
        () => cipher.open(corrupted, ObjectPurpose.blob),
        throwsA(isA<TamperedDataException>()),
      );
    });

    test(
      'flipping any byte in ciphertext or tag throws TamperedDataException',
      () async {
        final cipher = EncryptingObjectCipher(
          masterKey: masterKey,
          vaultId: vaultId,
        );
        final sealed = await cipher.seal(
          utf8.encode('hello world'),
          ObjectPurpose.blob,
        );

        // Ciphertext byte (offset 35)
        var corrupted = Uint8List.fromList(sealed);
        corrupted[35] ^= 0xFF;
        expect(
          () => cipher.open(corrupted, ObjectPurpose.blob),
          throwsA(isA<TamperedDataException>()),
        );

        // Tag byte (last byte)
        corrupted = Uint8List.fromList(sealed);
        corrupted[corrupted.length - 1] ^= 0xFF;
        expect(
          () => cipher.open(corrupted, ObjectPurpose.blob),
          throwsA(isA<TamperedDataException>()),
        );
      },
    );

    test('PlaintextObjectCipher passthrough and TPH1 rejection', () async {
      const plaintextCipher = PlaintextObjectCipher();
      expect(plaintextCipher.encrypts, isFalse);

      final rawData = utf8.encode('# Markdown note in clear');
      final sealed = await plaintextCipher.seal(rawData, ObjectPurpose.blob);
      expect(sealed, equals(rawData));

      final opened = await plaintextCipher.open(sealed, ObjectPurpose.blob);
      expect(opened, equals(rawData));

      // Rejects TPH1 encrypted envelope in plaintext vault
      final encryptedData = await Tph1Envelope.seal(
        plaintext: rawData,
        purpose: ObjectPurpose.blob,
        masterKey: masterKey,
        vaultId: vaultId,
      );
      expect(
        () => plaintextCipher.open(encryptedData, ObjectPurpose.blob),
        throwsA(isA<UnsupportedEnvelopeException>()),
      );
    });
  });
}
