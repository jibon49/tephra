// © 2026 Tephra. All rights reserved.

import 'dart:math';

import 'package:cryptography/cryptography.dart';

import 'envelope.dart';
import 'object_cipher.dart';
import 'object_purpose.dart';

/// [ObjectCipher] implementing TPH1 AES-256-GCM envelope encryption.
final class EncryptingObjectCipher implements ObjectCipher {
  /// Creates an [EncryptingObjectCipher].
  const EncryptingObjectCipher({
    required this.masterKey,
    required this.vaultId,
    this.random,
  });

  /// Master key used for envelope key derivations.
  final SecretKey masterKey;

  /// Remote vault ID binding all envelope operations.
  final String vaultId;

  /// Optional PRNG for salt and nonce generation.
  final Random? random;

  @override
  bool get encrypts => true;

  @override
  Future<List<int>> seal(List<int> plaintext, ObjectPurpose purpose) {
    return Tph1Envelope.seal(
      plaintext: plaintext,
      purpose: purpose,
      masterKey: masterKey,
      vaultId: vaultId,
      random: random,
    );
  }

  @override
  Future<List<int>> open(List<int> stored, ObjectPurpose purpose) {
    return Tph1Envelope.open(
      stored: stored,
      expectedPurpose: purpose,
      masterKey: masterKey,
      vaultId: vaultId,
    );
  }
}
