// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/tephra_index.dart';
import 'package:tephra_vault/tephra_vault.dart';
import 'package:test/test.dart';

void main() {
  test('500 notes link update performance under 5s', () async {
    final fs = MemoryVaultFileSystem();
    final index = await NoteIndex.open(':memory:', fs);

    final targetPath = VaultPath('Target.md');
    await fs.writeText(targetPath, const TextDocument(text: '# Target note\n'));

    final untouchedPath = VaultPath('Untouched.md');
    const untouchedText = '# Untouched note\nNo links here.\n';
    await fs.writeText(untouchedPath, const TextDocument(text: untouchedText));
    final untouchedOriginalBytes = await fs.readBytes(untouchedPath);

    const noteBody =
        'Intro line\n[[Target]] and [[Target#H|al]]\n![[Target]] [m](Target.md)\nEnd';

    final expectedRenamedBody =
        'Intro line\n[[Renamed]] and [[Renamed#H|al]]\n![[Renamed]] [m](Renamed.md)\nEnd';

    final expectedBytes = <VaultPath, List<int>>{};

    for (var i = 0; i < 500; i++) {
      final name = 'N${i.toString().padLeft(3, '0')}.md';
      final path = VaultPath(name);
      final lineEnding = (i < 50) ? LineEnding.crlf : LineEnding.lf;
      final hasBom = (i >= 50 && i < 100);

      final doc = TextDocument(
        text: noteBody,
        lineEnding: lineEnding,
        hasBom: hasBom,
      );
      await fs.writeText(path, doc);

      final expDoc = TextDocument(
        text: expectedRenamedBody,
        lineEnding: lineEnding,
        hasBom: hasBom,
      );
      expectedBytes[path] = expDoc.encode();
    }

    await index.reconcile();

    final stopwatch = Stopwatch()..start();

    // 1. Plan
    final table = await index.loadNameTable();
    const settings = LinkFormatSettings(
      format: NewLinkFormat.shortest,
      useMarkdownLinks: false,
    );
    final planner = RenamePlanner(before: table, settings: settings);

    final moves = {targetPath: VaultPath('Folder/Renamed.md')};

    // Collect sources from backlinks + moved markdown files
    final backlinks = await index.backlinks(targetPath);
    final sourcePaths = <VaultPath>{
      for (final b in backlinks) b.source,
      if (targetPath.isMarkdown) targetPath,
    };

    final sources = <VaultPath, String>{};
    final docs = <VaultPath, TextDocument>{};
    for (final p in sourcePaths) {
      final doc = await fs.readText(p);
      sources[p] = doc.text;
      docs[p] = doc;
    }

    final plan = planner.plan(moves, sources);

    // Assert counts
    expect(plan.linkCount, 2000);
    expect(plan.fileCount, 500);

    // 2. Apply move
    await fs.move(targetPath, VaultPath('Folder/Renamed.md'));

    // 3. Apply edits to disk files
    for (final fileEdit in plan.fileEdits) {
      final newPath = moves[fileEdit.path] ?? fileEdit.path;
      final origDoc = docs[fileEdit.path]!;
      final newText = applyTextEdits(sources[fileEdit.path]!, fileEdit.edits);
      await fs.writeText(
        newPath,
        TextDocument(
          text: newText,
          hasBom: origDoc.hasBom,
          lineEnding: origDoc.lineEnding,
        ),
      );
    }

    stopwatch.stop();
    final elapsedMs = stopwatch.elapsedMilliseconds;
    // Record elapsed time for PROGRESS.md
    expect(elapsedMs, lessThan(5000));

    // Assert every note's bytes
    for (var i = 0; i < 500; i++) {
      final name = 'N${i.toString().padLeft(3, '0')}.md';
      final path = VaultPath(name);
      final actual = await fs.readBytes(path);
      expect(actual, expectedBytes[path]);
    }

    // Assert untouched note is byte-identical
    final untouchedAfterBytes = await fs.readBytes(untouchedPath);
    expect(untouchedAfterBytes, untouchedOriginalBytes);

    await index.close();
  });
}
