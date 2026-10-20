// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

/// The kind of informational note emitted during plan generation.
enum PlanNoteKind {
  /// Local file republished because remote history was unknown / deleted.
  republished,

  /// Locally edited file kept instead of being deleted concurrently elsewhere.
  keptEditedFileDeletedElsewhere,

  /// Remote change restored a file that was deleted locally.
  restoredDeletedFileChangedElsewhere,

  /// Remote file renamed to resolve case collision on a case-insensitive system.
  renamedDueToCaseConflict,

  /// Remote file renamed to resolve invalid Windows filename characters/names.
  sanitizedWindowsName,
}

/// An informational note associated with a path during sync planning.
final class PlanNote {
  const PlanNote(this.path, this.kind, {this.detail});

  /// Vault-relative path targeted by this note.
  final VaultPath path;

  /// Category / kind of the plan note.
  final PlanNoteKind kind;

  /// Optional detail string (e.g. target renamed path).
  final String? detail;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlanNote &&
          path == other.path &&
          kind == other.kind &&
          detail == other.detail;

  @override
  int get hashCode => Object.hash(path, kind, detail);

  @override
  String toString() =>
      'PlanNote(${path.value}, kind: $kind${detail == null ? '' : ', detail: $detail'})';
}
