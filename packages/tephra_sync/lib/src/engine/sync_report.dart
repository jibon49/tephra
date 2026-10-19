// © 2026 Tephra. All rights reserved.

/// Final report produced upon completion of a sync cycle.
final class SyncReport {
  const SyncReport({
    this.uploaded = 0,
    this.downloaded = 0,
    this.merged = 0,
    this.conflicts = 0,
    this.deletedLocal = 0,
    this.deletedRemote = 0,
    this.renamed = 0,
    this.heldDeletes = 0,
    this.bytesUp = 0,
    this.bytesDown = 0,
    required this.duration,
    this.errors = const [],
  });

  final int uploaded;
  final int downloaded;
  final int merged;
  final int conflicts;
  final int deletedLocal;
  final int deletedRemote;
  final int renamed;
  final int heldDeletes;
  final int bytesUp;
  final int bytesDown;
  final Duration duration;
  final List<String> errors;

  @override
  String toString() =>
      'SyncReport(up: $uploaded ($bytesUp B), down: $downloaded ($bytesDown B), '
      'merged: $merged, conflicts: $conflicts, delLoc: $deletedLocal, '
      'delRem: $deletedRemote, renamed: $renamed, held: $heldDeletes, '
      'duration: ${duration.inMilliseconds}ms${errors.isNotEmpty ? ', errors: ${errors.length}' : ''})';
}
