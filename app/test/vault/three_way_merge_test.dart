// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/vault/three_way_merge.dart';

void main() {
  group('threeWayMerge', () {
    test('1. identical edits and base matches', () {
      const base = 'line 1\nline 2\nline 3\n';
      const mine = 'line 1\nline 2 changed\nline 3\n';
      const theirs = 'line 1\nline 2 changed\nline 3\n';

      // identical edits
      final r1 = threeWayMerge(base: base, mine: mine, theirs: theirs);
      expect(r1.clean, isTrue);
      expect(r1.text, mine);

      // mine == base -> theirs
      final r2 = threeWayMerge(base: base, mine: base, theirs: theirs);
      expect(r2.clean, isTrue);
      expect(r2.text, theirs);

      // theirs == base -> mine
      final r3 = threeWayMerge(base: base, mine: mine, theirs: base);
      expect(r3.clean, isTrue);
      expect(r3.text, mine);
    });

    test('2. non-overlapping edits merge', () {
      final baseLines = List.generate(20, (i) => 'L${i + 1}');
      final base = '${baseLines.join('\n')}\n';

      final mineLines = List<String>.from(baseLines);
      mineLines[1] = 'L2 mine';
      final mine = '${mineLines.join('\n')}\n';

      final theirsLines = List<String>.from(baseLines);
      theirsLines[17] = 'L18 theirs';
      final theirs = '${theirsLines.join('\n')}\n';

      final res = threeWayMerge(base: base, mine: mine, theirs: theirs);
      expect(res.clean, isTrue);
      expect(res.text, contains('L2 mine'));
      expect(res.text, contains('L18 theirs'));
      expect(res.text, contains('L1\nL2 mine\nL3'));
      expect(res.text, contains('L17\nL18 theirs\nL19'));
    });

    test('3. theirs inserts lines above (context shift)', () {
      final baseLines = List.generate(20, (i) => 'L${i + 1}');
      final base = '${baseLines.join('\n')}\n';

      final mineLines = List<String>.from(baseLines);
      mineLines[9] = 'L10 mine edited';
      final mine = '${mineLines.join('\n')}\n';

      final theirs = 'P1\nP2\nP3\n$base';

      final res = threeWayMerge(base: base, mine: mine, theirs: theirs);
      expect(res.clean, isTrue);
      expect(res.text.startsWith('P1\nP2\nP3\n'), isTrue);
      expect(res.text, contains('L10 mine edited'));
    });

    test('4. same line, different edits -> conflict', () {
      const base = 'line 1\nshared line\nline 3\n';
      const mine = 'line 1\nshared line mine\nline 3\n';
      const theirs = 'line 1\nshared line theirs\nline 3\n';

      final res = threeWayMerge(base: base, mine: mine, theirs: theirs);
      expect(res.clean, isFalse);
      expect(res.text, mine);
    });

    test('5. one-character context difference inside context -> not clean', () {
      // Patch context lines around the change must match strictly
      const base = 'ctxA\nctxB\nTARGET\nctxC\nctxD\n';
      const mine = 'ctxA\nctxB\nTARGET MINE\nctxC\nctxD\n';
      // Theirs modified ctxB slightly
      const theirs = 'ctxA\nctxX\nTARGET\nctxC\nctxD\n';

      final res = threeWayMerge(base: base, mine: mine, theirs: theirs);
      // Because matchThreshold is 0.001 and patchDeleteThreshold is 0.0,
      // the patch for TARGET requires strict exact context
      expect(res.clean, isFalse);
      expect(res.text, mine);
    });

    test('6. append vs prepend -> clean', () {
      const base = 'middle content\n';
      const mine = 'PREPEND\n$base';
      const theirs = '$base\nAPPEND\n';

      final res = threeWayMerge(base: base, mine: mine, theirs: theirs);
      expect(res.clean, isTrue);
      expect(res.text, contains('PREPEND'));
      expect(res.text, contains('middle content'));
      expect(res.text, contains('APPEND'));
    });

    test('7. Unicode (Bangla, emoji) merges cleanly', () {
      const base = 'ভূমিকা\nবিভাগ ১: সাধারণ\nউপসংহার 🎯\n';
      const mine = 'ভূমিকা (সম্পাদিত)\nবিভাগ ১: সাধারণ\nউপসংহার 🎯\n';
      const theirs = 'ভূমিকা\nবিভাগ ১: সাধারণ\nউপসংহার 🎯 এবং আরও 🚀\n';

      final res = threeWayMerge(base: base, mine: mine, theirs: theirs);
      expect(res.clean, isTrue);
      expect(res.text, contains('ভূমিকা (সম্পাদিত)'));
      expect(res.text, contains('বিভাগ ১: সাধারণ'));
      expect(res.text, contains('উপসংহার 🎯 এবং আরও 🚀'));
    });

    test(
      '8. too large (> 3,000,000 chars) -> not clean without calling dmp',
      () {
        final large = 'a' * 1100000;
        final res = threeWayMerge(
          base: large,
          mine: '${large}m',
          theirs: '${large}t',
        );
        // Total length = 1.1M * 3 > 3M
        expect(res.clean, isFalse);
        expect(res.text, '${large}m');
      },
    );

    test('9. 5,000-line note merges in < 500 ms', () {
      final lines = List.generate(
        5000,
        (i) => 'Line $i: Content of line for performance testing of merge.',
      );
      final base = '${lines.join('\n')}\n';

      final mineLines = List<String>.from(lines);
      mineLines[100] = 'Line 100: Mine edited line!';
      final mine = '${mineLines.join('\n')}\n';

      final theirsLines = List<String>.from(lines);
      theirsLines[4900] = 'Line 4900: Theirs edited line!';
      final theirs = '${theirsLines.join('\n')}\n';

      final sw = Stopwatch()..start();
      final res = threeWayMerge(base: base, mine: mine, theirs: theirs);
      sw.stop();

      // ignore: avoid_print
      print('5000-line 3-way merge took: ${sw.elapsedMilliseconds} ms');

      expect(res.clean, isTrue);
      expect(res.text, contains('Line 100: Mine edited line!'));
      expect(res.text, contains('Line 4900: Theirs edited line!'));
      expect(sw.elapsedMilliseconds, lessThan(500));
    });

    test('10. result deterministic', () {
      const base = 'line A\nline B\nline C\n';
      const mine = 'line A mine\nline B\nline C\n';
      const theirs = 'line A\nline B\nline C theirs\n';

      final r1 = threeWayMerge(base: base, mine: mine, theirs: theirs);
      final r2 = threeWayMerge(base: base, mine: mine, theirs: theirs);

      expect(r1.clean, r2.clean);
      expect(r1.text, r2.text);
    });
  });
}
