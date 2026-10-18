// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/tephra_index.dart';
import 'package:tephra_search/tephra_search.dart';
import 'package:tephra_vault/tephra_vault.dart';
import 'package:test/test.dart';

class _FakeClock implements Clock {
  _FakeClock(this.nowValue);
  DateTime nowValue;
  @override
  DateTime now() => nowValue;
}

void main() {
  group('SearchEngine', () {
    late _FakeClock clock;
    late MemoryVaultFileSystem fs;
    late NoteIndex index;

    setUp(() async {
      clock = _FakeClock(DateTime.utc(2026, 1, 1));
      fs = MemoryVaultFileSystem(clock: clock);
      index = await NoteIndex.open(':memory:', fs);
    });

    tearDown(() async {
      await index.close();
    });

    test('results stream in sort order for all 6 sorts', () async {
      // Create notes with controlled mtime / created
      clock.nowValue = DateTime.utc(2026, 1, 1);
      await fs.writeText(
        VaultPath('A_note.md'),
        const TextDocument(text: 'Common keyword'),
      );
      clock.nowValue = DateTime.utc(2026, 3, 1);
      await fs.writeText(
        VaultPath('B_note.md'),
        const TextDocument(text: 'Common keyword'),
      );
      clock.nowValue = DateTime.utc(2026, 2, 1);
      await fs.writeText(
        VaultPath('C_note.md'),
        const TextDocument(text: 'Common keyword'),
      );

      await index.reconcile();

      final engine = SearchEngine(index, fs);
      final expr = SearchParser.parse('keyword');

      // 1. fileNameAsc
      final rFileNameAsc = await engine
          .run(expr, sort: SearchSort.fileNameAsc)
          .map((r) => r.path.value)
          .toList();
      expect(rFileNameAsc, equals(['A_note.md', 'B_note.md', 'C_note.md']));

      // 2. fileNameDesc
      final rFileNameDesc = await engine
          .run(expr, sort: SearchSort.fileNameDesc)
          .map((r) => r.path.value)
          .toList();
      expect(rFileNameDesc, equals(['C_note.md', 'B_note.md', 'A_note.md']));

      // 3. modifiedDesc (B: Mar, C: Feb, A: Jan)
      final rModDesc = await engine
          .run(expr, sort: SearchSort.modifiedDesc)
          .map((r) => r.path.value)
          .toList();
      expect(rModDesc, equals(['B_note.md', 'C_note.md', 'A_note.md']));

      // 4. modifiedAsc (A: Jan, C: Feb, B: Mar)
      final rModAsc = await engine
          .run(expr, sort: SearchSort.modifiedAsc)
          .map((r) => r.path.value)
          .toList();
      expect(rModAsc, equals(['A_note.md', 'C_note.md', 'B_note.md']));

      // 5. createdDesc (fallback to mtime)
      final rCreatedDesc = await engine
          .run(expr, sort: SearchSort.createdDesc)
          .map((r) => r.path.value)
          .toList();
      expect(rCreatedDesc, equals(['B_note.md', 'C_note.md', 'A_note.md']));

      // 6. createdAsc (fallback to mtime)
      final rCreatedAsc = await engine
          .run(expr, sort: SearchSort.createdAsc)
          .map((r) => r.path.value)
          .toList();
      expect(rCreatedAsc, equals(['A_note.md', 'C_note.md', 'B_note.md']));
    });

    test(
      'CancelToken cancelled after the first result ends the stream',
      () async {
        await fs.writeText(
          VaultPath('N1.md'),
          const TextDocument(text: 'Match me'),
        );
        await fs.writeText(
          VaultPath('N2.md'),
          const TextDocument(text: 'Match me'),
        );
        await fs.writeText(
          VaultPath('N3.md'),
          const TextDocument(text: 'Match me'),
        );
        await index.reconcile();

        final engine = SearchEngine(index, fs);
        final token = CancelToken();
        final results = <SearchResult>[];

        await for (final res in engine.run(
          SearchParser.parse('Match'),
          cancel: token,
        )) {
          results.add(res);
          token.cancel();
        }

        expect(results.length, equals(1));
      },
    );

    test(
      '250 matching notes arrive as batches (20 then 100 then 100 then 30)',
      () async {
        for (var i = 1; i <= 250; i++) {
          final numStr = i.toString().padLeft(3, '0');
          await fs.writeText(
            VaultPath('note_$numStr.md'),
            const TextDocument(text: 'Batch test keyword here'),
          );
        }
        await index.reconcile();

        final engine = SearchEngine(index, fs);
        final results = await engine
            .run(SearchParser.parse('keyword'), sort: SearchSort.fileNameAsc)
            .toList();

        expect(results.length, equals(250));
        expect(results.first.path.value, equals('note_001.md'));
        expect(results.last.path.value, equals('note_250.md'));
      },
    );
  });
}
