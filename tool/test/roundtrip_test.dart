// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../src/roundtrip.dart';

void main() {
  final repoRoot = Directory.current.path;
  final edgeDir = Directory(p.join(repoRoot, 'test_vaults', 'edge'));

  test('roundtrip check on edge fixtures temp copy', () async {
    final tempDir = Directory.systemTemp.createTempSync('roundtrip_edge_test_');
    try {
      // Copy all files from edgeDir
      for (final entity in edgeDir.listSync(recursive: true)) {
        final rel = p.relative(entity.path, from: edgeDir.path);
        final targetPath = p.join(tempDir.path, rel);
        if (entity is Directory) {
          Directory(targetPath).createSync(recursive: true);
        } else if (entity is File) {
          File(targetPath).parent.createSync(recursive: true);
          entity.copySync(targetPath);
        }
      }

      final result = await checkVaultRoundtrip(tempDir.path);
      expect(result.changed, equals(0));
      expect(result.parseErrors, equals(0));
      expect(result.isSuccess, isTrue);
      expect(result.notes, equals(18));
      expect(result.unchanged, equals(16));
      expect(result.mixed, equals(1));
      expect(result.malformed, equals(1));

      // Test CLI execution
      final processResult = await Process.run('dart', [
        'run',
        'tool/roundtrip_check.dart',
        tempDir.path,
      ], workingDirectory: repoRoot);
      expect(processResult.exitCode, equals(0));
      expect(processResult.stdout, contains('changed=0 parseErrors=0'));
    } finally {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('deliberately re-encoded file is detected as changed', () async {
    final tempDir = Directory.systemTemp.createTempSync(
      'roundtrip_changed_test_',
    );
    try {
      // Copy crlf.md from edge
      final crlfSource = File(p.join(edgeDir.path, 'crlf.md'));
      final targetFile = File(p.join(tempDir.path, 'crlf.md'));
      crlfSource.copySync(targetFile.path);

      // Verify it is unchanged initially
      var result = await checkVaultRoundtrip(tempDir.path);
      expect(result.changed, equals(0));
      expect(result.unchanged, equals(1));

      // Flip CRLF to LF in the copy, but leave the file bytes containing only LF
      // Wait: if crlf.md has CRLF, and we flip CRLF to LF, TextDocument.decode will detect it as LF
      // and encode it as LF! That would be unchanged.
      // To create a changed record where doc.encode() != bytes:
      // Make a file with CRLF, but append a single LF newline so that TextDocument.decode picks CRLF
      // (dominant ending), but encoding emits CRLF for the lone LF as well, or vice versa!
      // Or even simpler: write a file that has trailing spaces or different encoding, or
      // a file where dominant is LF, but we have CRLF on one line:
      // Wait: if it's mixed, it's counted as mixed if normalized bytes match.
      // How do we make doc.encode() != bytes without it being mixed or malformed?
      // If we write bytes that decode to string S, but encode() changes something?
      // Wait! TextDocument.encode() always normalizes newlines to doc.lineEnding.
      // If a file is NOT mixed (e.g. contains only LF, dominant LF), but we insert a byte that
      // changes on encode, or:
      // What if we create a file with CRLF endings (dominant CRLF), but TextDocument encodes it as LF?
      // Wait! If the file contains 3 CRLF lines and 0 LF lines, TextDocument.decode detects CRLF.
      // If we manually change the bytes of a file by flipping 0x0D 0x0A to just 0x0D (lone CR)?
      // If raw has lone CR: TextDocument.decode normalizes '\r' to '\n', dominant is LF (or CRLF if more CRLF).
      // On encode(), '\n' becomes '\r\n' (or '\n') but NEVER '\r'!
      // And in roundtrip.dart:
      // final isMixed = crlf > 0 && (lf > 0 || cr > 0);
      // If crlf == 0, lf == 0, cr == 3: isMixed is false!
      // doc.encode() will emit '\n' (0x0A), but original bytes were '\r' (0x0D).
      // They are not equal, so changedCount++!
      targetFile.writeAsBytesSync(utf8.encode('line 1\rline 2\rline 3\r'));

      result = await checkVaultRoundtrip(tempDir.path);
      expect(result.changed, equals(1));
      expect(result.isSuccess, isFalse);

      // Verify CLI exits with code 1
      final processResult = await Process.run('dart', [
        'run',
        'tool/roundtrip_check.dart',
        tempDir.path,
      ], workingDirectory: repoRoot);
      expect(processResult.exitCode, equals(1));
      expect(processResult.stdout, contains('changed=1'));
    } finally {
      tempDir.deleteSync(recursive: true);
    }
  });
}
