// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/editor/folding/fold_anchors.dart';
import 'package:tephra/editor/folding/fold_regions.dart';

void main() {
  group('FoldState anchor mapping and pruning', () {
    test('insert 3 characters at 2 -> {0, 9}', () {
      final initial = FoldState({0, 6});
      final updated = initial.mapThroughEdit(2, 0, 3);
      expect(updated.anchors, {0, 9});
    });

    test('delete 3 characters at offset 1 (range 1-4, before second anchor) -> {0, 3}', () {
      final initial = FoldState({0, 6});
      final updated = initial.mapThroughEdit(1, 3, 0);
      expect(updated.anchors, {0, 3});
    });

    test('delete range 5-8 (contains anchor 6) -> {0}', () {
      final initial = FoldState({0, 6});
      final updated = initial.mapThroughEdit(5, 3, 0);
      expect(updated.anchors, {0});
    });

    test('anchor without a region after re-compute is dropped', () {
      final state = FoldState({0, 6, 20});
      const validRegions = [
        FoldRegion(
          kind: FoldKind.heading,
          headerStart: 0,
          from: 3,
          to: 10,
          level: 1,
        ),
        FoldRegion(
          kind: FoldKind.heading,
          headerStart: 6,
          from: 10,
          to: 15,
          level: 2,
        ),
      ];

      final pruned = state.pruneDeadAnchors(validRegions);
      expect(pruned.anchors, {0, 6});
      expect(pruned.anchors.contains(20), isFalse);
    });

    test('toggle, foldAll, and unfoldAll operations', () {
      final empty = FoldState();
      expect(empty.anchors, isEmpty);

      final toggled1 = empty.toggle(10);
      expect(toggled1.anchors, {10});

      final toggled2 = toggled1.toggle(20);
      expect(toggled2.anchors, {10, 20});

      final toggledOff = toggled2.toggle(10);
      expect(toggledOff.anchors, {20});

      const regions = [
        FoldRegion(
          kind: FoldKind.heading,
          headerStart: 5,
          from: 10,
          to: 20,
          level: 1,
        ),
        FoldRegion(
          kind: FoldKind.list,
          headerStart: 30,
          from: 35,
          to: 50,
          level: 1,
        ),
      ];

      final foldedAll = empty.foldAll(regions);
      expect(foldedAll.anchors, {5, 30});

      final unfolded = foldedAll.unfoldAll();
      expect(unfolded.anchors, isEmpty);
    });
  });
}
