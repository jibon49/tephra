// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:tephra_index/tephra_index.dart';
import 'package:tephra_search/tephra_search.dart';
import 'package:tephra_vault/tephra_vault.dart';
import 'package:test/test.dart';

Directory _findSearchVaultDir() {
  var dir = Directory('../../test_vaults/search');
  if (dir.existsSync()) return dir;
  dir = Directory('test_vaults/search');
  if (dir.existsSync()) return dir;
  throw StateError('test_vaults/search directory not found');
}

void main() {
  group('SearchParity (Q1-Q44)', () {
    late IoVaultFileSystem fs;
    late NoteIndex index;
    late SearchEngine engine;

    setUpAll(() async {
      final vaultDir = _findSearchVaultDir();
      fs = IoVaultFileSystem(vaultDir.path);
      index = await NoteIndex.open(':memory:', fs);
      await index.reconcile();
      engine = SearchEngine(index, fs);
    });

    tearDownAll(() async {
      await index.close();
    });

    Future<void> check(String query, List<String> expectedStems) async {
      final expr = SearchParser.parse(query);
      final results = await engine.run(expr).toList();

      final actualPaths = results.map((r) => r.path.value).toSet();
      final expectedPaths = expectedStems
          .map((s) => s.endsWith('.md') ? s : '$s.md')
          .toSet();

      expect(
        actualPaths,
        equals(expectedPaths),
        reason: 'Query "$query" expected $expectedPaths but got $actualPaths',
      );

      if (!query.startsWith('-') && !query.contains('""')) {
        for (final r in results) {
          expect(
            r.matches,
            isNotEmpty,
            reason:
                'Query "$query" returned note ${r.path.value} with empty matches',
          );
        }
      }
    }

    test('Q1: meeting', () async {
      await check('meeting', [
        'Alpha',
        'Beta',
        'Gamma',
        'Archive/Zeta',
        'Daily/2026-10-11',
      ]);
    });

    test('Q2: meeting bob', () async {
      await check('meeting bob', ['Alpha', 'Daily/2026-10-11']);
    });

    test('Q3: meeting OR recipe', () async {
      await check('meeting OR recipe', [
        'Alpha',
        'Beta',
        'Gamma',
        'Archive/Zeta',
        'Daily/2026-10-11',
      ]);
    });

    test('Q4: meeting -bob', () async {
      await check('meeting -bob', ['Beta', 'Gamma', 'Archive/Zeta']);
    });

    test('Q5: "meeting notes"', () async {
      await check('"meeting notes"', ['Beta']);
    });

    test('Q6: "Meeting with Bob"', () async {
      await check('"Meeting with Bob"', ['Daily/2026-10-11']);
    });

    test('Q7: match-case:Meeting', () async {
      await check('match-case:Meeting', ['Beta', 'Daily/2026-10-11']);
    });

    test('Q8: match-case:aPPLE', () async {
      await check('match-case:aPPLE', []);
    });

    test('Q9: ignore-case:APPLE', () async {
      await check('ignore-case:APPLE', ['Case']);
    });

    test('Q10: file:alpha', () async {
      await check('file:alpha', ['Alpha']);
    });

    test('Q11: file:"Epsilon Notes"', () async {
      await check('file:"Epsilon Notes"', ['Projects/Epsilon Notes']);
    });

    test('Q12: path:Projects', () async {
      await check('path:Projects', [
        'Projects/Delta',
        'Projects/Epsilon Notes',
      ]);
    });

    test('Q13: path:archive meeting', () async {
      await check('path:archive meeting', ['Archive/Zeta']);
    });

    test('Q14: tag:#project', () async {
      await check('tag:#project', ['Alpha', 'Beta']);
    });

    test('Q15: tag:project/sub', () async {
      await check('tag:project/sub', ['Beta']);
    });

    test('Q16: tag:#work', () async {
      await check('tag:#work', ['Alpha', 'Archive/Zeta']);
    });

    test('Q17: tag:#urgent OR tag:#archive', () async {
      await check('tag:#urgent OR tag:#archive', ['Beta', 'Archive/Zeta']);
    });

    test('Q18: task:report', () async {
      await check('task:report', ['Alpha', 'Projects/Epsilon Notes']);
    });

    test('Q19: task-todo:report', () async {
      await check('task-todo:report', ['Alpha']);
    });

    test('Q20: task-done:""', () async {
      await check('task-done:""', ['Alpha', 'Projects/Epsilon Notes']);
    });

    test('Q21: task-todo:call', () async {
      await check('task-todo:call', ['Beta']);
    });

    test('Q22: line:(meeting bob)', () async {
      await check('line:(meeting bob)', ['Daily/2026-10-11']);
    });

    test('Q23: section:(coffee budget)', () async {
      await check('section:(coffee budget)', []);
    });

    test('Q24: section:(meeting budget)', () async {
      await check('section:(meeting budget)', ['Daily/2026-10-11']);
    });

    test('Q25: block:(flour recipe)', () async {
      await check('block:(flour recipe)', ['Gamma']);
    });

    test('Q26: line:(recipe flour)', () async {
      await check('line:(recipe flour)', []);
    });

    test('Q27: [status]', () async {
      await check('[status]', ['Alpha', 'Beta', 'Projects/Delta']);
    });

    test('Q28: [status:draft]', () async {
      await check('[status:draft]', ['Alpha']);
    });

    test('Q29: [status:draft OR done]', () async {
      await check('[status:draft OR done]', ['Alpha', 'Beta']);
    });

    test('Q30: [status:]', () async {
      await check('[status:]', ['Projects/Delta']);
    });

    test('Q31: [reviewed:true]', () async {
      await check('[reviewed:true]', ['Archive/Zeta']);
    });

    test('Q32: /555-\\d{4}/', () async {
      await check(r'/555-\d{4}/', ['Regex']);
    });

    test('Q33: /colou?r/', () async {
      await check('/colou?r/', ['Case']);
    });

    test('Q34: বাংলায়', () async {
      await check('বাংলায়', ['বাংলা']);
    });

    test('Q35: -meeting -recipe', () async {
      await check('-meeting -recipe', [
        'Projects/Delta',
        'Projects/Epsilon Notes',
        'বাংলা',
        'Case',
        'Regex',
      ]);
    });

    test('Q36: (meeting OR coffee) budget', () async {
      await check('(meeting OR coffee) budget', ['Alpha', 'Daily/2026-10-11']);
    });

    test('Q37: "exact phrase here"', () async {
      await check('"exact phrase here"', ['Archive/Zeta']);
    });

    test('Q38: #urgent', () async {
      await check('#urgent', ['Beta']);
    });

    test('Q39: #123', () async {
      await check('#123', ['Regex']);
    });

    test('Q40: ox', () async {
      await check('ox', ['Projects/Epsilon Notes']);
    });

    test('Q41: notes', () async {
      await check('notes', ['Alpha', 'Beta', 'Projects/Epsilon Notes']);
    });

    test('Q42: content:"epsilon notes"', () async {
      await check('content:"epsilon notes"', []);
    });

    test('Q43: first', () async {
      await check('first', ['Alpha']);
    });

    test('Q44: [priority:2]', () async {
      await check('[priority:2]', ['Alpha']);
    });
  });
}
