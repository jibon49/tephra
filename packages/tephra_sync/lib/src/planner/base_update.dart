// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

import '../model/journal_entry.dart';

bool _listEquals(List<String> a, List<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Abstract base class for bookkeeping updates to the synced base state table.
sealed class BaseUpdate {
  const BaseUpdate(this.path);

  /// Updates or inserts the base state for [path].
  const factory BaseUpdate.set(
    VaultPath path,
    String hash,
    String version,
    List<String> blobKeys,
    int size,
    int mtime,
  ) = BaseUpdateSet;

  /// Helper factory to construct a [BaseUpdateSet] from a [JournalEntry].
  factory BaseUpdate.fromEntry(
    VaultPath path,
    JournalEntry entry, {
    int? size,
    int? mtime,
  }) => BaseUpdateSet(
    path,
    entry.hash ?? '',
    entry.entryId,
    entry.blobKeys ?? const [],
    size ?? entry.size ?? 0,
    mtime ?? entry.mtime ?? 0,
  );

  /// Removes the base state for [path].
  const factory BaseUpdate.remove(VaultPath path) = BaseUpdateRemove;

  /// Vault-relative path targeted by this base update.
  final VaultPath path;
}

/// Inserts or replaces a base entry in `synced_files`.
final class BaseUpdateSet extends BaseUpdate {
  const BaseUpdateSet(
    super.path,
    this.hash,
    this.version,
    this.blobKeys,
    this.size,
    this.mtime,
  );

  final String hash;
  final String version;
  final List<String> blobKeys;
  final int size;
  final int mtime;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BaseUpdateSet &&
          path == other.path &&
          hash == other.hash &&
          version == other.version &&
          _listEquals(blobKeys, other.blobKeys) &&
          size == other.size &&
          mtime == other.mtime;

  @override
  int get hashCode =>
      Object.hash(path, hash, version, Object.hashAll(blobKeys), size, mtime);

  @override
  String toString() =>
      'BaseUpdate.set(${path.value}, hash: $hash, ver: $version)';
}

/// Deletes a base entry from `synced_files`.
final class BaseUpdateRemove extends BaseUpdate {
  const BaseUpdateRemove(super.path);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is BaseUpdateRemove && path == other.path;

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() => 'BaseUpdate.remove(${path.value})';
}
