// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/editor/live_preview/block_decorator.dart';
import 'package:tephra/editor/live_preview/live_preview_engine.dart';
import 'package:tephra/editor/live_preview/lp_options.dart';
import 'package:tephra_markdown/tephra_markdown.dart';

void main() {
  group('LivePreviewEngine equivalence tests', () {
    test('equivalence against single-chunk parse for all syntax notes', () {
      final syntaxDir = Directory('test_vaults/syntax').existsSync()
          ? Directory('test_vaults/syntax')
          : Directory('../test_vaults/syntax');

      var testedCount = 0;
      for (final file in syntaxDir.listSync(recursive: true)) {
        if (file is File && file.path.endsWith('.md')) {
          final bytes = file.readAsBytesSync();
          final text = utf8.decode(bytes, allowMalformed: true);

          final engine = LivePreviewEngine();
          engine.setText(text, sync: true);
          final engineDecs = engine.decorationsFor(0, text.length);

          final parsed = MarkdownParser.parse(text);
          final refDecs = decorateChunk(text, parsed, 0, const LpOptions());

          expect(
            engineDecs.length,
            equals(refDecs.length),
            reason: 'Count mismatch in ${file.path}',
          );
          for (var i = 0; i < engineDecs.length; i++) {
            expect(
              engineDecs[i],
              equals(refDecs[i]),
              reason: 'Mismatch at index $i in ${file.path}',
            );
          }
          testedCount++;
        }
      }
      expect(testedCount, greaterThanOrEqualTo(15));
    });

    test(
      '500 random single-character edits equivalence with fresh setText',
      () {
        const seed = 42;
        final rng = Random(seed);

        var text = '''
# Sample Document

First paragraph with **bold** text and [links](https://example.com).

- item 1
- item 2
- [ ] task item

```dart
var x = 1;
var y = 2;
```

Second paragraph with *italic* words.
''';

        final engine = LivePreviewEngine();
        engine.setText(text, sync: true);

        for (var i = 1; i <= 500; i++) {
          final isInsert = text.isEmpty || rng.nextBool();
          final offset = rng.nextInt(text.length + (isInsert ? 1 : 0));

          final int start;
          final int deletedLength;
          final String insertedText;

          if (isInsert) {
            start = offset;
            deletedLength = 0;
            insertedText = rng.nextBool() ? 'a' : '\n';
          } else {
            start = offset;
            deletedLength = 1;
            insertedText = '';
          }

          final newText =
              text.substring(0, start) +
              insertedText +
              text.substring(start + deletedLength);

          try {
            engine.applyEdit(
              start: start,
              deletedLength: deletedLength,
              insertedText: insertedText,
              newText: newText,
            );
          } catch (e) {
            fail('Failed at edit $i (seed: $seed): $e');
          }

          text = newText;

          if (i % 25 == 0) {
            final incrementalDecs = engine.decorationsFor(0, text.length);
            final freshEngine = LivePreviewEngine();
            freshEngine.setText(text, sync: true);
            final freshDecs = freshEngine.decorationsFor(0, text.length);

            expect(
              incrementalDecs.length,
              equals(freshDecs.length),
              reason: 'Count mismatch at edit $i (seed: $seed)',
            );
            for (var d = 0; d < incrementalDecs.length; d++) {
              expect(
                incrementalDecs[d],
                equals(freshDecs[d]),
                reason: 'Mismatch at decoration $d in edit $i (seed: $seed)',
              );
            }
          }
        }
      },
    );

    test('edit inside a paragraph re-parses exactly 1 chunk', () {
      const text = 'Paragraph 1\n\nParagraph 2 is here\n\nParagraph 3';
      final engine = LivePreviewEngine();
      engine.setText(text, sync: true);

      // Edit inside Paragraph 2 (insert '!')
      final insertPos = text.indexOf('here') + 4;
      final newText =
          '${text.substring(0, insertPos)}!${text.substring(insertPos)}';

      engine.applyEdit(
        start: insertPos,
        deletedLength: 0,
        insertedText: '!',
        newText: newText,
      );

      expect(engine.lastStats.chunksReparsed, equals(1));
    });

    test(
      'typing a code fence line re-parses following chunks until fence matches',
      () {
        const text = 'Paragraph 1\n\nParagraph 2\n\nParagraph 3';
        final engine = LivePreviewEngine();
        engine.setText(text, sync: true);

        // Turn Paragraph 2 into an unclosed fence
        const newText = 'Paragraph 1\n\n```\nParagraph 2\n\nParagraph 3';
        engine.applyEdit(
          start: 13,
          deletedLength: 0,
          insertedText: '```\n',
          newText: newText,
        );

        final fresh = LivePreviewEngine()..setText(newText, sync: true);
        expect(
          engine.decorationsFor(0, newText.length),
          equals(fresh.decorationsFor(0, newText.length)),
        );
      },
    );

    test(
      'deleting blank line between two paragraphs merges two chunks into one',
      () {
        const text = 'Paragraph 1\n\nParagraph 2';
        final engine = LivePreviewEngine();
        engine.setText(text, sync: true);
        expect(engine.lastStats.chunkCount, equals(2));

        // Delete the second '\n'
        const newText = 'Paragraph 1\nParagraph 2';
        engine.applyEdit(
          start: 12,
          deletedLength: 1,
          insertedText: '',
          newText: newText,
        );

        expect(engine.lastStats.chunkCount, equals(1));
      },
    );
  });

  group('LivePreviewEngine performance budgets', () {
    test('5,000-line note setText, applyEdit, and decorationsFor budgets', () {
      final lines = List.generate(5000, (i) {
        if (i % 6 == 0) return '';
        if (i % 8 == 0) return '- [ ] Task item $i';
        return 'Paragraph line $i with **bold** and [[Link]] content.';
      });
      final text = lines.join('\n');

      final engine = LivePreviewEngine();
      // JIT warmup
      engine.setText(text.substring(0, text.length ~/ 2), sync: true);

      // Measure setText
      final swSetText = Stopwatch()..start();
      engine.setText(text, sync: true);
      swSetText.stop();

      // Budget: setText of 5,000-line note <= 400 ms
      // ignore: avoid_print
      print('5,000-line setText: ${swSetText.elapsedMilliseconds} ms');
      expect(swSetText.elapsedMilliseconds, lessThanOrEqualTo(400));

      // Measure applyEdit median across 10 single-char typing edits
      final editTimes = <int>[];
      var curText = text;
      final targetOffset = text.indexOf('line 2500');

      for (var i = 0; i < 10; i++) {
        final newText =
            '${curText.substring(0, targetOffset)}x${curText.substring(targetOffset)}';
        final sw = Stopwatch()..start();
        engine.applyEdit(
          start: targetOffset,
          deletedLength: 0,
          insertedText: 'x',
          newText: newText,
        );
        sw.stop();
        editTimes.add(sw.elapsedMicroseconds);
        curText = newText;
      }

      editTimes.sort();
      final medianUs = editTimes[editTimes.length ~/ 2];
      final medianMs = medianUs / 1000.0;
      // ignore: avoid_print
      print('5,000-line applyEdit median: $medianMs ms');
      expect(medianMs, lessThanOrEqualTo(6.0));

      // Measure decorationsFor 60-line window
      final windowStart = targetOffset;
      final windowEnd = targetOffset + 3000;
      final swWindow = Stopwatch()..start();
      for (var i = 0; i < 100; i++) {
        engine.decorationsFor(windowStart, windowEnd);
      }
      swWindow.stop();
      final avgWindowUs = swWindow.elapsedMicroseconds / 100.0;
      final avgWindowMs = avgWindowUs / 1000.0;
      // ignore: avoid_print
      print('60-line decorationsFor avg: $avgWindowMs ms');
      expect(avgWindowMs, lessThan(1.0));
    });
  });
}
