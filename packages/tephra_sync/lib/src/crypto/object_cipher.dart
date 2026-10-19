// © 2026 Tephra. All rights reserved.

import 'object_purpose.dart';

/// Common cryptographic interface for sealing and opening remote storage objects.
abstract interface class ObjectCipher {
  /// Encrypts/seals [plaintext] for remote storage under given [purpose].
  Future<List<int>> seal(List<int> plaintext, ObjectPurpose purpose);

  /// Decrypts/opens [stored] object verified against [purpose].
  Future<List<int>> open(List<int> stored, ObjectPurpose purpose);

  /// Whether this cipher performs cryptographic encryption.
  bool get encrypts;
}
