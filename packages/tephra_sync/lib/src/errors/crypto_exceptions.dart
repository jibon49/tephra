// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

/// Thrown when vault password verification fails during key derivation.
class WrongPasswordException extends CryptoException {
  /// Creates a [WrongPasswordException] with a technical description.
  const WrongPasswordException([super.message = 'Incorrect password']);
}

/// Thrown when recovery key verification or checksum validation fails.
class WrongRecoveryKeyException extends CryptoException {
  /// Creates a [WrongRecoveryKeyException] with a technical description.
  const WrongRecoveryKeyException([
    super.message = 'Invalid recovery key or checksum mismatch',
  ]);
}

/// Thrown when encrypted data fails authentication (GCM tag or hash mismatch).
class TamperedDataException extends CryptoException {
  /// Creates a [TamperedDataException] for an optional [key].
  const TamperedDataException({
    this.key,
    String message = 'Ciphertext authentication failed or data corrupted',
  }) : super(message);

  /// Key of the remote object that failed verification, if known.
  final String? key;

  @override
  String toString() => key == null
      ? 'TamperedDataException: $message'
      : 'TamperedDataException: $message ($key)';
}

/// Thrown when encrypted object envelope uses an unknown magic, version, or purpose.
class UnsupportedEnvelopeException extends CryptoException {
  /// Creates an [UnsupportedEnvelopeException] with a technical description.
  const UnsupportedEnvelopeException([
    super.message = 'Unsupported envelope format or version',
  ]);
}

/// Thrown when master key is absent from secure storage.
class KeyNotAvailableException extends CryptoException {
  /// Creates a [KeyNotAvailableException] with a technical description.
  const KeyNotAvailableException([
    super.message = 'Master key not found in secure storage',
  ]);
}
