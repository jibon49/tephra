// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../errors/crypto_exceptions.dart';
import 'object_purpose.dart';

/// Cryptographic envelope specification and codec for all encrypted Tephra objects.
///
/// Layout (TPH1):
/// - [0..3]: Magic ASCII `TPH1` (`0x54 0x50 0x48 0x31`)
/// - [4]: Format version (`0x01`)
/// - [5]: Object purpose code (1..7)
/// - [6..21]: Object salt (16 random bytes)
/// - [22..33]: AES-GCM nonce (12 random bytes)
/// - [34..34+n-1]: AES-256-GCM ciphertext
/// - [34+n..34+n+15]: AES-GCM authentication tag (16 bytes)
abstract final class Tph1Envelope {
  /// Magic bytes: 'T', 'P', 'H', '1'.
  static const List<int> magic = [0x54, 0x50, 0x48, 0x31];

  /// Current envelope version.
  static const int currentVersion = 0x01;

  /// Fixed header size in bytes before ciphertext.
  static const int headerLength = 34;

  /// Salt length in bytes.
  static const int saltLength = 16;

  /// AES-GCM nonce length in bytes (96 bits = 12 bytes).
  static const int nonceLength = 12;

  /// AES-GCM tag length in bytes (128 bits = 16 bytes).
  static const int tagLength = 16;

  /// Minimum total envelope size with empty (0-byte) plaintext: 34 + 16 = 50 bytes.
  static const int minEnvelopeLength = headerLength + tagLength;

  /// Encrypts and seals [plaintext] into a `TPH1` envelope.
  static Future<Uint8List> seal({
    required List<int> plaintext,
    required ObjectPurpose purpose,
    required SecretKey masterKey,
    required String vaultId,
    Random? random,
  }) async {
    final rng = random ?? Random.secure();
    final salt = Uint8List(saltLength);
    for (var i = 0; i < saltLength; i++) {
      salt[i] = rng.nextInt(256);
    }

    final nonce = Uint8List(nonceLength);
    for (var i = 0; i < nonceLength; i++) {
      nonce[i] = rng.nextInt(256);
    }

    // 1. Construct 34-byte header
    final header = Uint8List(headerLength);
    header.setRange(0, 4, magic);
    header[4] = currentVersion;
    header[5] = purpose.code;
    header.setRange(6, 22, salt);
    header.setRange(22, 34, nonce);

    // 2. Derive purpose-bound object key via HKDF-SHA256
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final objectKey = await hkdf.deriveKey(
      secretKey: masterKey,
      nonce: salt,
      info: purpose.infoBytes,
    );

    // 3. Assemble AAD: 34 header bytes followed by UTF-8 vaultId
    final vaultIdBytes = utf8.encode(vaultId);
    final aad = Uint8List(headerLength + vaultIdBytes.length);
    aad.setRange(0, headerLength, header);
    aad.setRange(headerLength, aad.length, vaultIdBytes);

    // 4. Encrypt with AES-256-GCM
    final aes = AesGcm.with256bits();
    final box = await aes.encrypt(
      plaintext,
      secretKey: objectKey,
      nonce: nonce,
      aad: aad,
    );

    // 5. Construct final envelope
    final out = Uint8List(headerLength + box.cipherText.length + tagLength);
    out.setRange(0, headerLength, header);
    out.setRange(
      headerLength,
      headerLength + box.cipherText.length,
      box.cipherText,
    );
    out.setRange(
      headerLength + box.cipherText.length,
      out.length,
      box.mac.bytes,
    );

    return out;
  }

  /// Opens and decrypts a `TPH1` envelope in [stored].
  ///
  /// Checks magic -> version -> purpose -> GCM tag.
  /// Throws [UnsupportedEnvelopeException] on header or purpose mismatch.
  /// Throws [TamperedDataException] on corrupted ciphertext, tag mismatch, or wrong vaultId.
  static Future<Uint8List> open({
    required List<int> stored,
    required ObjectPurpose expectedPurpose,
    required SecretKey masterKey,
    required String vaultId,
  }) async {
    if (stored.length < minEnvelopeLength) {
      throw const UnsupportedEnvelopeException(
        'Envelope too short (< 50 bytes)',
      );
    }

    // 1. Check Magic
    if (stored[0] != magic[0] ||
        stored[1] != magic[1] ||
        stored[2] != magic[2] ||
        stored[3] != magic[3]) {
      throw const UnsupportedEnvelopeException(
        'Invalid envelope magic header (expected TPH1)',
      );
    }

    // 2. Check Version
    if (stored[4] != currentVersion) {
      throw UnsupportedEnvelopeException(
        'Unsupported envelope version: ${stored[4]}',
      );
    }

    // 3. Check Purpose
    final purposeCode = stored[5];
    if (purposeCode != expectedPurpose.code) {
      throw UnsupportedEnvelopeException(
        'Envelope purpose mismatch: expected ${expectedPurpose.name} (${expectedPurpose.code}), got $purposeCode',
      );
    }

    final salt = stored.sublist(6, 22);
    final nonce = stored.sublist(22, 34);
    final header = stored.sublist(0, headerLength);

    // 4. Derive object key
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final objectKey = await hkdf.deriveKey(
      secretKey: masterKey,
      nonce: salt,
      info: expectedPurpose.infoBytes,
    );

    // 5. Assemble AAD
    final vaultIdBytes = utf8.encode(vaultId);
    final aad = Uint8List(headerLength + vaultIdBytes.length);
    aad.setRange(0, headerLength, header);
    aad.setRange(headerLength, aad.length, vaultIdBytes);

    // 6. Decrypt ciphertext + tag
    final cipherText = stored.sublist(headerLength, stored.length - tagLength);
    final tag = stored.sublist(stored.length - tagLength);

    final aes = AesGcm.with256bits();
    final box = SecretBox(cipherText, nonce: nonce, mac: Mac(tag));

    try {
      final decrypted = await aes.decrypt(box, secretKey: objectKey, aad: aad);
      return Uint8List.fromList(decrypted);
    } on SecretBoxAuthenticationError {
      throw const TamperedDataException();
    } catch (_) {
      throw const TamperedDataException();
    }
  }
}
