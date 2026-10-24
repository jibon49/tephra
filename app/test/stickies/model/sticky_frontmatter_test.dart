// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/stickies/model/sticky_color.dart';
import 'package:tephra/stickies/model/sticky_frontmatter.dart';
import 'package:tephra/stickies/model/sticky_meta.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_markdown/tephra_markdown.dart';
import 'package:tephra_vault/tephra_vault.dart';

void main() {
  group('applyStickyPatch', () {
    test('adds frontmatter to a plain note', () {
      const input = 'Call the printer guy\n- [ ] toner\n';
      final result = applyStickyPatch(
        input,
        const StickyPatch(sticky: true, color: NamedStickyColor.yellow),
      );
      const expected =
          '---\ntephra-sticky: true\nsticky-color: yellow\n---\nCall the printer guy\n- [ ] toner\n';
      expect(result, equals(expected));
    });

    test('pin then unpin restores plain note exactly', () {
      const input = 'Call the printer guy\n- [ ] toner\n';
      final pinned = applyStickyPatch(
        input,
        const StickyPatch(sticky: true, color: NamedStickyColor.yellow),
      );
      final unpinned = applyStickyPatch(
        pinned,
        const StickyPatch(removeAll: true),
      );
      expect(unpinned, equals(input));
    });

    test('existing frontmatter keeps formatting', () {
      const input =
          '---\ntitle:   "My  note"   # keep\ntags: [a, b]\n---\nBody **x**\n';
      final patched = applyStickyPatch(
        input,
        const StickyPatch(sticky: true, color: NamedStickyColor.pink),
      );

      // title and tags preserved byte-for-byte
      expect(patched, contains('title:   "My  note"   # keep\n'));
      expect(patched, contains('tags: [a, b]\n'));
      expect(patched, contains('tephra-sticky: true\n'));
      expect(patched, contains('sticky-color: pink\n'));
      expect(patched.endsWith('---\nBody **x**\n'), isTrue);

      final unpatched = applyStickyPatch(
        patched,
        const StickyPatch(removeAll: true),
      );
      expect(unpatched, equals(input));
    });

    test('hex colour is quoted', () {
      const input = 'Note body\n';
      final patched = applyStickyPatch(
        input,
        StickyColor.parse('#ffaa00') is HexStickyColor
            ? StickyPatch(sticky: true, color: StickyColor.parse('#ffaa00'))
            : const StickyPatch(),
      );
      expect(
        patched.contains("sticky-color: '#FFAA00'") ||
            patched.contains('sticky-color: "#FFAA00"'),
        isTrue,
      );

      final parsed = MarkdownParser.parse(patched);
      final meta = StickyMeta.fromFrontmatter(parsed.frontmatter);
      expect(meta.color, equals(StickyColor.parse('#FFAA00')));
    });

    test('remind set and cleared', () {
      const input = 'Note body\n';
      final setRemind = applyStickyPatch(
        input,
        const StickyPatch(
          sticky: true,
          remind: Optional.of(LocalDateTime(2026, 10, 12, 9, 0)),
        ),
      );
      expect(setRemind, contains('sticky-remind: 2026-10-12T09:00\n'));

      final clearedRemind = applyStickyPatch(
        setRemind,
        const StickyPatch(remind: Optional.none()),
      );
      expect(clearedRemind.contains('sticky-remind'), isFalse);
      expect(clearedRemind, contains('tephra-sticky: true\n'));
      expect(clearedRemind.endsWith('---\nNote body\n'), isTrue);
    });

    test('pinned false removes the key', () {
      const input =
          '---\ntephra-sticky: true\nsticky-pinned: true\n---\nBody\n';
      final result = applyStickyPatch(input, const StickyPatch(pinned: false));
      expect(result.contains('sticky-pinned'), isFalse);
      expect(result, contains('tephra-sticky: true\n'));
    });

    test('no-op patch returns identical string', () {
      const input = '---\ntephra-sticky: true\n---\nBody\n';
      final result = applyStickyPatch(input, const StickyPatch(sticky: true));
      expect(identical(result, input), isTrue);

      const plain = 'Plain note without frontmatter';
      final noopPlain = applyStickyPatch(plain, const StickyPatch());
      expect(identical(noopPlain, plain), isTrue);
    });

    test('CRLF + BOM file round trip', () {
      final bom = [0xEF, 0xBB, 0xBF];
      final content = utf8.encode('line 1\r\nline 2\r\n');
      final inputBytes = [...bom, ...content];

      final doc = TextDocument.decode(inputBytes);
      expect(doc.hasBom, isTrue);
      expect(doc.lineEnding, equals(LineEnding.crlf));

      final patchedText = applyStickyPatch(
        doc.text,
        const StickyPatch(sticky: true, color: NamedStickyColor.yellow),
      );
      final unpatchedText = applyStickyPatch(
        patchedText,
        const StickyPatch(removeAll: true),
      );

      final outputBytes = doc.copyWith(text: unpatchedText).encode();
      expect(outputBytes, equals(inputBytes));
    });

    test('body bytes untouched (property-style)', () {
      final rng = Random(4);
      final testBodies = <String>[];

      for (var i = 0; i < 50; i++) {
        final lines = <String>[];
        final lineCount = rng.nextInt(5);
        for (var j = 0; j < lineCount; j++) {
          final choice = rng.nextInt(4);
          switch (choice) {
            case 0:
              lines.add('Unicode text: বাংলা বাংলা 🚀');
            case 1:
              lines.add('---'); // looks like frontmatter delimiter inside body
            case 2:
              lines.add('```dart\nvoid main() {}\n```');
            default:
              lines.add('Normal line $j: ${rng.nextInt(1000)}');
          }
        }
        testBodies.add(lines.join('\n'));
      }

      for (final originalBody in testBodies) {
        final originalNote = '---\ntitle: test\n---\n$originalBody';
        final patched = applyStickyPatch(
          originalNote,
          const StickyPatch(sticky: true, color: NamedStickyColor.blue),
        );
        final splitPatched = splitFrontmatter(patched);
        expect(splitPatched, isNotNull);
        final newBody = patched.substring(splitPatched!.bodyStart);
        expect(newBody, equals(originalBody));
      }
    });

    test('non-map frontmatter throws ParseException', () {
      const invalidYaml = '---\n- a\n- b\n---\nx';
      expect(
        () => applyStickyPatch(invalidYaml, const StickyPatch(sticky: true)),
        throwsA(isA<ParseException>()),
      );
    });
  });
}
