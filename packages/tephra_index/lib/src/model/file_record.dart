// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

/// Record of any file in the vault (note or attachment).
final class FileRecord {
  const FileRecord({
    required this.path,
    required this.size,
    required this.modified,
    this.created,
    required this.isNote,
  });

  final VaultPath path;
  final int size;
  final DateTime modified;
  final DateTime? created;
  final bool isNote;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileRecord &&
          path == other.path &&
          size == other.size &&
          modified == other.modified &&
          created == other.created &&
          isNote == other.isNote;

  @override
  int get hashCode => Object.hash(path, size, modified, created, isNote);

  @override
  String toString() =>
      'FileRecord(path: ${path.value}, size: $size, isNote: $isNote)';
}
