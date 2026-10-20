// © 2026 Tephra. All rights reserved.

export 'package:tephra_sync/tephra_sync.dart'
    show
        DiffKind,
        DiffLine,
        SideBySideRow,
        computeLineDiff,
        computeSideBySide,
        lineDiff,
        sideBySide;

/// Display mode for diff visualization.
enum DiffDisplayMode {
  /// Two synchronized columns comparing original (left) and modified (right).
  sideBySide,

  /// Single unified column with inline insertions and deletions.
  inline,
}
