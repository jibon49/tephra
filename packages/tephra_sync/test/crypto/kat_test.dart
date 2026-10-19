// © 2026 Tephra. All rights reserved.

import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:test/test.dart';

Uint8List hexToBytes(String hex) {
  final clean = hex.replaceAll(RegExp(r'\s+'), '');
  final bytes = Uint8List(clean.length ~/ 2);
  for (var i = 0; i < clean.length; i += 2) {
    bytes[i ~/ 2] = int.parse(clean.substring(i, i + 2), radix: 16);
  }
  return bytes;
}

String bytesToHex(List<int> bytes) {
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

void main() {
  group('Known-Answer Tests (KAT)', () {
    test('AES-256-GCM empty plaintext', () async {
      final aes = AesGcm.with256bits();
      final key = SecretKey(List<int>.filled(32, 0));
      final nonce = List<int>.filled(12, 0);

      final box = await aes.encrypt(const [], secretKey: key, nonce: nonce);

      expect(box.cipherText, isEmpty);
      expect(
        bytesToHex(box.mac.bytes),
        equals('530f8afbc74536b9a963b4f1c4cb738b'),
      );
    });

    test('AES-256-GCM 16 zero bytes plaintext', () async {
      final aes = AesGcm.with256bits();
      final key = SecretKey(List<int>.filled(32, 0));
      final nonce = List<int>.filled(12, 0);

      final box = await aes.encrypt(
        List<int>.filled(16, 0),
        secretKey: key,
        nonce: nonce,
      );

      expect(
        bytesToHex(box.cipherText),
        equals('cea7403d4d606b6e074ec5d3baf39d18'),
      );
      expect(
        bytesToHex(box.mac.bytes),
        equals('d0d1c8a799996bf0265b98b5d48ab919'),
      );
    });

    test('HKDF RFC 5869 test case 1', () async {
      final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 42);
      final ikm = List<int>.filled(22, 0x0b);
      final salt = hexToBytes('000102030405060708090a0b0c');
      final info = hexToBytes('f0f1f2f3f4f5f6f7f8f9');

      final key = await hkdf.deriveKey(
        secretKey: SecretKey(ikm),
        nonce: salt,
        info: info,
      );
      final actual = await key.extractBytes();
      final expected = hexToBytes(
        '3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf34007208d5b887185865',
      );
      expect(bytesToHex(actual), equals(bytesToHex(expected)));
    });

    test('Argon2id RFC 9106 §5.3 test vector', () async {
      final argon = Argon2id(
        parallelism: 4,
        memory: 32,
        iterations: 3,
        hashLength: 32,
      );
      final password = List<int>.filled(32, 0x01);
      final salt = List<int>.filled(16, 0x02);
      final secret = List<int>.filled(8, 0x03);
      final ad = List<int>.filled(12, 0x04);

      final key = await argon.deriveKey(
        secretKey: SecretKey(password),
        nonce: salt,
        optionalSecret: secret,
        associatedData: ad,
      );
      final actual = await key.extractBytes();
      final expected = hexToBytes(
        '0d640df58d78766c08c037a34a8b53c9d01ef0452d75b65eb52520e96b01e659',
      );
      expect(bytesToHex(actual), equals(bytesToHex(expected)));
    });
  });
}
