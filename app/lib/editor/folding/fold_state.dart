// © 2026 Tephra. All rights reserved.

import 'package:flutter/foundation.dart';

import 'fold_regions.dart';

/// Immutable state containing the active folded anchors (headerStart offsets).
@immutable
final class FoldState {
  FoldState([Set<int>? anchors])
    : anchors = Set<int>.unmodifiable(anchors ?? const <int>{});

  /// The set of folded anchors, represented as UTF-16 headerStart offsets.
  final Set<int> anchors;

  /// Maps anchors through a text edit:
  /// - anchors before [start] remain unchanged.
  /// - anchors at or after [start] + [deletedLength] shift by `[insertedLength] - [deletedLength]`.
  /// - anchors inside the deleted range are dropped.
  FoldState mapThroughEdit(int start, int deletedLength, int insertedLength) {
    final next = <int>{};
    final delta = insertedLength - deletedLength;
    final deleteEnd = start + deletedLength;

    for (final anchor in anchors) {
      if (anchor < start) {
        next.add(anchor);
      } else if (anchor >= deleteEnd) {
        next.add(anchor + delta);
      }
      // If start <= anchor < deleteEnd, anchor is inside deleted range -> dropped.
    }

    return FoldState(next);
  }

  /// Filters folded anchors against a new list of valid regions.
  ///
  /// An anchor is active iff a region exists with `headerStart == anchor`.
  /// Anchors without a matching region are dropped.
  FoldState pruneDeadAnchors(List<FoldRegion> validRegions) {
    final validStarts = validRegions.map((r) => r.headerStart).toSet();
    final next = anchors.where(validStarts.contains).toSet();
    return FoldState(next);
  }

  /// Toggles the fold state of the region starting at [headerStart].
  FoldState toggle(int headerStart) {
    final next = Set<int>.of(anchors);
    if (next.contains(headerStart)) {
      next.remove(headerStart);
    } else {
      next.add(headerStart);
    }
    return FoldState(next);
  }

  /// Folds all given [regions].
  FoldState foldAll(List<FoldRegion> regions) {
    return FoldState(regions.map((r) => r.headerStart).toSet());
  }

  /// Unfolds all regions.
  FoldState unfoldAll() {
    return FoldState(const <int>{});
  }

  /// Returns true if the region starting at [headerStart] is folded.
  bool isFolded(int headerStart) => anchors.contains(headerStart);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FoldState && setEquals(anchors, other.anchors);

  @override
  int get hashCode => Object.hashAll(anchors.toList()..sort());

  @override
  String toString() => 'FoldState($anchors)';
}
