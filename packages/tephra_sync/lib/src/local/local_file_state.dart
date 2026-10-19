// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

/// Represents the scanned state of a single local file in the vault.
final class LocalFileState {
  /// Creates a [LocalFileState] record.
  const LocalFileState({
    required this.path,
    required this.hash,
    required this.size,
    required this.mtimeMs,
  });

  /// Vault-relative path of the file.
  final VaultPath path;

  /// Content SHA-256 hash (hex-encoded).
  final String hash;

  /// File size in bytes.
  final int size;

  /// Modification timestamp in UTC epoch milliseconds.
  final int mtimeMs;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalFileState &&
          path == other.path &&
          hash == other.hash &&
          size == other.size &&
          mtimeMs == other.mtimeMs;

  @override
  int get hashCode => Object.hash(path, hash, size, mtimeMs);

  @override
  String toString() =>
      'LocalFileState(path: ${path.value}, hash: $hash, size: $size, mtime: $mtimeMs)';
}
