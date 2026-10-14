// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/reading/parse_service.dart';
import 'package:tephra_markdown/tephra_markdown.dart';

void main() {
  group('ParseService', () {
    test('a 10-character text returns synchronously correct result', () async {
      const service = ParseService(isolateThreshold: 50000);
      const text = 'Short note';
      final result = await service.parse(text);
      expect(result.text, text);
      expect(result.root.children.first, isA<MdParagraph>());
    });

    test('a 60,000-character text returns the same result as MarkdownParser.parse computed directly', () async {
      const service = ParseService(isolateThreshold: 50000);
      final line =
          'This is a test line with some **bold** and *italic* content.\n';
      final repetitions = (60000 / line.length).ceil() + 10;
      final longText = line * repetitions;
      expect(longText.length, greaterThan(60000));

      final expected = MarkdownParser.parse(longText);
      final result = await service.parse(longText);

      expect(result.text, expected.text);
      expect(result.headings.length, expected.headings.length);
      expect(result.lines.lineCount, expected.lines.lineCount);
      expect(result.root.children.length, expected.root.children.length);
    });

    test(
      'isolateThreshold: 5 forces the isolate path for a small text',
      () async {
        const service = ParseService(isolateThreshold: 5);
        const text = 'Hello world!';
        final result = await service.parse(text);
        expect(result.text, text);
        expect(result.root.children.first, isA<MdParagraph>());
      },
    );
  });
}
