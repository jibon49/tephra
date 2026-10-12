// © 2026 Tephra. All rights reserved.

import 'package:tephra_markdown/src/util/offset_map.dart';
import 'package:test/test.dart';

void main() {
  group('OffsetMap', () {
    test('two segments of blockquote prefix stripped text', () {
      // Source text:
      // Index: 0 1 2 3 4 5 6 7 8
      // Text:  a b c \n >   d e f
      const source = 'abc\n> def';
      final map = OffsetMap();
      map.addSegment(0, 3); // 'abc'
      map.addSegment(6, 9); // 'def' (indices 6..8 in source)

      expect(map.buildText(source), equals('abc\ndef'));
      expect(map.toSource(0), equals(0));
      expect(
        map.toSource(3),
        equals(3),
      ); // virtual newline maps to previous segment's srcEnd
      expect(map.toSource(4), equals(6));
      expect(map.toSourceEnd(7), equals(9));
      expect(map.toSourceEnd(3), equals(3));
    });

    test('empty map edge cases', () {
      final map = OffsetMap();
      expect(map.buildText(''), equals(''));
      expect(map.toSource(0), equals(0));
      expect(map.toSourceEnd(0), equals(0));
    });
  });
}
