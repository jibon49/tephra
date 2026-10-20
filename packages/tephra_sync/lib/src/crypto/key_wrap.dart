// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../errors/crypto_exceptions.dart';
import 'master_key.dart';

/// Encapsulates an encrypted master key wrapped using AES-256-GCM.
final class WrappedKey {
  /// Creates a [WrappedKey].
  const WrappedKey({
    this.alg = defaultAlg,
    required this.nonce,
    required this.ciphertext,
    this.salt,
  });

  /// Decodes a [WrappedKey] from JSON.
  factory WrappedKey.fromJson(Map<String, Object?> json) {
    final nonceStr = json['nonce'] as String;
    final cipherStr = json['ciphertext'] as String;
    final saltStr = json['salt'] as String?;

    return WrappedKey(
      alg: json['alg'] as String? ?? defaultAlg,
      nonce: base64Decode(nonceStr),
      ciphertext: base64Decode(cipherStr),
      salt: saltStr != null ? base64Decode(saltStr) : null,
    );
  }

  /// Default encryption algorithm identifier.
  static const String defaultAlg = 'aes-256-gcm';

  /// AES-GCM nonce length in bytes (96 bits = 12 bytes).
  static const int nonceLength = 12;

  /// Expected ciphertext length: 32 bytes master key + 16 bytes GCM tag = 48 bytes.
  static const int expectedCiphertextLength = 48;

  /// Expected recovery salt length in bytes (16 bytes).
  static const int recoverySaltLength = 16;

  /// Algorithm identifier (always 'aes-256-gcm').
  final String alg;

  /// Random 12-byte initialization vector.
  final List<int> nonce;

  /// Encrypted 32-byte master key followed by 16-byte GCM authentication tag.
  final List<int> ciphertext;

  /// Random 16-byte salt (present when wrapped using a recovery key).
  final List<int>? salt;

  /// Wraps [masterKey] using [kek] with associated data binding [vaultId] and [purpose].
  static Future<WrappedKey> wrap({
    required SecretKey kek,
    required MasterKey masterKey,
    required String vaultId,
    required String purpose,
    List<int>? salt,
    Random? random,
  }) async {
    final rng = random ?? Random.secure();
    final nonce = Uint8List(nonceLength);
    for (var i = 0; i < nonceLength; i++) {
      nonce[i] = rng.nextInt(256);
    }

    final aad = utf8.encode('tephra-wrap-v1|$vaultId|$purpose');
    final aes = AesGcm.with256bits();
    final secretBox = await aes.encrypt(
      masterKey.bytes,
      secretKey: kek,
      nonce: nonce,
      aad: aad,
    );

    final combined = Uint8List(
      secretBox.cipherText.length + secretBox.mac.bytes.length,
    );
    combined.setRange(0, secretBox.cipherText.length, secretBox.cipherText);
    combined.setRange(
      secretBox.cipherText.length,
      combined.length,
      secretBox.mac.bytes,
    );

    return WrappedKey(
      alg: defaultAlg,
      nonce: nonce,
      ciphertext: combined,
      salt: salt,
    );
  }

  /// Unwraps this [WrappedKey] using [kek] with associated data binding [vaultId] and [purpose].
  ///
  /// Throws [WrongPasswordException] (when purpose == 'password') or
  /// [WrongRecoveryKeyException] (when purpose == 'recovery') on authentication failure.
  Future<MasterKey> unwrap({
    required SecretKey kek,
    required String vaultId,
    required String purpose,
  }) async {
    if (ciphertext.length < 16) {
      _throwAuthFailure(purpose);
    }

    final cipherBytes = ciphertext.sublist(0, ciphertext.length - 16);
    final tagBytes = ciphertext.sublist(ciphertext.length - 16);
    final aad = utf8.encode('tephra-wrap-v1|$vaultId|$purpose');

    final aes = AesGcm.with256bits();
    final secretBox = SecretBox(cipherBytes, nonce: nonce, mac: Mac(tagBytes));

    try {
      final decrypted = await aes.decrypt(secretBox, secretKey: kek, aad: aad);
      return MasterKey(decrypted);
    } on SecretBoxAuthenticationError {
      _throwAuthFailure(purpose);
    } catch (_) {
      _throwAuthFailure(purpose);
    }
  }

  static Never _throwAuthFailure(String purpose) {
    if (purpose == 'recovery') {
      throw const WrongRecoveryKeyException();
    }
    throw const WrongPasswordException();
  }

  /// Encodes this [WrappedKey] to JSON.
  Map<String, Object?> toJson() => {
    'alg': alg,
    'nonce': base64Encode(nonce),
    'ciphertext': base64Encode(ciphertext),
    if (salt != null) 'salt': base64Encode(salt!),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WrappedKey &&
          runtimeType == other.runtimeType &&
          alg == other.alg &&
          _bytesEquals(nonce, other.nonce) &&
          _bytesEquals(ciphertext, other.ciphertext) &&
          _nullableBytesEquals(salt, other.salt);

  @override
  int get hashCode => Object.hash(
    alg,
    Object.hashAll(nonce),
    Object.hashAll(ciphertext),
    salt == null ? 0 : Object.hashAll(salt!),
  );

  @override
  String toString() =>
      'WrappedKey(alg: $alg, nonceLen: ${nonce.length}, cipherLen: ${ciphertext.length})';

  static bool _bytesEquals(List<int> a, List<int> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _nullableBytesEquals(List<int>? a, List<int>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return _bytesEquals(a, b);
  }
}
