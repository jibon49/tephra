// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:typed_data';

import 'package:tephra_sync/tephra_sync.dart';
import 'package:test/test.dart';

void main() {
  group('three_way_merge merge3', () {
    test('identical edits on both sides merge cleanly', () {
      const base = 'line 1\nline 2\nline 3\n';
      const local = 'line 1\nline 2 modified\nline 3\n';
      const remote = 'line 1\nline 2 modified\nline 3\n';

      final outcome = merge3(base, local, remote);
      expect(outcome.isClean, isTrue);
      expect(outcome.text, equals('line 1\nline 2 modified\nline 3\n'));
    });

    test('one side unchanged takes the changed side', () {
      const base = 'line 1\nline 2\nline 3\n';
      const local = 'line 1\nline 2 local\nline 3\n';
      const remote = 'line 1\nline 2\nline 3\n';

      final outcome1 = merge3(base, local, remote);
      expect(outcome1.isClean, isTrue);
      expect(outcome1.text, equals(local));

      final outcome2 = merge3(base, remote, local);
      expect(outcome2.isClean, isTrue);
      expect(outcome2.text, equals(local));
    });

    test(
      'edits in different paragraphs separated by a blank line merge cleanly',
      () {
        const base = 'Para 1 original\n\nPara 2 original\n';
        const local = 'Para 1 edited by local\n\nPara 2 original\n';
        const remote = 'Para 1 original\n\nPara 2 edited by remote\n';

        final outcome = merge3(base, local, remote);
        expect(outcome.isClean, isTrue);
        expect(
          outcome.text,
          equals('Para 1 edited by local\n\nPara 2 edited by remote\n'),
        );
      },
    );

    test('edits on the same line produce a conflict', () {
      const base = 'line 1\nline 2\nline 3\n';
      const local = 'line 1\nline 2 by Alice\nline 3\n';
      const remote = 'line 1\nline 2 by Bob\nline 3\n';

      final outcome = merge3(base, local, remote);
      expect(outcome.isClean, isFalse);
    });

    test('edits on neighbouring lines produce a conflict', () {
      const base = 'line 1\nline 2\nline 3\n';
      const local = 'line 1 edited\nline 2\nline 3\n';
      const remote = 'line 1\nline 2 edited\nline 3\n';

      final outcome = merge3(base, local, remote);
      expect(outcome.isClean, isFalse);
    });

    test(
      'both insert at end of file conflicts unless insertions are identical',
      () {
        const base = 'line 1\nline 2\n';
        const localDiff = 'line 1\nline 2\nline 3 local\n';
        const remoteDiff = 'line 1\nline 2\nline 3 remote\n';

        final outcomeDiff = merge3(base, localDiff, remoteDiff);
        expect(outcomeDiff.isClean, isFalse);

        const localSame = 'line 1\nline 2\nline 3 same\n';
        const remoteSame = 'line 1\nline 2\nline 3 same\n';

        final outcomeSame = merge3(base, localSame, remoteSame);
        expect(outcomeSame.isClean, isTrue);
        expect(outcomeSame.text, equals('line 1\nline 2\nline 3 same\n'));
      },
    );

    test('deletion vs edit of the same line produces a conflict', () {
      const base = 'line 1\nline 2\nline 3\n';
      const local = 'line 1\nline 3\n'; // deleted line 2
      const remote = 'line 1\nline 2 modified\nline 3\n'; // edited line 2

      final outcome = merge3(base, local, remote);
      expect(outcome.isClean, isFalse);
    });

    test('last line without trailing newline merges cleanly', () {
      const base = 'header\n\nbody';
      const local = 'HEADER\n\nbody';
      const remote = 'header\n\nBODY';

      final outcome = merge3(base, local, remote);
      expect(outcome.isClean, isTrue);
      expect(outcome.text, equals('HEADER\n\nBODY'));
    });

    test('60,001 distinct lines produces a conflict', () {
      final base = List.generate(20000, (i) => 'base_$i\n').join();
      final local = List.generate(20000, (i) => 'local_$i\n').join();
      final remote = List.generate(20001, (i) => 'remote_$i\n').join();

      final outcome = merge3(base, local, remote);
      expect(outcome.isClean, isFalse);
    });
  });

  group('mergeDocuments document encoding', () {
    test('CRLF local document results in CRLF encoded bytes', () {
      final baseBytes = utf8.encode('line 1\n\nline 2\n');
      final localBytes = utf8.encode('line 1 edited\r\n\r\nline 2\r\n');
      final remoteBytes = utf8.encode('line 1\n\nline 2 edited\n');

      final outcome = mergeDocuments(
        baseBytes: baseBytes,
        localBytes: localBytes,
        remoteBytes: remoteBytes,
      );

      expect(outcome.isClean, isTrue);
      expect(outcome.text, equals('line 1 edited\n\nline 2 edited\n'));
      expect(
        utf8.decode(outcome.bytes!),
        equals('line 1 edited\r\n\r\nline 2 edited\r\n'),
      );
    });

    test('BOM in local document is preserved in output bytes', () {
      final baseBytes = utf8.encode('line 1\n\nline 2\n');
      final localBytes = Uint8List.fromList([
        0xEF,
        0xBB,
        0xBF,
        ...utf8.encode('line 1 edited\n\nline 2\n'),
      ]);
      final remoteBytes = utf8.encode('line 1\n\nline 2 edited\n');

      final outcome = mergeDocuments(
        baseBytes: baseBytes,
        localBytes: localBytes,
        remoteBytes: remoteBytes,
      );

      expect(outcome.isClean, isTrue);
      expect(outcome.bytes!.sublist(0, 3), equals([0xEF, 0xBB, 0xBF]));
      expect(
        utf8.decode(outcome.bytes!.sublist(3)),
        equals('line 1 edited\n\nline 2 edited\n'),
      );
    });

    test('malformed UTF-8 in any input produces conflict', () {
      final validBytes = utf8.encode('valid text\n');
      final malformedBytes = [0xFF, 0xFE, 0xFD]; // invalid UTF-8 sequence

      final outcome1 = mergeDocuments(
        baseBytes: malformedBytes,
        localBytes: validBytes,
        remoteBytes: validBytes,
      );
      expect(outcome1.isClean, isFalse);

      final outcome2 = mergeDocuments(
        baseBytes: validBytes,
        localBytes: malformedBytes,
        remoteBytes: validBytes,
      );
      expect(outcome2.isClean, isFalse);

      final outcome3 = mergeDocuments(
        baseBytes: validBytes,
        localBytes: validBytes,
        remoteBytes: malformedBytes,
      );
      expect(outcome3.isClean, isFalse);
    });
  });
}
