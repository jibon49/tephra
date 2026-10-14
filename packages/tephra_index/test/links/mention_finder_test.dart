// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/src/links/mention_finder.dart';
import 'package:test/test.dart';

void main() {
  group('mention_finder_test', () {
    final path = VaultPath('Doc.md');
    final terms = ['Alpha', 'Project Alpha'];

    test('Alpha is here -> 1 at 0', () {
      final m = findMentions(path, 'Alpha is here', terms);
      expect(m.length, equals(1));
      expect(m.first.start, equals(0));
      expect(m.first.end, equals(5));
      expect(m.first.matchedText, equals('Alpha'));
    });

    test('alphabet -> 0', () {
      final m = findMentions(path, 'alphabet', terms);
      expect(m, isEmpty);
    });

    test('the ALPHA. -> 1 (matchedText ALPHA)', () {
      final m = findMentions(path, 'the ALPHA.', terms);
      expect(m.length, equals(1));
      expect(m.first.matchedText, equals('ALPHA'));
      expect(m.first.start, equals(4));
      expect(m.first.end, equals(9));
    });

    test('[[Alpha]] and Alpha -> 1 (the second)', () {
      final m = findMentions(path, '[[Alpha]] and Alpha', terms);
      expect(m.length, equals(1));
      expect(m.first.start, equals(14));
      expect(m.first.end, equals(19));
      expect(m.first.matchedText, equals('Alpha'));
    });

    test('`Alpha` -> 0', () {
      final m = findMentions(path, '`Alpha`', terms);
      expect(m, isEmpty);
    });

    test('#Alpha -> 0 (tag)', () {
      final m = findMentions(path, '#Alpha', terms);
      expect(m, isEmpty);
    });

    test('---\\ntitle: Alpha\\n---\\nAlpha -> 1 (body only)', () {
      final m = findMentions(path, '---\ntitle: Alpha\n---\nAlpha', terms);
      expect(m.length, equals(1));
      expect(m.first.matchedText, equals('Alpha'));
      expect(m.first.line, equals(3));
    });

    test('Project Alpha rocks -> 1 with matchedText Project Alpha', () {
      final m = findMentions(path, 'Project Alpha rocks', terms);
      expect(m.length, equals(1));
      expect(m.first.matchedText, equals('Project Alpha'));
      expect(m.first.start, equals(0));
      expect(m.first.end, equals(13));
    });

    test('%%Alpha%% -> 0', () {
      final m = findMentions(path, '%%Alpha%%', terms);
      expect(m, isEmpty);
    });

    test("Bangla term 'বাংলা' in 'আমি বাংলা জানি' -> 1, in 'বাংলায়' -> 0", () {
      final banglaTerms = ['বাংলা'];
      final m1 = findMentions(path, 'আমি বাংলা জানি', banglaTerms);
      expect(m1.length, equals(1));
      expect(m1.first.matchedText, equals('বাংলা'));

      final m2 = findMentions(path, 'বাংলায়', banglaTerms);
      expect(m2, isEmpty);
    });
  });
}
