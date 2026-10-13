// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/explorer/explorer_rows.dart';
import 'package:tephra/explorer/visible_file_types.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

void main() {
  group('explorer_rows_test', () {
    VaultEntry makeEntry(String path, {bool isFolder = false}) {
      return VaultEntry(
        path: VaultPath(path),
        isFolder: isFolder,
        size: isFolder ? 0 : 100,
        modified: DateTime.utc(2026, 1, 1),
      );
    }

    test('flattenTree with expanded folders produces expected DFS (path, depth) rows', () {
      final entryA = makeEntry('a', isFolder: true);
      final entryAB = makeEntry('a/b', isFolder: true);
      final entryABC = makeEntry('a/b/c.md', isFolder: false);
      final entryAX = makeEntry('a/x.md', isFolder: false);

      final rootEntries = [entryA];
      final expanded = {VaultPath('a'), VaultPath('a/b')};
      final childrenOf = {
        VaultPath('a'): [entryAB, entryAX],
        VaultPath('a/b'): [entryABC],
      };

      final rows = flattenTree(rootEntries, expanded, childrenOf);
      final actual = rows.map((r) => (r.entry.path.value, r.depth)).toList();

      expect(
        actual,
        equals([('a', 0), ('a/b', 1), ('a/b/c.md', 2), ('a/x.md', 1)]),
      );
    });

    test('an expanded folder missing from childrenOf yields a loading row', () {
      final entryA = makeEntry('a', isFolder: true);
      final rootEntries = [entryA];
      final expanded = {VaultPath('a')};
      final childrenOf =
          <VaultPath, List<VaultEntry>>{}; // empty map: not yet loaded

      final rows = flattenTree(rootEntries, expanded, childrenOf);
      expect(rows.length, equals(2));
      expect(rows[0].entry.path.value, equals('a'));
      expect(rows[0].depth, equals(0));
      expect(rows[0].expanded, isTrue);
      expect(rows[0].loading, isFalse);

      expect(rows[1].loading, isTrue);
      expect(rows[1].depth, equals(1));
    });

    test('a non-expanded folder hides children', () {
      final entryA = makeEntry('a', isFolder: true);
      final entryAB = makeEntry('a/b.md', isFolder: false);
      final rootEntries = [entryA];
      final expanded = <VaultPath>{}; // not expanded
      final childrenOf = {
        VaultPath('a'): [entryAB],
      };

      final rows = flattenTree(rootEntries, expanded, childrenOf);
      expect(rows.length, equals(1));
      expect(rows[0].entry.path.value, equals('a'));
      expect(rows[0].expanded, isFalse);
    });

    test('isVisibleInExplorer hides .xyz, shows .canvas and folders', () {
      final hiddenFile = makeEntry('secret.xyz');
      final canvasFile = makeEntry('diagram.canvas');
      final mdFile = makeEntry('note.md');
      final folder = makeEntry('docs', isFolder: true);

      expect(isVisibleInExplorer(hiddenFile), isFalse);
      expect(isVisibleInExplorer(canvasFile), isTrue);
      expect(isVisibleInExplorer(mdFile), isTrue);
      expect(isVisibleInExplorer(folder), isTrue);
    });

    test('displayName strips .md only from markdown files', () {
      final md = makeEntry('Note.md');
      final canvas = makeEntry('Diagram.canvas');
      final folder = makeEntry('Folder.md', isFolder: true);

      expect(displayName(md), equals('Note'));
      expect(displayName(canvas), equals('Diagram.canvas'));
      expect(displayName(folder), equals('Folder.md'));
    });
  });
}
