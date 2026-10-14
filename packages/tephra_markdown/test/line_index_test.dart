// © 2026 Tephra. All rights reserved.

import 'package:tephra_markdown/tephra_markdown.dart';
import 'package:test/test.dart';

void main() {
  group('LineIndex', () {
    test("'' -> 1 line", () {
      final index = LineIndex('');
      expect(index.lineCount, equals(1));
      expect(index.lineStart(0), equals(0));
      expect(index.lineEnd(0), equals(0));
      expect(index.lineOf(0), equals(0));
      expect(index.lineText('', 0), equals(''));
    });

    test("'a\\n' -> 2 lines and offsets", () {
      const text = 'a\n';
      final index = LineIndex(text);
      expect(index.lineCount, equals(2));
      expect(index.lineStart(1), equals(2));
      expect(index.lineEnd(0), equals(1));
      expect(index.lineEnd(1), equals(2));
      expect(index.lineOf(0), equals(0));
      expect(index.lineOf(1), equals(0)); // \n belongs to line 0
      expect(index.lineOf(2), equals(1));
    });

    test('lineOf(text.length) is the last line', () {
      const text = 'one\ntwo\nthree';
      final index = LineIndex(text);
      expect(index.lineCount, equals(3));
      expect(index.lineOf(text.length), equals(2));
    });

    test('lineOf out-of-bounds throws RangeError', () {
      const text = 'hello';
      final index = LineIndex(text);
      expect(() => index.lineOf(-1), throwsA(isA<RangeError>()));
      expect(() => index.lineOf(text.length + 1), throwsA(isA<RangeError>()));
    });

    test("lineText('ab\\ncd', 1) == 'cd'", () {
      const text = 'ab\ncd';
      final index = LineIndex(text);
      expect(index.lineText(text, 0), equals('ab'));
      expect(index.lineText(text, 1), equals('cd'));
    });

    test('text with emoji keeps UTF-16 offsets', () {
      // 🚀 is U+1F680 (2 UTF-16 code units: 0xD83D 0xDE80)
      const text = '🚀\nhello';
      final index = LineIndex(text);
      expect(index.lineStart(0), equals(0));
      expect(index.lineEnd(0), equals(2)); // before \n at index 2
      expect(index.lineStart(1), equals(3)); // after \n
      expect(index.lineOf(0), equals(0));
      expect(index.lineOf(1), equals(0));
      expect(index.lineOf(2), equals(0)); // \n is on line 0
      expect(index.lineOf(3), equals(1)); // 'h' is on line 1
      expect(index.lineText(text, 0), equals('🚀'));
      expect(index.lineText(text, 1), equals('hello'));
    });

    test('10,000-line text builds in < 20 ms', () {
      final buffer = StringBuffer();
      for (var i = 0; i < 10000; i++) {
        buffer.writeln('Line $i: some content for speed testing');
      }
      final bigText = buffer.toString();

      final sw = Stopwatch()..start();
      final index = LineIndex(bigText);
      sw.stop();

      expect(index.lineCount, equals(10001));
      expect(sw.elapsedMilliseconds, lessThan(20));
    });
  });
}
