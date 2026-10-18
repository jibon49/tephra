// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/reading/embeds/embed_slice.dart';
import 'package:tephra_markdown/tephra_markdown.dart';

void main() {
  group('embed_slice', () {
    const text = '---\na: 1\n---\nIntro\n# H\nx ^b1\n## Sub\ny\n# Next\nz';
    final parsed = MarkdownParser.parse(text);

    test('whole note without heading or blockRef slices after frontmatter', () {
      final slice = sliceForEmbed(text, parsed);
      expect(slice, isNotNull);
      expect(
        slice!.substringOf(text),
        equals('Intro\n# H\nx ^b1\n## Sub\ny\n# Next\nz'),
      );
    });

    test('heading H slices section including sub-heading up to next same/higher heading', () {
      final slice = sliceForEmbed(text, parsed, heading: 'H');
      expect(slice, isNotNull);
      expect(slice!.substringOf(text), equals('# H\nx ^b1\n## Sub\ny\n'));
    });

    test('heading chain h#sub slices sub-section', () {
      final slice = sliceForEmbed(text, parsed, heading: 'h#sub');
      expect(slice, isNotNull);
      expect(slice!.substringOf(text), equals('## Sub\ny\n'));
    });

    test('block B1 slices paragraph containing ^b1', () {
      final slice = sliceForEmbed(text, parsed, blockRef: 'B1');
      expect(slice, isNotNull);
      expect(slice!.substringOf(text), equals('x ^b1'));
    });

    test('nonexistent heading returns null', () {
      final slice = sliceForEmbed(text, parsed, heading: 'Missing');
      expect(slice, isNull);
    });

    test('nonexistent blockRef returns null', () {
      final slice = sliceForEmbed(text, parsed, blockRef: 'missing-id');
      expect(slice, isNull);
    });

    test('list item block embed includes nested children', () {
      const listDoc = '- Item 1 ^item1\n  - Nested 1\n  - Nested 2\n- Item 2';
      final listParsed = MarkdownParser.parse(listDoc);
      final slice = sliceForEmbed(listDoc, listParsed, blockRef: 'item1');
      expect(slice, isNotNull);
      expect(
        slice!.substringOf(listDoc),
        equals('- Item 1 ^item1\n  - Nested 1\n  - Nested 2'),
      );
    });
  });
}
