// © 2026 Tephra. All rights reserved.

import 'dart:typed_data';

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/tephra_index.dart';
import 'package:tephra_vault/tephra_vault.dart';
import 'package:test/test.dart';

void main() {
  group('NoteIndex in-process', () {
    late MemoryVaultFileSystem fs;
    late NoteIndex index;

    const noteA = '''---
aliases: [Ay]
tags: [p]
---
# H1
[[B]] [[Missing]] ![[img.png]] #q/r
- [ ] t1
- [x] t2''';

    const noteB = '[[A#H1]] [[Ay]]';

    setUp(() async {
      fs = MemoryVaultFileSystem();
      await fs.writeText(VaultPath('A.md'), const TextDocument(text: noteA));
      await fs.writeText(VaultPath('B.md'), const TextDocument(text: noteB));
      await fs.writeBytes(VaultPath('img.png'), Uint8List.fromList([1, 2, 3]));

      index = await NoteIndex.open(':memory:', fs);
      await index.reconcile();
    });

    tearDown(() async {
      await index.close();
    });

    test('allNotes returns summaries with aliases and tags', () async {
      final notes = await index.allNotes();
      expect(notes.length, 2);

      final summaryA = notes.firstWhere((n) => n.path == VaultPath('A.md'));
      expect(summaryA.title, 'A');
      expect(summaryA.aliases, ['Ay']);
      expect(summaryA.tags, containsAll(['p', 'q/r']));
      expect(summaryA.wordCount, greaterThan(0));

      final noteInfo = await index.note(VaultPath('A.md'));
      expect(noteInfo, isNotNull);
      expect(noteInfo!.title, 'A');
      expect(noteInfo.aliases, ['Ay']);
    });

    test('resolveLink resolves alias and subpaths', () async {
      final resAy = await index.resolveLink('ay', from: VaultPath('B.md'));
      expect(resAy, VaultPath('A.md'));

      final resB = await index.resolveLink('B#x|y', from: VaultPath('A.md'));
      expect(resB, VaultPath('B.md'));

      final resSelf = await index.resolveLink('', from: VaultPath('A.md'));
      expect(resSelf, VaultPath('A.md'));

      final resMissing = await index.resolveLink(
        'NonExistent',
        from: VaultPath('A.md'),
      );
      expect(resMissing, isNull);
    });

    test('backlinks returns records targeting note', () async {
      final backs = await index.backlinks(VaultPath('A.md'));
      expect(backs.length, 2);
      expect(backs.every((l) => l.source == VaultPath('B.md')), isTrue);
      expect(backs.any((l) => l.viaAlias), isTrue);
      expect(backs.any((l) => l.heading == 'H1'), isTrue);
    });

    test('outgoing returns links and embeds from source', () async {
      final out = await index.outgoing(VaultPath('A.md'));
      expect(out.length, 3);

      final bLink = out.firstWhere((l) => l.targetRaw == 'B');
      expect(bLink.resolved, isTrue);
      expect(bLink.kind, LinkKind.link);

      final missingLink = out.firstWhere((l) => l.targetRaw == 'Missing');
      expect(missingLink.resolved, isFalse);
      expect(missingLink.kind, LinkKind.link);

      final imgEmbed = out.firstWhere((l) => l.targetRaw == 'img.png');
      expect(imgEmbed.resolved, isTrue);
      expect(imgEmbed.kind, LinkKind.embed);
    });

    test('tags returns tag counts including prefixes', () async {
      final tagList = await index.tags();
      final tagMap = {for (final t in tagList) t.tagLower: t};

      expect(tagMap.containsKey('p'), isTrue);
      expect(tagMap['p']!.count, 1);
      expect(tagMap['p']!.directCount, 1);

      expect(tagMap.containsKey('q'), isTrue);
      expect(tagMap['q']!.count, 1);
      expect(tagMap['q']!.directCount, 0);

      expect(tagMap.containsKey('q/r'), isTrue);
      expect(tagMap['q/r']!.count, 1);
      expect(tagMap['q/r']!.directCount, 1);
    });

    test('tasks filter by done status', () async {
      final undone = await index.tasks(done: false);
      expect(undone.length, 1);
      expect(undone.first.text, 't1');
      expect(undone.first.statusChar, ' ');

      final done = await index.tasks(done: true);
      expect(done.length, 1);
      expect(done.first.text, 't2');
      expect(done.first.statusChar, 'x');

      final all = await index.tasks();
      expect(all.length, 2);
    });

    test('headings returns note headings', () async {
      final hList = await index.headings(VaultPath('A.md'));
      expect(hList.length, 1);
      expect(hList.first.text, 'H1');
      expect(hList.first.level, 1);
    });

    test('fullText matches words and rejects invalid syntax', () async {
      final hits = await index.fullText('H1');
      expect(hits.map((h) => h.path), contains(VaultPath('A.md')));

      expect(
        () => index.fullText('"unterminated'),
        throwsA(isA<IndexQueryException>()),
      );
    });

    test('rawSelect allows SELECT and rejects mutations', () async {
      final rows = await index.rawSelect(
        'SELECT path FROM files ORDER BY path',
      );
      expect(rows.length, 3);

      expect(
        () => index.rawSelect('DELETE FROM files'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('stats reports correct counts', () async {
      final s = await index.stats();
      expect(s.files, 3);
      expect(s.notes, 2);
      expect(s.links, 5); // 3 from A, 2 from B
      expect(s.unresolvedLinks, 1); // Missing
      expect(s.tags, greaterThanOrEqualTo(2)); // p, q/r
    });

    test(
      'propertyKeys and propertyValues return frontmatter properties',
      () async {
        final keys = await index.propertyKeys();
        final keyNames = keys.map((k) => k.key).toList();
        expect(keyNames, containsAll(['aliases', 'tags']));

        final aliasVals = await index.propertyValues('aliases');
        expect(aliasVals, contains('Ay'));
      },
    );

    test('allFiles, allAliases, allHeadings', () async {
      final files = await index.allFiles();
      expect(files.length, 3);
      expect(
        files.any((f) => f.path == VaultPath('img.png') && !f.isNote),
        isTrue,
      );

      final aliases = await index.allAliases();
      expect(aliases.length, 1);
      expect(aliases.first.alias, 'Ay');

      final headings = await index.allHeadings();
      expect(headings.length, 1);
      expect(headings.first.text, 'H1');
    });

    test('changes stream emits after onChange', () async {
      final events = <IndexEvent>[];
      final sub = index.changes.listen(events.add);

      await fs.writeText(
        VaultPath('C.md'),
        const TextDocument(text: '# Note C'),
      );
      await index.onChange(FileCreated(VaultPath('C.md')));

      await pumpEventQueue();
      await sub.cancel();

      expect(events.isNotEmpty, isTrue);
      expect(
        events.any((e) => e.changedPaths.contains(VaultPath('C.md'))),
        isTrue,
      );
      expect(await index.note(VaultPath('C.md')), isNotNull);
    });

    test('progress reaches done with batch updates', () async {
      final bigFs = MemoryVaultFileSystem();
      for (var i = 1; i <= 450; i++) {
        final padded = i.toString().padLeft(3, '0');
        await bigFs.writeText(
          VaultPath('Note$padded.md'),
          TextDocument(text: '# Note $i\nBody $i'),
        );
      }

      final bigIndex = await NoteIndex.open(
        ':memory:',
        bigFs,
        options: const IndexOptions(batchSize: 200),
      );

      final progressList = <IndexProgress>[];
      final sub = bigIndex.progress.listen(progressList.add);

      await bigIndex.reconcile();
      await pumpEventQueue();
      await sub.cancel();
      await bigIndex.close();

      expect(progressList.isNotEmpty, isTrue);
      expect(progressList.last.phase, IndexPhase.done);
      expect(progressList.last.done, 450);

      // Verify done counts are non-decreasing
      for (var i = 1; i < progressList.length; i++) {
        expect(
          progressList[i].done >= progressList[i - 1].done,
          isTrue,
          reason: 'Done count must be non-decreasing at step $i',
        );
      }

      // Check indexing batch updates at 200, 400, 450
      final indexingDoneCounts = progressList
          .where((p) => p.phase == IndexPhase.indexing)
          .map((p) => p.done)
          .toList();
      expect(indexingDoneCounts, [200, 400, 450]);
    });

    test('unlinkedMentions returns occurrences of stem and aliases', () async {
      final uFs = MemoryVaultFileSystem();
      await uFs.writeText(
        VaultPath('Alpha.md'),
        const TextDocument(text: '---\naliases: [Al1]\n---\n# Alpha'),
      );
      await uFs.writeText(
        VaultPath('B.md'),
        const TextDocument(text: 'I like alpha.\n[[Alpha]]'),
      );
      await uFs.writeText(
        VaultPath('C.md'),
        const TextDocument(text: 'al1 rules'),
      );
      await uFs.writeText(
        VaultPath('D.md'),
        const TextDocument(text: 'alphabet'),
      );

      final uIndex = await NoteIndex.open(':memory:', uFs);
      await uIndex.reconcile();

      final mentions = await uIndex.unlinkedMentions(VaultPath('Alpha.md'));
      await uIndex.close();

      expect(mentions.length, equals(2));
      expect(mentions[0].source, equals(VaultPath('B.md')));
      expect(mentions[0].line, equals(0));
      expect(mentions[0].matchedText, equals('alpha'));

      expect(mentions[1].source, equals(VaultPath('C.md')));
      expect(mentions[1].line, equals(0));
      expect(mentions[1].matchedText, equals('al1'));
    });
  });
}
