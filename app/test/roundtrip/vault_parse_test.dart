// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tephra/reading/reading_view.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_markdown/tephra_markdown.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../helpers/test_app.dart';

Directory _findVaultsDir() {
  var dir = Directory('test_vaults');
  if (dir.existsSync()) return dir;
  dir = Directory('../test_vaults');
  if (dir.existsSync()) return dir;
  dir = Directory('../../test_vaults');
  if (dir.existsSync()) return dir;
  throw StateError('test_vaults not found');
}

void _checkInvariants(MdNode node, int textLength) {
  expect(
    node.start >= 0,
    isTrue,
    reason: 'start < 0 for ${node.runtimeType} (${node.start})',
  );
  expect(
    node.end >= node.start,
    isTrue,
    reason: 'end < start for ${node.runtimeType} (${node.start}..${node.end})',
  );
  expect(
    node.end <= textLength,
    isTrue,
    reason:
        'end > textLength for ${node.runtimeType} (${node.end} > $textLength)',
  );

  for (var i = 0; i < node.children.length; i++) {
    final child = node.children[i];
    expect(
      child.start >= node.start,
      isTrue,
      reason:
          'child ${child.runtimeType} start ${child.start} < parent ${node.runtimeType} start ${node.start}',
    );
    expect(
      child.end <= node.end,
      isTrue,
      reason:
          'child ${child.runtimeType} end ${child.end} > parent ${node.runtimeType} end ${node.end}',
    );
    if (i + 1 < node.children.length) {
      final next = node.children[i + 1];
      expect(
        child.end <= next.start,
        isTrue,
        reason:
            'siblings overlap: ${child.runtimeType}@${child.start}-${child.end} vs ${next.runtimeType}@${next.start}-${next.end}',
      );
    }
    _checkInvariants(child, textLength);
  }
}

void main() {
  final vaultsDir = _findVaultsDir();

  test('parse every .md note in syntax, edge, and real vaults', () {
    final sw = Stopwatch()..start();
    var noteCount = 0;

    for (final vaultName in ['syntax', 'edge', 'real']) {
      final dir = Directory(p.join(vaultsDir.path, vaultName));
      if (!dir.existsSync()) {
        throw StateError('Vault directory missing: ${dir.path}');
      }

      final files =
          dir
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.toLowerCase().endsWith('.md'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));

      for (final file in files) {
        noteCount++;
        final bytes = file.readAsBytesSync();
        final doc = TextDocument.decode(bytes);
        final parsed = MarkdownParser.parse(doc.text);
        _checkInvariants(parsed.root, doc.text.length);
      }
    }
    sw.stop();
    debugPrint(
      'PARSER parsed $noteCount notes across syntax, edge, real in ${sw.elapsedMilliseconds} ms',
    );
    expect(noteCount, greaterThanOrEqualTo(340));
  });

  testWidgets('every syntax note renders in ReadingView without exceptions', (
    tester,
  ) async {
    final syntaxDir = Directory(p.join(vaultsDir.path, 'syntax'));
    final files =
        syntaxDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.toLowerCase().endsWith('.md'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    expect(files.length, equals(24));

    for (final file in files) {
      final text = file.readAsStringSync();
      final relPath = p
          .relative(file.path, from: syntaxDir.path)
          .replaceAll('\\', '/');
      final path = VaultPath(relPath);

      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: ReadingView(path: path, text: text),
          ),
          size: const Size(800, 1000),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.takeException(),
        isNull,
        reason: 'Exception rendering $relPath in ReadingView',
      );
    }
  });
}
