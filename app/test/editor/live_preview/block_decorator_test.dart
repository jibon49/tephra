// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/editor/live_preview/block_decorator.dart';
import 'package:tephra/editor/live_preview/lp_decoration.dart';
import 'package:tephra/editor/live_preview/lp_options.dart';
import 'package:tephra_markdown/tephra_markdown.dart';

void main() {
  group('BlockDecorator exact unit cases', () {
    test('**bold** x', () {
      const text = '**bold** x';
      final parsed = MarkdownParser.parse(text);
      final decs = decorateChunk(text, parsed, 0, const LpOptions());

      expect(
        decs,
        equals(const [
          LpHide(0, 2, reveal: LpReveal(0, 8)),
          LpStyle(2, 6, LpStyleKind.bold),
          LpHide(6, 8, reveal: LpReveal(0, 8)),
        ]),
      );
    });

    test('# T', () {
      const text = '# T';
      final parsed = MarkdownParser.parse(text);
      final decs = decorateChunk(text, parsed, 0, const LpOptions());

      expect(
        decs,
        equals(const [
          LpHide(0, 2, reveal: LpReveal(0, 3)),
          LpStyle(2, 3, LpStyleKind.heading, level: 1),
        ]),
      );
    });

    test('[[N|a]] z', () {
      const text = '[[N|a]] z';
      final parsed = MarkdownParser.parse(text);
      final decs = decorateChunk(text, parsed, 0, const LpOptions());

      expect(
        decs,
        equals(const [
          LpHide(0, 2, reveal: LpReveal(0, 7)),
          LpHide(2, 4, reveal: LpReveal(0, 7)),
          LpStyle(4, 5, LpStyleKind.internalLink, data: 'N'),
          LpHide(5, 7, reveal: LpReveal(0, 7)),
        ]),
      );
    });

    test('[t](u) z', () {
      const text = '[t](u) z';
      final parsed = MarkdownParser.parse(text);
      final decs = decorateChunk(text, parsed, 0, const LpOptions());

      expect(
        decs,
        equals(const [
          LpHide(0, 1, reveal: LpReveal(0, 6)),
          LpStyle(1, 2, LpStyleKind.internalLink, data: 'u'),
          LpHide(2, 6, reveal: LpReveal(0, 6)),
        ]),
      );
    });

    test('- [ ] t', () {
      const text = '- [ ] t';
      final parsed = MarkdownParser.parse(text);
      final decs = decorateChunk(text, parsed, 0, const LpOptions());

      expect(
        decs,
        equals(const [
          LpHide(0, 1, reveal: LpReveal(2, 5)),
          LpWidget(
            2,
            5,
            LpWidgetKind.checkbox,
            data: {'status': ' '},
            reveal: LpReveal(2, 5),
          ),
        ]),
      );
    });

    test('- [x] t', () {
      const text = '- [x] t';
      final parsed = MarkdownParser.parse(text);
      final decs = decorateChunk(text, parsed, 0, const LpOptions());

      expect(
        decs,
        equals(const [
          LpHide(0, 1, reveal: LpReveal(2, 5)),
          LpWidget(
            2,
            5,
            LpWidgetKind.checkbox,
            data: {'status': 'x'},
            reveal: LpReveal(2, 5),
          ),
          LpStyle(6, 7, LpStyleKind.taskDone),
        ]),
      );
    });

    test('- a', () {
      const text = '- a';
      final parsed = MarkdownParser.parse(text);
      final decs = decorateChunk(text, parsed, 0, const LpOptions());

      expect(decs, equals(const [LpReplaceChar(0, 1, '•')]));
    });

    test('> [!note] T\\n> b', () {
      const text = '> [!note] T\n> b';
      final parsed = MarkdownParser.parse(text);
      final decs = decorateChunk(text, parsed, 0, const LpOptions());

      expect(
        decs,
        equals(const [
          LpWidget(
            0,
            11,
            LpWidgetKind.calloutHeader,
            data: {'type': 'note', 'title': 'T', 'fold': 'none'},
            reveal: LpReveal(0, 15),
          ),
          LpStyle(0, 11, LpStyleKind.calloutLine, data: 'note'),
          LpHide(12, 14, reveal: LpReveal(0, 15)),
          LpStyle(12, 15, LpStyleKind.calloutLine, data: 'note'),
        ]),
      );
    });
  });

  group('BlockDecorator no-text-change guarantee', () {
    test('invariants hold for all notes in test_vaults/syntax and edge', () {
      final vaultDirs = [
        Directory('test_vaults/syntax'),
        Directory('../test_vaults/syntax'),
        Directory('test_vaults/edge'),
        Directory('../test_vaults/edge'),
      ];

      var testedCount = 0;
      for (final dir in vaultDirs) {
        if (!dir.existsSync()) continue;
        for (final file in dir.listSync(recursive: true)) {
          if (file is File && file.path.endsWith('.md')) {
            final bytes = file.readAsBytesSync();
            final text = utf8.decode(bytes, allowMalformed: true);
            final parsed = MarkdownParser.parse(text);
            final decs = decorateChunk(text, parsed, 0, const LpOptions());

            final hides = <LpHide>[];
            for (final d in decs) {
              expect(d.start, greaterThanOrEqualTo(0));
              expect(d.end, greaterThanOrEqualTo(d.start));
              expect(d.end, lessThanOrEqualTo(text.length));

              if (d is LpReplaceChar) {
                expect(d.end - d.start, equals(1));
              }

              if (d is LpHide) {
                hides.add(d);
              }
            }

            // Hidden ranges never overlap each other
            hides.sort((a, b) => a.start.compareTo(b.start));
            for (var i = 0; i < hides.length - 1; i++) {
              expect(
                hides[i].end,
                lessThanOrEqualTo(hides[i + 1].start),
                reason:
                    'Overlapping hides in ${file.path}: ${hides[i]} and ${hides[i + 1]}',
              );
            }

            testedCount++;
          }
        }
      }
      expect(testedCount, greaterThanOrEqualTo(20));
    });
  });
}
