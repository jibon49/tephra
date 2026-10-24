// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/stickies/data/sticky_file_writer.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

void main() {
  group('StickyFileWriter', () {
    late MemoryVaultFileSystem fs;
    late StickyFileWriter writer;

    setUp(() {
      fs = MemoryVaultFileSystem();
      writer = StickyFileWriter(fs);
    });

    test('writes when hash matches', () async {
      final path = VaultPath('Stickies/Note.md');
      final initialDoc = TextDocument(text: 'Initial content\n');
      await fs.writeText(path, initialDoc);

      final initialBytes = await fs.readBytes(path);
      final initialHash = contentHash(initialBytes);

      final newHash = await writer.writeIfUnchanged(
        path,
        initialHash,
        'Updated content\n',
      );

      expect(newHash, isNotNull);
      final readDoc = await fs.readText(path);
      expect(readDoc.text, 'Updated content\n');
    });

    test('returns null and writes nothing when hash differs', () async {
      final path = VaultPath('Stickies/Note.md');
      final initialDoc = TextDocument(text: 'Initial content\n');
      await fs.writeText(path, initialDoc);

      final staleHash = 'deadbeef' * 8;

      final result = await writer.writeIfUnchanged(
        path,
        staleHash,
        'Should not write\n',
      );

      expect(result, isNull);
      final readDoc = await fs.readText(path);
      expect(readDoc.text, 'Initial content\n');
    });

    test('append adds newline when missing', () async {
      final path = VaultPath('Stickies/Append.md');
      await fs.writeText(path, TextDocument(text: 'First line'));

      await writer.append(path, 'Second line');

      final readDoc = await fs.readText(path);
      expect(readDoc.text, 'First line\nSecond line');
    });

    test('append creates missing note', () async {
      final path = VaultPath('Stickies/Missing.md');

      await writer.append(path, 'Brand new content\n');

      final readDoc = await fs.readText(path);
      expect(readDoc.text, 'Brand new content\n');
    });

    test('CRLF preserved', () async {
      final path = VaultPath('Stickies/Crlf.md');
      final crlfBytes = utf8.encode('Line 1\r\nLine 2\r\n');
      await fs.writeBytes(path, crlfBytes);

      final doc = TextDocument.decode(crlfBytes);
      expect(doc.lineEnding, LineEnding.crlf);

      final hash = contentHash(crlfBytes);
      final newHash = await writer.writeIfUnchanged(
        path,
        hash,
        'Line 1\nLine 2 updated\n',
      );

      expect(newHash, isNotNull);
      final readBytes = await fs.readBytes(path);
      final readText = utf8.decode(readBytes);
      expect(readText, 'Line 1\r\nLine 2 updated\r\n');
    });
  });
}
