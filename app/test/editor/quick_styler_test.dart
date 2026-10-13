// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/editor/highlight/quick_styler.dart';
import 'package:tephra/editor/highlight/span_extractor.dart';
import 'package:tephra/reading/parse_service.dart';

void main() {
  const samples = <String>[
    '# Heading 1',
    '## Heading 2',
    '> A blockquote line',
    '- Bullet item',
    '* Star bullet',
    '1. Numbered item',
    'A `inline code` snippet',
    'Some **bold text** here',
    'Some *italic text* here',
    'A [[Note Target]] link',
    'Check this #tag-name here',
    'Some ==highlighted text== here',
  ];

  test('quick styler yields the same token set as extractSpans for standard single-line samples', () async {
    const parseService = ParseService();

    expect(samples.length, equals(12));

    for (final sample in samples) {
      final parsed = await parseService.parse(sample);
      final astSpans = extractSpans(parsed);
      final astTokens = astSpans.map((s) => s.token).toSet();

      final quickStyles = QuickStyler.style(sample);
      final quickTokens = quickStyles.expand((r) => r.tokens).toSet();

      expect(
        quickTokens,
        equals(astTokens),
        reason: 'Tokens mismatch for sample: "$sample"',
      );
    }
  });
}
