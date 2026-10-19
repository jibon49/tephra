// © 2026 Tephra. All rights reserved.

import 'package:tephra_sync/tephra_sync.dart';
import 'package:test/test.dart';

void main() {
  group('splitLines', () {
    test(
      'splits lines while preserving newlines on all except possibly last line',
      () {
        expect(splitLines(''), isEmpty);
        expect(splitLines('single line'), equals(['single line']));
        expect(splitLines('single line\n'), equals(['single line\n']));
        expect(
          splitLines('line 1\nline 2\nline 3'),
          equals(['line 1\n', 'line 2\n', 'line 3']),
        );
        expect(
          splitLines('line 1\nline 2\nline 3\n'),
          equals(['line 1\n', 'line 2\n', 'line 3\n']),
        );
        expect(splitLines('\n'), equals(['\n']));
        expect(splitLines('\n\n'), equals(['\n', '\n']));
      },
    );

    test('rejoining splitLines reproduces original string identically', () {
      final samples = [
        '',
        'hello',
        'hello\n',
        'a\nb\nc',
        'a\nb\nc\n',
        '\n\n\n',
        '# Heading\n\nParagraph text.\n',
      ];
      for (final s in samples) {
        expect(splitLines(s).join(''), equals(s));
      }
    });
  });

  group('LineCodec', () {
    test('encodes and decodes lines losslessly', () {
      final codec = LineCodec();
      final lines = ['alpha\n', 'beta\n', 'alpha\n', 'gamma'];

      final encoded = codec.encode(lines);
      expect(encoded, isNotNull);
      expect(encoded!.length, equals(4));

      // Check duplicate line 'alpha\n' maps to the same character code
      expect(encoded.codeUnitAt(0), equals(encoded.codeUnitAt(2)));
      expect(encoded.codeUnitAt(0), isNot(equals(encoded.codeUnitAt(1))));

      final decoded = codec.decode(encoded);
      expect(decoded, equals(lines));
    });

    test('skips surrogate code points 0xD800 - 0xDFFF', () {
      final codec = LineCodec();
      // Generate enough unique lines to approach and pass 0xD800
      // 0xD800 - 0x0100 = 55,040
      final lines = List.generate(55042, (i) => 'line_$i\n');
      final encoded = codec.encode(lines);
      expect(encoded, isNotNull);
      expect(codec.hasOverflow, isFalse);

      // Verify no code unit in encoded falls into the surrogate range [0xD800, 0xDFFF]
      for (var i = 0; i < encoded!.length; i++) {
        final cu = encoded.codeUnitAt(i);
        expect(
          cu < 0xD800 || cu > 0xDFFF,
          isTrue,
          reason: 'Code unit 0x${cu.toRadixString(16)} must not be a surrogate',
        );
      }
    });

    test('exceeding 60,000 distinct lines triggers overflow', () {
      final codec = LineCodec();
      final lines = List.generate(60001, (i) => 'line_$i\n');
      final encoded = codec.encode(lines);

      expect(encoded, isNull);
      expect(codec.hasOverflow, isTrue);
    });
  });
}
