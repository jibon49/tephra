// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';

import '../errors/crypto_exceptions.dart';
import 'base32.dart';

/// 128-bit emergency recovery key with embedded checksum.
///
/// Displayed as 8 groups of 4 characters joined by dashes:
/// `ABCD-EFGH-IJKL-MNOP-QRST-UVWX-YZ23-4567`.
final class RecoveryKey {
  /// Wraps 16 random recovery bytes [bytes].
  RecoveryKey(List<int> bytes) : _bytes = Uint8List.fromList(bytes) {
    if (_bytes.length != keyLength) {
      throw ArgumentError.value(
        _bytes.length,
        'bytes.length',
        'Recovery key bytes must be exactly $keyLength bytes',
      );
    }
  }

  /// Generates a fresh [RecoveryKey] using [Random.secure] (or injected [random]).
  factory RecoveryKey.generate({Random? random}) {
    final rng = random ?? Random.secure();
    final bytes = Uint8List(keyLength);
    for (var i = 0; i < keyLength; i++) {
      bytes[i] = rng.nextInt(256);
    }
    return RecoveryKey(bytes);
  }

  /// Parses a user-entered recovery key string.
  ///
  /// Tolerates lower-case characters, spaces, dashes, and maps common
  /// visual misreads: '0' -> 'O', '1' -> 'I', '8' -> 'B'.
  ///
  /// Throws [WrongRecoveryKeyException] on invalid length, invalid Base32
  /// characters, or checksum mismatch.
  factory RecoveryKey.parse(String input) {
    // 1. Upper-case and strip spaces / dashes
    var sanitized = input.toUpperCase().replaceAll(RegExp(r'[\s\-]+'), '');

    // 2. Map common misreads: 0->O, 1->I, 8->B
    sanitized = sanitized
        .replaceAll('0', 'O')
        .replaceAll('1', 'I')
        .replaceAll('8', 'B');

    // 3. Must be exactly 32 Base32 characters (20 bytes = 16 key + 4 checksum)
    if (sanitized.length != 32) {
      throw const WrongRecoveryKeyException(
        'Recovery key must be exactly 32 characters (excluding dashes)',
      );
    }

    // 4. Base32 decode
    final Uint8List payload;
    try {
      payload = base32Decode(sanitized);
    } on FormatException catch (e) {
      throw WrongRecoveryKeyException(
        'Invalid characters in recovery key: ${e.message}',
      );
    }

    if (payload.length != 20) {
      throw const WrongRecoveryKeyException(
        'Decoded recovery key length is invalid',
      );
    }

    final keyBytes = payload.sublist(0, 16);
    final checksumBytes = payload.sublist(16, 20);

    // 5. Verify checksum
    final computedChecksum = _computeChecksum(keyBytes);
    if (!_constantTimeEquals(computedChecksum, checksumBytes)) {
      throw const WrongRecoveryKeyException('Recovery key checksum mismatch');
    }

    return RecoveryKey(keyBytes);
  }

  /// Recovery key length in bytes (128 bits = 16 bytes).
  static const int keyLength = 16;

  /// Checksum length in bytes (32 bits = 4 bytes).
  static const int checksumLength = 4;

  /// Standard regex pattern for formatted display strings.
  static final RegExp formatRegex = RegExp(r'^[A-Z2-7]{4}(-[A-Z2-7]{4}){7}$');

  /// Context info string for HKDF-SHA256 recovery KEK derivation.
  static const String recoveryKekInfo = 'tephra/v1/recovery-kek';

  final Uint8List _bytes;

  /// Raw 16 bytes of entropy.
  Uint8List get bytes => Uint8List.fromList(_bytes);

  /// Computes the first 4 bytes of SHA-256(_bytes).
  Uint8List get checksum => _computeChecksum(_bytes);

  /// Returns the canonical display string formatted as 8 groups of 4 separated by '-'.
  String get displayString {
    final combined = Uint8List(keyLength + checksumLength);
    combined.setRange(0, keyLength, _bytes);
    combined.setRange(keyLength, combined.length, checksum);

    final base32 = base32Encode(combined);
    assert(base32.length == 32);

    final groups = <String>[];
    for (var i = 0; i < 32; i += 4) {
      groups.add(base32.substring(i, i + 4));
    }
    return groups.join('-');
  }

  /// Derives the 32-byte Recovery Key Encryption Key (KEK) using HKDF-SHA256.
  ///
  /// No Argon2id is needed because the recovery key already contains 128 bits of full entropy.
  Future<SecretKey> deriveRecoveryKek({required List<int> recoverySalt}) async {
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    return hkdf.deriveKey(
      secretKey: SecretKey(_bytes),
      nonce: recoverySalt,
      info: utf8.encode(recoveryKekInfo),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecoveryKey &&
          runtimeType == other.runtimeType &&
          _constantTimeEquals(_bytes, other._bytes);

  @override
  int get hashCode => Object.hashAll(_bytes);

  @override
  String toString() => 'RecoveryKey(***redacted***)';

  static Uint8List _computeChecksum(List<int> bytes) {
    final digest = crypto.sha256.convert(bytes);
    return Uint8List.fromList(digest.bytes.sublist(0, checksumLength));
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
