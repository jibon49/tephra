// © 2026 Tephra. All rights reserved.

import 'package:tephra_index/src/extract/word_counter.dart';
import 'package:test/test.dart';

void main() {
  group('word_counter', () {
    test('standard english words and punctuation', () {
      expect(countWords('Hello, world!'), equals(2));
    });

    test('words with apostrophes', () {
      expect(countWords("don't stop"), equals(2));
    });

    test('bangla script words with combining marks', () {
      expect(countWords('আমি বাংলায় গান গাই।'), equals(4));
    });

    test('words after frontmatter offset', () {
      const text = '---\ntitle: x\n---\nOne two';
      final afterFrontmatter = text.indexOf('One');
      expect(countWords(text, afterFrontmatter), equals(2));
    });

    test('empty string returns 0', () {
      expect(countWords(''), equals(0));
    });
  });
}
