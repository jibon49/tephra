// © 2026 Tephra. All rights reserved.

/// Reference to a content-addressed remote blob.
final class BlobRef {
  /// Creates a [BlobRef].
  const BlobRef({required this.key, required this.size});

  /// Full remote key (`blobs/<sha256Hex>`).
  final String key;

  /// Size in bytes of the stored blob.
  final int size;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BlobRef &&
          runtimeType == other.runtimeType &&
          key == other.key &&
          size == other.size;

  @override
  int get hashCode => Object.hash(key, size);

  @override
  String toString() => 'BlobRef(key: $key, size: $size)';
}
