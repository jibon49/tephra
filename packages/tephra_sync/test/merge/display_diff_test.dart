// © 2026 Tephra. All rights reserved.

import 'package:tephra_sync/tephra_sync.dart';
import 'package:test/test.dart';

void main() {
  group('lineDiff', () {
    test('handles empty inputs', () {
      expect(lineDiff('', ''), isEmpty);

      final added = lineDiff('', 'hello');
      expect(added.length, 1);
      expect(added[0].kind, DiffKind.added);
      expect(added[0].text, 'hello');
      expect(added[0].aLine, isNull);
      expect(added[0].bLine, 1);

      final removed = lineDiff('world', '');
      expect(removed.length, 1);
      expect(removed[0].kind, DiffKind.removed);
      expect(removed[0].text, 'world');
      expect(removed[0].aLine, 1);
      expect(removed[0].bLine, isNull);
    });

    test('unchanged texts produce identical same lines', () {
      const text = 'Line 1\nLine 2\nLine 3\n';
      final diff = lineDiff(text, text);
      expect(diff.length, 3);
      for (var i = 0; i < 3; i++) {
        expect(diff[i].kind, DiffKind.same);
        expect(diff[i].text, 'Line ${i + 1}');
        expect(diff[i].aLine, i + 1);
        expect(diff[i].bLine, i + 1);
      }
    });

    test('insert line in middle', () {
      const a = 'apple\nbanana\ncherry\n';
      const b = 'apple\nbanana\nblueberry\ncherry\n';
      final diff = lineDiff(a, b);
      expect(diff.length, 4);

      expect(diff[0].kind, DiffKind.same);
      expect(diff[0].text, 'apple');
      expect(diff[0].aLine, 1);
      expect(diff[0].bLine, 1);

      expect(diff[1].kind, DiffKind.same);
      expect(diff[1].text, 'banana');
      expect(diff[1].aLine, 2);
      expect(diff[1].bLine, 2);

      expect(diff[2].kind, DiffKind.added);
      expect(diff[2].text, 'blueberry');
      expect(diff[2].aLine, isNull);
      expect(diff[2].bLine, 3);

      expect(diff[3].kind, DiffKind.same);
      expect(diff[3].text, 'cherry');
      expect(diff[3].aLine, 3);
      expect(diff[3].bLine, 4);
    });

    test('delete line in middle', () {
      const a = 'Line 1\nLine to delete\nLine 3\n';
      const b = 'Line 1\nLine 3\n';
      final diff = lineDiff(a, b);
      expect(diff.length, 3);

      expect(diff[0].kind, DiffKind.same);
      expect(diff[0].text, 'Line 1');

      expect(diff[1].kind, DiffKind.removed);
      expect(diff[1].text, 'Line to delete');
      expect(diff[1].aLine, 2);
      expect(diff[1].bLine, isNull);

      expect(diff[2].kind, DiffKind.same);
      expect(diff[2].text, 'Line 3');
      expect(diff[2].aLine, 3);
      expect(diff[2].bLine, 2);
    });

    test('replace line in middle', () {
      const a = 'alpha\nbeta\ngamma\n';
      const b = 'alpha\nBRAVO\ngamma\n';
      final diff = lineDiff(a, b);
      expect(diff.length, 4);

      expect(diff[0].kind, DiffKind.same);
      expect(diff[0].text, 'alpha');

      expect(diff[1].kind, DiffKind.removed);
      expect(diff[1].text, 'beta');
      expect(diff[1].aLine, 2);
      expect(diff[1].bLine, isNull);

      expect(diff[2].kind, DiffKind.added);
      expect(diff[2].text, 'BRAVO');
      expect(diff[2].aLine, isNull);
      expect(diff[2].bLine, 2);

      expect(diff[3].kind, DiffKind.same);
      expect(diff[3].text, 'gamma');
    });
  });

  group('sideBySide', () {
    test('pairs unchanged lines row-by-row', () {
      const text = 'First\nSecond\nThird\n';
      final diff = lineDiff(text, text);
      final rows = sideBySide(diff);

      expect(rows.length, 3);
      for (var i = 0; i < 3; i++) {
        expect(rows[i].left, isNotNull);
        expect(rows[i].right, isNotNull);
        expect(rows[i].left!.kind, DiffKind.same);
        expect(rows[i].right!.kind, DiffKind.same);
        expect(rows[i].left!.text, rows[i].right!.text);
      }
    });

    test('pairs single replacement into one row with left and right', () {
      const a = 'Line 1\nOld Line\nLine 3\n';
      const b = 'Line 1\nNew Line\nLine 3\n';
      final diff = lineDiff(a, b);
      final rows = sideBySide(diff);

      expect(rows.length, 3);
      expect(rows[0].left?.text, 'Line 1');
      expect(rows[0].right?.text, 'Line 1');

      expect(rows[1].left?.kind, DiffKind.removed);
      expect(rows[1].left?.text, 'Old Line');
      expect(rows[1].right?.kind, DiffKind.added);
      expect(rows[1].right?.text, 'New Line');

      expect(rows[2].left?.text, 'Line 3');
      expect(rows[2].right?.text, 'Line 3');
    });

    test('handles unbalanced replacement run (2 removed, 3 added)', () {
      const a = 'A\nRem1\nRem2\nZ\n';
      const b = 'A\nAdd1\nAdd2\nAdd3\nZ\n';
      final diff = lineDiff(a, b);
      final rows = sideBySide(diff);

      expect(rows.length, 5); // A, pair1, pair2, pair3(left null), Z
      expect(rows[0].left?.text, 'A');
      expect(rows[0].right?.text, 'A');

      expect(rows[1].left?.text, 'Rem1');
      expect(rows[1].right?.text, 'Add1');

      expect(rows[2].left?.text, 'Rem2');
      expect(rows[2].right?.text, 'Add2');

      expect(rows[3].left, isNull);
      expect(rows[3].right?.text, 'Add3');

      expect(rows[4].left?.text, 'Z');
      expect(rows[4].right?.text, 'Z');
    });

    test('handles pure insertion (left is null)', () {
      const a = 'A\nB\n';
      const b = 'A\nInserted\nB\n';
      final rows = sideBySide(lineDiff(a, b));

      expect(rows.length, 3);
      expect(rows[1].left, isNull);
      expect(rows[1].right?.kind, DiffKind.added);
      expect(rows[1].right?.text, 'Inserted');
    });

    test('handles pure deletion (right is null)', () {
      const a = 'A\nDeleted\nB\n';
      const b = 'A\nB\n';
      final rows = sideBySide(lineDiff(a, b));

      expect(rows.length, 3);
      expect(rows[1].left?.kind, DiffKind.removed);
      expect(rows[1].left?.text, 'Deleted');
      expect(rows[1].right, isNull);
    });
  });

  group('async compute diffs (>2,000 lines)', () {
    test('computes diff for large text across isolate', () async {
      final aBuilder = StringBuffer();
      final bBuilder = StringBuffer();

      for (var i = 1; i <= 2100; i++) {
        aBuilder.writeln('Common line $i');
        if (i == 1050) {
          bBuilder.writeln('Modified line 1050');
        } else {
          bBuilder.writeln('Common line $i');
        }
      }

      final diff = await computeLineDiff(
        aBuilder.toString(),
        bBuilder.toString(),
      );
      expect(diff.length, 2101); // 1 removed + 1 added for line 1050

      final sbs = await computeSideBySide(
        aBuilder.toString(),
        bBuilder.toString(),
      );
      expect(sbs.length, 2100);
      expect(sbs[1049].left?.text, 'Common line 1050');
      expect(sbs[1049].right?.text, 'Modified line 1050');
    });
  });
}
