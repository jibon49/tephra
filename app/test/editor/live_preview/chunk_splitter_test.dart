// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/editor/live_preview/chunk_splitter.dart';

void main() {
  group('ChunkSplitter unit cases', () {
    test('a\\n\\nb -> 2 chunks [0,3), [3,4)', () {
      final chunks = splitChunks('a\n\nb');
      expect(chunks, equals(const [ChunkSpan(0, 3), ChunkSpan(3, 4)]));
    });

    test('a\\n\\n\\nb -> [0,4), [4,5)', () {
      final chunks = splitChunks('a\n\n\nb');
      expect(chunks, equals(const [ChunkSpan(0, 4), ChunkSpan(4, 5)]));
    });

    test('fenced code block with blank line inside stays one chunk', () {
      const text = '```dart\nvar a = 1;\n\nvar b = 2;\n```';
      final chunks = splitChunks(text);
      expect(chunks, equals([ChunkSpan(0, text.length)]));
    });

    test(r'$$\nx\n\ny\n$$ one chunk', () {
      const text = '\$\$\nx\n\ny\n\$\$';
      final chunks = splitChunks(text);
      expect(chunks, equals([ChunkSpan(0, text.length)]));
    });

    test('- a\\n\\n- b one chunk', () {
      const text = '- a\n\n- b';
      final chunks = splitChunks(text);
      expect(chunks, equals([ChunkSpan(0, text.length)]));
    });

    test('- a\\n\\nText two chunks', () {
      const text = '- a\n\nText';
      final chunks = splitChunks(text);
      expect(chunks, equals(const [ChunkSpan(0, 5), ChunkSpan(5, 9)]));
    });

    test('Para\\n\\n    code one chunk (indent continuation)', () {
      const text = 'Para\n\n    code';
      final chunks = splitChunks(text);
      expect(chunks, equals([ChunkSpan(0, text.length)]));
    });

    test(
      'frontmatter with a blank line inside stays attached to the first chunk',
      () {
        const text = '---\ntitle: Note\n\ntags: [a]\n---\nBody';
        final chunks = splitChunks(text);
        expect(chunks, equals([ChunkSpan(0, text.length)]));
      },
    );
  });

  group('ChunkSplitter property and performance tests', () {
    test(
      'chunks tile the text across all test_vaults/syntax and edge notes',
      () {
        final vaultDirs = [
          Directory('test_vaults/syntax'),
          Directory('../test_vaults/syntax'),
          Directory('test_vaults/edge'),
          Directory('../test_vaults/edge'),
        ];

        var checkedNotes = 0;
        for (final dir in vaultDirs) {
          if (!dir.existsSync()) continue;
          for (final file in dir.listSync(recursive: true)) {
            if (file is File && file.path.endsWith('.md')) {
              final bytes = file.readAsBytesSync();
              final text = utf8.decode(bytes, allowMalformed: true);
              final chunks = splitChunks(text);
              expect(chunks.isNotEmpty, isTrue);
              expect(chunks.first.start, equals(0));
              expect(chunks.last.end, equals(text.length));
              for (var i = 0; i < chunks.length - 1; i++) {
                expect(chunks[i].end, equals(chunks[i + 1].start));
              }
              checkedNotes++;
            }
          }
        }
        expect(checkedNotes, greaterThanOrEqualTo(20));
      },
    );

    test('5,000-line text splits in < 3 ms', () {
      final lines = List.generate(5000, (i) {
        if (i % 5 == 0) return '';
        if (i % 7 == 0) return '- list item $i';
        return 'Paragraph line $i with some regular text content.';
      });
      final text = lines.join('\n');

      // Warm up JIT
      for (var i = 0; i < 5; i++) {
        splitChunks(text);
      }

      final stopwatch = Stopwatch()..start();
      final chunks = splitChunks(text);
      stopwatch.stop();

      expect(chunks.first.start, equals(0));
      expect(chunks.last.end, equals(text.length));
      expect(stopwatch.elapsedMilliseconds, lessThan(3));
    });
  });
}
