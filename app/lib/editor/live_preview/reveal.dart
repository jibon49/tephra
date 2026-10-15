// © 2026 Tephra. All rights reserved.

import 'dart:math' as math;

import 'lp_decoration.dart';

/// Text selection / caret range.
final class TextRange {
  const TextRange({required this.start, required this.end});
  const TextRange.collapsed(int offset) : start = offset, end = offset;
  const TextRange.range(this.start, this.end);

  final int start;
  final int end;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TextRange && start == other.start && end == other.end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'TextRange($start..$end)';
}

/// A decoration is shown as source when the caret or any part of the selection
/// touches its reveal range (touching = inclusive at both ends).
bool isRevealed(LpDecoration d, TextRange active) {
  if (d.reveal == null) return false;
  final s = math.min(active.start, active.end);
  final e = math.max(active.start, active.end);
  return s <= d.reveal!.end && e >= d.reveal!.start;
}
