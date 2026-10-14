// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tephra_vault/tephra_vault.dart';
import 'package:test/test.dart';

File _findEdgeFile(String name) {
  var dir = Directory.current;
  while (true) {
    final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
    if (pubspec.existsSync() &&
        pubspec.readAsStringSync().contains('name: tephra_workspace')) {
      return File(p.join(dir.path, 'test_vaults', 'edge', name));
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError(
        'Could not locate tephra_workspace root from ${Directory.current.path}',
      );
    }
    dir = parent;
  }
}

void main() {
  test('1. empty file', () {
    final doc = TextDocument.decode(<int>[]);
    expect(doc.text, equals(''));
    expect(doc.hasBom, isFalse);
    expect(doc.lineEnding, equals(LineEnding.lf));
    expect(doc.malformed, isFalse);
    expect(doc.encode(), equals(<int>[]));
  });

  test('2. lf file', () {
    final bytes = utf8.encode('a\nb\n');
    final doc = TextDocument.decode(bytes);
    expect(doc.lineEnding, equals(LineEnding.lf));
    expect(doc.encode(), equals(bytes));
  });

  test('3. crlf file', () {
    final bytes = utf8.encode('a\r\nb\r\n');
    final doc = TextDocument.decode(bytes);
    expect(doc.text, equals('a\nb\n'));
    expect(doc.lineEnding, equals(LineEnding.crlf));
    expect(doc.encode(), equals(bytes));
  });

  test('4. bom file', () {
    final bytes = [0xEF, 0xBB, 0xBF, ...utf8.encode('x')];
    final doc = TextDocument.decode(bytes);
    expect(doc.hasBom, isTrue);
    expect(doc.text, equals('x'));
    expect(doc.encode(), equals(bytes));
  });

  test('5. bom only', () {
    final bytes = [0xEF, 0xBB, 0xBF];
    final doc = TextDocument.decode(bytes);
    expect(doc.hasBom, isTrue);
    expect(doc.text, equals(''));
    expect(doc.encode(), equals(bytes));
  });

  test('6. bom and crlf', () {
    final bytes = [0xEF, 0xBB, 0xBF, ...utf8.encode('# T\r\n\r\nx\r\n')];
    final doc = TextDocument.decode(bytes);
    expect(doc.hasBom, isTrue);
    expect(doc.lineEnding, equals(LineEnding.crlf));
    expect(doc.encode(), equals(bytes));
  });

  test('7. mixed endings dominant', () {
    final docLf = TextDocument.decode(
      utf8.encode('line 1\nline 2\r\nline 3\nline 4\r\nline 5\n'),
    );
    expect(docLf.lineEnding, equals(LineEnding.lf));
    expect(docLf.text.contains('\r'), isFalse);

    final docCrlf = TextDocument.decode(utf8.encode('a\r\nb\r\nc\n'));
    expect(docCrlf.lineEnding, equals(LineEnding.crlf));
  });

  test('8. tie goes to lf', () {
    final doc = TextDocument.decode(utf8.encode('a\r\nb\n'));
    expect(doc.lineEnding, equals(LineEnding.lf));
  });

  test('9. lone CR becomes newline', () {
    final doc = TextDocument.decode(utf8.encode('a\rb'));
    expect(doc.text, equals('a\nb'));
    expect(doc.lineEnding, equals(LineEnding.lf));
  });

  test('10. no trailing newline preserved', () {
    final bytes = utf8.encode('Last');
    final doc = TextDocument.decode(bytes);
    expect(doc.text, equals('Last'));
    expect(doc.encode(), equals(bytes));
  });

  test('11. malformed bytes', () {
    final bytes = [0x61, 0xFF, 0x62];
    final doc = TextDocument.decode(bytes);
    expect(doc.malformed, isTrue);
    expect(doc.text, equals('a\uFFFDb'));
  });

  test('12. valid multi-byte', () {
    final bangla = utf8.encode('বাংলা');
    final docBangla = TextDocument.decode(bangla);
    expect(docBangla.malformed, isFalse);
    expect(docBangla.text, equals('বাংলা'));
    expect(docBangla.encode(), equals(bangla));

    final emoji = utf8.encode('🌋');
    final docEmoji = TextDocument.decode(emoji);
    expect(docEmoji.malformed, isFalse);
    expect(docEmoji.text, equals('🌋'));
    expect(docEmoji.encode(), equals(emoji));
  });

  test('13. encode applies line ending without doubling', () {
    const doc = TextDocument(text: 'a\nb', lineEnding: LineEnding.crlf);
    expect(doc.encode(), equals(utf8.encode('a\r\nb')));
  });

  test('14. bom plus crlf encode', () {
    const doc = TextDocument(
      text: 'a\nb',
      hasBom: true,
      lineEnding: LineEnding.crlf,
    );
    expect(doc.encode(), equals([0xEF, 0xBB, 0xBF, 0x61, 0x0D, 0x0A, 0x62]));
  });

  test('15. round trip law', () {
    final files = [
      'crlf.md',
      'bom.md',
      'bom-crlf.md',
      'no-trailing-newline.md',
      'trailing-spaces.md',
      'tabs.md',
    ];

    for (final name in files) {
      final file = _findEdgeFile(name);
      final raw = file.readAsBytesSync();
      final decoded = TextDocument.decode(raw);
      expect(
        decoded.encode(),
        equals(raw),
        reason: '$name must round trip byte-exact',
      );
    }

    final mixedFile = _findEdgeFile('mixed-endings.md');
    final mixedRaw = mixedFile.readAsBytesSync();
    final mixedDecoded = TextDocument.decode(mixedRaw);
    final mixedNormalizedOriginal = utf8
        .decode(mixedRaw)
        .replaceAll('\r\n', '\n');
    final mixedNormalizedEncoded = utf8
        .decode(mixedDecoded.encode())
        .replaceAll('\r\n', '\n');
    expect(mixedNormalizedEncoded, equals(mixedNormalizedOriginal));
  });
}
