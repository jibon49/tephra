// © 2026 Tephra. All rights reserved.

/// Represents the last synced base state of a vault file on this device.
final class BaseState {
  /// Creates a [BaseState].
  const BaseState({
    required this.path,
    required this.caseKey,
    required this.hash,
    required this.size,
    required this.mtime,
    required this.version,
    required this.blobKeys,
    required this.syncedAt,
  });

  /// Vault-relative path.
  final String path;

  /// Lower-case path for case-insensitive lookup.
  final String caseKey;

  /// SHA-256 hash of the content.
  final String hash;

  /// File size in bytes.
  final int size;

  /// Modification time in milliseconds UTC.
  final int mtime;

  /// Remote entry id (`<deviceId>:<seq>`) this device last synced.
  final String version;

  /// List of remote blob keys composing this file's ciphertext.
  final List<String> blobKeys;

  /// Sync timestamp in milliseconds UTC.
  final int syncedAt;

  /// Returns a copy of this [BaseState] with updated fields.
  BaseState copyWith({
    String? path,
    String? caseKey,
    String? hash,
    int? size,
    int? mtime,
    String? version,
    List<String>? blobKeys,
    int? syncedAt,
  }) {
    return BaseState(
      path: path ?? this.path,
      caseKey: caseKey ?? this.caseKey,
      hash: hash ?? this.hash,
      size: size ?? this.size,
      mtime: mtime ?? this.mtime,
      version: version ?? this.version,
      blobKeys: blobKeys ?? this.blobKeys,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BaseState &&
          runtimeType == other.runtimeType &&
          path == other.path &&
          caseKey == other.caseKey &&
          hash == other.hash &&
          size == other.size &&
          mtime == other.mtime &&
          version == other.version &&
          syncedAt == other.syncedAt &&
          _listEquals(blobKeys, other.blobKeys);

  @override
  int get hashCode => Object.hash(
    path,
    caseKey,
    hash,
    size,
    mtime,
    version,
    syncedAt,
    Object.hashAll(blobKeys),
  );

  @override
  String toString() =>
      'BaseState(path: $path, hash: $hash, size: $size, version: $version)';

  static bool _listEquals(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
