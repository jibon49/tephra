// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'src/huge_note.dart';
import 'src/png_writer.dart';

void main() {
  final repoRoot = _findRepoRoot();
  final edgeDir = Directory(p.join(repoRoot, 'test_vaults', 'edge'));
  final attachDir = Directory(
    p.join(repoRoot, 'test_vaults', 'syntax', 'attachments'),
  );

  if (edgeDir.existsSync()) {
    edgeDir.deleteSync(recursive: true);
  }
  edgeDir.createSync(recursive: true);

  if (attachDir.existsSync()) {
    attachDir.deleteSync(recursive: true);
  }
  attachDir.createSync(recursive: true);

  const basePattern = 'lorem ipsum dolor sit amet ';
  final longLineStr = (basePattern * ((100000 ~/ basePattern.length) + 1))
      .substring(0, 100000);

  final edgeFiles = <String, List<int>>{
    'crlf.md': utf8.encode('# CRLF file\r\n\r\nLine one\r\nLine two\r\n'),
    'bom.md': [
      0xEF,
      0xBB,
      0xBF,
      ...utf8.encode('# BOM file\n\nText after the BOM.\n'),
    ],
    'bom-crlf.md': [
      0xEF,
      0xBB,
      0xBF,
      ...utf8.encode('# BOM and CRLF\r\n\r\nText.\r\n'),
    ],
    'mixed-endings.md': utf8.encode(
      'line 1\nline 2\r\nline 3\nline 4\r\nline 5\n',
    ),
    'empty.md': <int>[],
    'only-frontmatter.md': utf8.encode(
      '---\ntitle: Only frontmatter\ntags: [edge]\n---\n',
    ),
    'no-trailing-newline.md': utf8.encode('Last line has no newline'),
    'trailing-spaces.md': utf8.encode(
      'Hard break with two spaces  \nnext line\n\nTrailing tab\t\n',
    ),
    'tabs.md': utf8.encode(
      '-\tTab after bullet\n\tIndented with a tab\n\n```\n\tcode with tab\n```\n',
    ),
    'malformed-utf8.md': [
      ...utf8.encode('Valid start\n'),
      0xFF,
      0xFE,
      ...utf8.encode('middle\n'),
      0xE2,
      0x82,
      ...utf8.encode('\nend\n'),
    ],
    'long-line.md': utf8.encode('$longLineStr\n'),
    'huge-5000-lines.md': utf8.encode(generateHugeNote()),
    'নোট.md': utf8.encode('# বাংলা নোট\n\nএটি একটি বাংলা নোট। #বাংলা\n'),
    '🌋 Volcano.md': utf8.encode(
      '# 🌋 Volcano\n\nEmoji in the file name. 🔥\n',
    ),
    'Spaces in name.md': utf8.encode('File name with spaces.\n'),
    'unicode-nfd.md': utf8.encode('Cafe\u0301 is NFD and Caf\u00e9 is NFC.\n'),
    'deep/d01/d02/d03/d04/d05/d06/d07/d08/d09/d10/d11/d12/deep-note.md': utf8
        .encode('# Deep note\n\nTwelve folders deep.\n'),
    '.hidden/hidden-note.md': utf8.encode(
      'This note is in a hidden folder and must be ignored.\n',
    ),
  };

  final attachFiles = <String, List<int>>{
    'sample.png': samplePngBytes(),
    'sample.pdf': utf8.encode('%PDF-1.4\n% Tephra placeholder PDF\n%%EOF\n'),
    'sample.mp3': utf8.encode('TEPHRA PLACEHOLDER MP3\n'),
    'sample.mp4': utf8.encode('TEPHRA PLACEHOLDER MP4\n'),
  };

  var total = 0;
  for (final entry in edgeFiles.entries) {
    final file = File(p.join(edgeDir.path, entry.key));
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(entry.value, flush: true);
    stdout.writeln('Wrote test_vaults/edge/${entry.key}');
    total++;
  }

  for (final entry in attachFiles.entries) {
    final file = File(p.join(attachDir.path, entry.key));
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(entry.value, flush: true);
    stdout.writeln('Wrote test_vaults/syntax/attachments/${entry.key}');
    total++;
  }

  stdout.writeln('Wrote $total files.');
}

String _findRepoRoot() {
  var dir = Directory.current;
  while (true) {
    final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
    if (pubspec.existsSync()) {
      final content = pubspec.readAsStringSync();
      if (content.contains('name: tephra_workspace')) {
        return dir.path;
      }
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      break;
    }
    dir = parent;
  }
  throw StateError(
    'Could not locate workspace root (pubspec.yaml with name: tephra_workspace)',
  );
}
