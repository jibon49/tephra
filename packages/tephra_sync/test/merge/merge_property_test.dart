// © 2026 Tephra. All rights reserved.

import 'dart:math';

import 'package:tephra_sync/tephra_sync.dart';
import 'package:test/test.dart';

void main() {
  group('merge3 Property Test (2,000 seeded random triples)', () {
    test('disjoint edits separated by >= 1 unchanged line merge cleanly with both edits', () {
      final random = Random(42);
      const iterations = 2000;

      for (var iter = 0; iter < iterations; iter++) {
        // Generate base with 8 to 25 lines
        final numLines = 8 + random.nextInt(18);
        final baseLines = List.generate(
          numLines,
          (i) => 'base_line_${iter}_$i\n',
        );

        // Pick range 1: [start1, end1)
        final maxStart1 = numLines - 6;
        final start1 = random.nextInt(maxStart1);
        final len1 = random.nextInt(3); // 0 (pure insertion), 1, or 2 lines
        final end1 = start1 + len1;

        // Pick range 2: [start2, end2), ensuring start2 >= end1 + 1 (at least 1 line separation)
        final minStart2 = end1 + 1;
        final availableForRange2 = numLines - minStart2 - 2;
        final start2 = minStart2 + random.nextInt(max(1, availableForRange2));
        final len2 = random.nextInt(3);
        final end2 = start2 + len2;

        // Generate replacement lines for local and remote
        final localNewLines = List.generate(
          random.nextInt(4),
          (k) => 'local_replacement_${iter}_$k\n',
        );
        final remoteNewLines = List.generate(
          random.nextInt(4),
          (k) => 'remote_replacement_${iter}_$k\n',
        );

        final localLines = List<String>.from(baseLines)
          ..replaceRange(start1, end1, localNewLines);
        final remoteLines = List<String>.from(baseLines)
          ..replaceRange(start2, end2, remoteNewLines);

        final base = baseLines.join('');
        final local = localLines.join('');
        final remote = remoteLines.join('');

        final outcome = merge3(base, local, remote);

        expect(
          outcome.isClean,
          isTrue,
          reason:
              'Iteration $iter should merge cleanly: range1=[$start1, $end1), range2=[$start2, $end2)',
        );

        final mergedText = outcome.text!;

        // Must contain all newly inserted local lines
        for (final line in localNewLines) {
          expect(
            mergedText.contains(line),
            isTrue,
            reason:
                'Iteration $iter: merged text must contain local line $line',
          );
        }

        // Must contain all newly inserted remote lines
        for (final line in remoteNewLines) {
          expect(
            mergedText.contains(line),
            isTrue,
            reason:
                'Iteration $iter: merged text must contain remote line $line',
          );
        }

        // Must contain the separating unchanged base line at end1
        final separatingLine = baseLines[end1];
        expect(
          mergedText.contains(separatingLine),
          isTrue,
          reason:
              'Iteration $iter: merged text must preserve separating line $separatingLine',
        );
      }
    });
  });
}
