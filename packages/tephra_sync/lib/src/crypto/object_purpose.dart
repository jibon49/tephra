// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import '../errors/crypto_exceptions.dart';

/// Cryptographic purpose binding an encrypted object to its usage.
///
/// Encoded into the [TPH1] envelope byte 5 and used as HKDF info to derive
/// dedicated sub-keys per purpose from the vault master key.
enum ObjectPurpose {
  /// File content chunks.
  blob(1, 'tephra/v1/blob'),

  /// Journal batches.
  journal(2, 'tephra/v1/journal'),

  /// Snapshot manifests.
  snapshot(3, 'tephra/v1/snapshot'),

  /// Backup manifests.
  manifest(4, 'tephra/v1/manifest'),

  /// Device info and revocation records.
  device(5, 'tephra/v1/device'),

  /// Distributed GC leases.
  lock(6, 'tephra/v1/lock'),

  /// Distributed GC state.
  gcState(7, 'tephra/v1/gc-state');

  const ObjectPurpose(this.code, this.infoString);

  /// 1-byte numeric code in TPH1 envelope offset 5.
  final int code;

  /// ASCII info string for HKDF-SHA256 derivation.
  final String infoString;

  /// Cached UTF-8 encoded info bytes for HKDF.
  List<int> get infoBytes => utf8.encode(infoString);

  /// Resolves an [ObjectPurpose] from its byte [code].
  ///
  /// Throws [UnsupportedEnvelopeException] if [code] is not recognized.
  static ObjectPurpose fromCode(int code) {
    for (final p in ObjectPurpose.values) {
      if (p.code == code) return p;
    }
    throw UnsupportedEnvelopeException('Unknown object purpose code: $code');
  }
}
