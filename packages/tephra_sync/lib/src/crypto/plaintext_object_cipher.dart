// © 2026 Tephra. All rights reserved.

import '../errors/crypto_exceptions.dart';
import 'envelope.dart';
import 'object_cipher.dart';
import 'object_purpose.dart';

/// [ObjectCipher] for unencrypted remote vaults.
///
/// `seal` passes bytes through unmodified.
/// `open` rejects data that begins with the `TPH1` magic header (preventing accidental
/// mixed-mode data corruption), otherwise returns bytes unmodified.
final class PlaintextObjectCipher implements ObjectCipher {
  /// Creates a [PlaintextObjectCipher].
  const PlaintextObjectCipher();

  @override
  bool get encrypts => false;

  @override
  Future<List<int>> seal(List<int> plaintext, ObjectPurpose purpose) async {
    return plaintext;
  }

  @override
  Future<List<int>> open(List<int> stored, ObjectPurpose purpose) async {
    if (stored.length >= 4 &&
        stored[0] == Tph1Envelope.magic[0] &&
        stored[1] == Tph1Envelope.magic[1] &&
        stored[2] == Tph1Envelope.magic[2] &&
        stored[3] == Tph1Envelope.magic[3]) {
      throw const UnsupportedEnvelopeException(
        'Encountered encrypted TPH1 envelope in unencrypted plaintext vault',
      );
    }
    return stored;
  }
}
