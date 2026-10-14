// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

final class VaultEntry {
  const VaultEntry({
    required this.path,
    required this.isFolder,
    required this.size,
    required this.modified,
    this.created,
  });

  final VaultPath path;
  final bool isFolder;
  final int size;
  final DateTime modified;
  final DateTime? created;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VaultEntry &&
          other.path == path &&
          other.isFolder == isFolder &&
          other.size == size &&
          other.modified == modified &&
          other.created == created);

  @override
  int get hashCode => Object.hash(path, isFolder, size, modified, created);

  @override
  String toString() =>
      'VaultEntry(path: $path, isFolder: $isFolder, size: $size, modified: $modified, created: $created)';
}
