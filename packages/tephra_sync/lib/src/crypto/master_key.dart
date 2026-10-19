// © 2026 Tephra. All rights reserved.

import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// 256-bit symmetric root key for an encrypted remote vault.
///
/// Generated once when creating an encrypted vault.
/// Never stored unencrypted, uploaded in the clear, or logged.
final class MasterKey {
  /// Wraps existing 32-byte [bytes] as a [MasterKey].
  MasterKey(List<int> bytes) : _bytes = Uint8List.fromList(bytes) {
    if (_bytes.length != keyLength) {
      throw ArgumentError.value(
        _bytes.length,
        'bytes.length',
        'Master key must be exactly $keyLength bytes',
      );
    }
  }

  /// Generates a fresh 256-bit [MasterKey] using [Random.secure] (or injected [random]).
  factory MasterKey.generate({Random? random}) {
    final rng = random ?? Random.secure();
    final bytes = Uint8List(keyLength);
    for (var i = 0; i < keyLength; i++) {
      bytes[i] = rng.nextInt(256);
    }
    return MasterKey(bytes);
  }

  /// Expected length of the master key in bytes (256 bits = 32 bytes).
  static const int keyLength = 32;

  final Uint8List _bytes;

  /// Raw 32 bytes of the master key.
  Uint8List get bytes => Uint8List.fromList(_bytes);

  /// Cryptography [SecretKey] view of the master key.
  SecretKey get secretKey => SecretKey(_bytes);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MasterKey &&
          runtimeType == other.runtimeType &&
          _bytesEquals(_bytes, other._bytes);

  @override
  int get hashCode => Object.hashAll(_bytes);

  @override
  String toString() => 'MasterKey(***redacted***)';

  static bool _bytesEquals(List<int> a, List<int> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
