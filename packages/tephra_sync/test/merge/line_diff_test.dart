// © 2026 Tephra. All rights reserved.

import 'package:tephra_sync/tephra_sync.dart';
import 'package:test/test.dart';

void main() {
  group('lineHunks', () {
    test('pure insertion produces hunk with baseStart == baseEnd', () {
      final base = ['a\n', 'c\n'];
      final other = ['a\n', 'b\n', 'c\n'];

      final hunks = lineHunks(base, other);
      expect(hunks, isNotNull);
      expect(hunks!.length, equals(1));

      final h = hunks.first;
      expect(h.baseStart, equals(1));
      expect(h.baseEnd, equals(1));
      expect(h.lines, equals(['b\n']));
    });

    test('pure deletion produces hunk with empty replacement lines', () {
      final base = ['a\n', 'b\n', 'c\n'];
      final other = ['a\n', 'c\n'];

      final hunks = lineHunks(base, other);
      expect(hunks, isNotNull);
      expect(hunks!.length, equals(1));

      final h = hunks.first;
      expect(h.baseStart, equals(1));
      expect(h.baseEnd, equals(2));
      expect(h.lines, isEmpty);
    });

    test('adjacent delete and insert are grouped into one hunk', () {
      final base = ['a\n', 'old\n', 'c\n'];
      final other = ['a\n', 'new1\n', 'new2\n', 'c\n'];

      final hunks = lineHunks(base, other);
      expect(hunks, isNotNull);
      expect(hunks!.length, equals(1));

      final h = hunks.first;
      expect(h.baseStart, equals(1));
      expect(h.baseEnd, equals(2));
      expect(h.lines, equals(['new1\n', 'new2\n']));
    });

    test('multiple disjoint edits yield multiple hunks', () {
      final base = ['l0\n', 'l1\n', 'l2\n', 'l3\n', 'l4\n'];
      final other = ['L0\n', 'l1\n', 'l2\n', 'L3\n', 'L4\n'];

      final hunks = lineHunks(base, other);
      expect(hunks, isNotNull);
      expect(hunks!.length, equals(2));

      expect(hunks[0].baseStart, equals(0));
      expect(hunks[0].baseEnd, equals(1));
      expect(hunks[0].lines, equals(['L0\n']));

      expect(hunks[1].baseStart, equals(3));
      expect(hunks[1].baseEnd, equals(5));
      expect(hunks[1].lines, equals(['L3\n', 'L4\n']));
    });
  });
}
