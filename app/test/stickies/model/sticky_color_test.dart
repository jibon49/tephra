// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/stickies/model/sticky_color.dart';

void main() {
  group('StickyColor', () {
    test('parses names case-insensitively', () {
      final color = StickyColor.parse('Pink');
      expect(color, equals(NamedStickyColor.pink));
      expect(color.yamlValue, equals('pink'));
      expect(color.argb, equals(0xFFFFC7DD));

      expect(StickyColor.parse('  YELLOW  '), equals(NamedStickyColor.yellow));
      expect(StickyColor.parse('blue'), equals(NamedStickyColor.blue));
      expect(StickyColor.parse('Green'), equals(NamedStickyColor.green));
      expect(StickyColor.parse('PURPLE'), equals(NamedStickyColor.purple));
      expect(StickyColor.parse('gray'), equals(NamedStickyColor.gray));
    });

    test('expands #abc', () {
      final color = StickyColor.parse('#abc');
      expect(color, isA<HexStickyColor>());
      expect(color.yamlValue, equals('#AABBCC'));
      expect(color.argb, equals(0xFFAABBCC));

      final upper = StickyColor.parse('#123');
      expect(upper.yamlValue, equals('#112233'));

      final full = StickyColor.parse('#FFAA00');
      expect(full.yamlValue, equals('#FFAA00'));
    });

    test('invalid falls back', () {
      expect(StickyColor.parse('teal'), equals(StickyColor.fallback));
      expect(StickyColor.parse(42), equals(StickyColor.fallback));
      expect(StickyColor.parse(null), equals(StickyColor.fallback));
      expect(StickyColor.parse(''), equals(StickyColor.fallback));
      expect(StickyColor.parse('#12'), equals(StickyColor.fallback));
      expect(StickyColor.parse('#12345'), equals(StickyColor.fallback));
      expect(StickyColor.parse('#GGGGGG'), equals(StickyColor.fallback));
    });

    test('text colour contrast', () {
      // Light background -> dark text
      expect(NamedStickyColor.yellow.textArgb, equals(0xFF1F1F1F));
      expect(NamedStickyColor.pink.textArgb, equals(0xFF1F1F1F));
      expect(NamedStickyColor.blue.textArgb, equals(0xFF1F1F1F));

      // Dark background -> white text
      final navy = StickyColor.parse('#000080');
      expect(navy.textArgb, equals(0xFFFFFFFF));

      final black = StickyColor.parse('#000000');
      expect(black.textArgb, equals(0xFFFFFFFF));
    });
  });
}
