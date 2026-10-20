// © 2026 Tephra. All rights reserved.

/// User decision for resolving a held delete action triggered by the delete guard.
enum DeleteDecision {
  /// Approve deletion: proceed with DeleteLocal or DeleteRemote.
  approve,

  /// Keep file: restore file by downloading or uploading.
  keep,
}
