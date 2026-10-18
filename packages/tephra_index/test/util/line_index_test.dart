// © 2026 Tephra. All rights reserved.

import 'package:tephra_markdown/tephra_markdown.dart';
import 'package:test/test.dart';

void main() {
  group('LineIndex', () {
    test('empty string has 1 line and lineOf(0) == 0', () {
      final index = LineIndex('');
      expect(index.lineCount, equals(1));
      expect(index.lineOf(0), equals(0));
      expect(index.lineStart(0), equals(0));
      expect(index.lineEnd(0), equals(0));
      expect(index.lineText('', 0), equals(''));
    });

    test('multiline text line offsets and text slices', () {
      const text = 'a\nb\n';
      final index = LineIndex(text);
      expect(index.lineCount, equals(3));
      expect(index.lineOf(0), equals(0));
      expect(index.lineOf(1), equals(0));
      expect(index.lineOf(2), equals(1));
      expect(index.lineOf(4), equals(2));

      expect(index.lineStart(1), equals(2));
      expect(index.lineEnd(1), equals(3));
      expect(index.lineText(text, 1), equals('b'));

      expect(() => index.lineOf(-1), throwsA(isA<RangeError>()));
      expect(() => index.lineOf(text.length + 1), throwsA(isA<RangeError>()));
    });

    test('100,000-line text performance and last offset lookup', () {
      final sw = Stopwatch()..start();
      final text = List.filled(100000, 'short line').join('\n');
      final index = LineIndex(text);
      expect(index.lineCount, equals(100000));
      expect(index.lineOf(text.length), equals(99999));
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(1500));
    });
  });
}
