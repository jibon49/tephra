// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../src/huge_note.dart';
import '../src/png_writer.dart';

void main() {
  final repoRoot = Directory.current.path;
  final syntaxDir = Directory(p.join(repoRoot, 'test_vaults', 'syntax'));
  final edgeDir = Directory(p.join(repoRoot, 'test_vaults', 'edge'));

  test('syntax notes are LF without BOM', () {
    final mdFiles = syntaxDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.md'))
        .toList();

    expect(mdFiles, isNotEmpty);
    for (final f in mdFiles) {
      final bytes = f.readAsBytesSync();
      // No BOM
      if (bytes.length >= 3) {
        expect(
          bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF,
          isFalse,
          reason: '${f.path} has a BOM',
        );
      }
      // No 0x0D (CR)
      expect(
        bytes.contains(0x0D),
        isFalse,
        reason: '${f.path} contains CR byte',
      );
      // Ends with 0x0A (LF)
      expect(bytes.last, 0x0A, reason: '${f.path} does not end with LF');
    }
  });

  test('syntax vault has the expected note count', () {
    final mdFiles = syntaxDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.md'))
        .toList();
    expect(mdFiles.length, 24);
  });

  test('edge files have exact bytes', () {
    final crlfBytes = File(p.join(edgeDir.path, 'crlf.md')).readAsBytesSync();
    final crlfStr = utf8.decode(crlfBytes);
    expect('\r\n'.allMatches(crlfStr).length, 4);
    // No lone \n
    final withoutCrlf = crlfStr.replaceAll('\r\n', '');
    expect(withoutCrlf.contains('\n'), isFalse);

    final bomBytes = File(p.join(edgeDir.path, 'bom.md')).readAsBytesSync();
    expect(bomBytes[0], 0xEF);
    expect(bomBytes[1], 0xBB);
    expect(bomBytes[2], 0xBF);

    final emptyBytes = File(p.join(edgeDir.path, 'empty.md')).readAsBytesSync();
    expect(emptyBytes.length, 0);

    final malformedBytes = File(p.join(edgeDir.path, 'malformed-utf8.md'))
        .readAsBytesSync();
    expect(() => utf8.decode(malformedBytes), throwsA(isA<FormatException>()));

    final hugeBytes = File(p.join(edgeDir.path, 'huge-5000-lines.md'))
        .readAsBytesSync();
    expect(hugeBytes.where((b) => b == 0x0A).length, 5000);

    final longLineBytes = File(p.join(edgeDir.path, 'long-line.md'))
        .readAsBytesSync();
    expect(longLineBytes.length, 100001);

    final deepNote = File(
      p.join(
        edgeDir.path,
        'deep',
        'd01',
        'd02',
        'd03',
        'd04',
        'd05',
        'd06',
        'd07',
        'd08',
        'd09',
        'd10',
        'd11',
        'd12',
        'deep-note.md',
      ),
    );
    expect(deepNote.existsSync(), isTrue);
  });

  test('generator is deterministic', () {
    final n1 = generateHugeNote();
    final n2 = generateHugeNote();
    expect(n1, equals(n2));

    final p1 = samplePngBytes();
    final p2 = samplePngBytes();
    expect(p1.take(8).toList(), [137, 80, 78, 71, 13, 10, 26, 10]);
    expect(p1, equals(p2));
  });

  test('png writer produces valid chunk CRCs', () {
    final bytes = encodePng(2, 2, [
      255,
      0,
      0,
      0,
      255,
      0,
      0,
      0,
      255,
      255,
      255,
      255,
    ]);

    expect(bytes.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
    var offset = 8;
    final chunkTypes = <String>[];

    while (offset < bytes.length) {
      final length =
          (bytes[offset] << 24) |
          (bytes[offset + 1] << 16) |
          (bytes[offset + 2] << 8) |
          bytes[offset + 3];
      final typeBytes = bytes.sublist(offset + 4, offset + 8);
      final typeStr = ascii.decode(typeBytes);
      chunkTypes.add(typeStr);

      final data = bytes.sublist(offset + 8, offset + 8 + length);
      final storedCrc =
          ((bytes[offset + 8 + length] << 24) |
              (bytes[offset + 9 + length] << 16) |
              (bytes[offset + 10 + length] << 8) |
              bytes[offset + 11 + length]) &
          0xFFFFFFFF;

      final expectedCrc = crc32([...typeBytes, ...data]);
      expect(storedCrc, expectedCrc, reason: 'CRC mismatch for chunk $typeStr');

      offset += 12 + length;
    }

    expect(chunkTypes, ['IHDR', 'IDAT', 'IEND']);
  });
}
