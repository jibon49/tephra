// © 2026 Tephra. All rights reserved.

/// Mapping from plaintext hash to encrypted remote blob key for deduplication.
final class BlobIndexRecord {
  /// Creates a [BlobIndexRecord].
  const BlobIndexRecord({
    required this.plainHash,
    required this.blobKey,
    required this.size,
    required this.seenAt,
  });

  /// SHA-256 of the unencrypted file bytes.
  final String plainHash;

  /// Remote ciphertext blob key (`blobs/<cipherHash>`).
  final String blobKey;

  /// Blob size in bytes.
  final int size;

  /// Timestamp in milliseconds UTC when blob existence was last verified remotely.
  final int seenAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BlobIndexRecord &&
          runtimeType == other.runtimeType &&
          plainHash == other.plainHash &&
          blobKey == other.blobKey &&
          size == other.size &&
          seenAt == other.seenAt;

  @override
  int get hashCode => Object.hash(plainHash, blobKey, size, seenAt);

  @override
  String toString() =>
      'BlobIndexRecord(plainHash: $plainHash, blobKey: $blobKey, size: $size)';
}
