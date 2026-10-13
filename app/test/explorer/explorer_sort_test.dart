// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/explorer/explorer_sort.dart';
import 'package:tephra/settings/vault_settings.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

void main() {
  group('explorer_sort_test', () {
    final entryFolderA = VaultEntry(
      path: VaultPath('folderA'),
      isFolder: true,
      size: 0,
      modified: DateTime.utc(2026, 1, 5),
      created: DateTime.utc(2026, 1, 1),
    );
    final entryFolderZ = VaultEntry(
      path: VaultPath('folderZ'),
      isFolder: true,
      size: 0,
      modified: DateTime.utc(2026, 1, 6),
      created: DateTime.utc(2026, 1, 2),
    );
    final entry10 = VaultEntry(
      path: VaultPath('10.md'),
      isFolder: false,
      size: 10,
      modified: DateTime.utc(2026, 1, 1),
      created: DateTime.utc(2026, 1, 3),
    );
    final entry9 = VaultEntry(
      path: VaultPath('9.md'),
      isFolder: false,
      size: 9,
      modified: DateTime.utc(2026, 1, 2),
      created: DateTime.utc(2026, 1, 4),
    );
    final entryA = VaultEntry(
      path: VaultPath('A.md'),
      isFolder: false,
      size: 1,
      modified: DateTime.utc(2026, 1, 3),
      created: DateTime.utc(2026, 1, 5),
    );
    final entryB = VaultEntry(
      path: VaultPath('b.md'),
      isFolder: false,
      size: 2,
      modified: DateTime.utc(2026, 1, 4),
      created: null, // null created falls back to modified: 2026-01-04
    );

    final entries = [
      entryB,
      entryA,
      entryFolderZ,
      entryFolderA,
      entry10,
      entry9,
    ];

    test('folders always first in all six modes', () {
      for (final mode in ExplorerSort.values) {
        final sorted = sortEntries(entries, mode);
        expect(sorted[0].isFolder, isTrue);
        expect(sorted[1].isFolder, isTrue);
        expect(sorted[2].isFolder, isFalse);
        expect(sorted[3].isFolder, isFalse);
        expect(sorted[4].isFolder, isFalse);
        expect(sorted[5].isFolder, isFalse);
      }
    });

    test('nameAsc sorts folders then 10, 9, A, b', () {
      final sorted = sortEntries(entries, ExplorerSort.nameAsc);
      final paths = sorted.map((e) => e.path.value).toList();
      expect(
        paths,
        equals(['folderA', 'folderZ', '10.md', '9.md', 'A.md', 'b.md']),
      );
    });

    test('nameDesc reverses within groups', () {
      final sorted = sortEntries(entries, ExplorerSort.nameDesc);
      final paths = sorted.map((e) => e.path.value).toList();
      expect(
        paths,
        equals(['folderZ', 'folderA', 'b.md', 'A.md', '9.md', '10.md']),
      );
    });

    test('modifiedNew sorts newest modified first', () {
      final sorted = sortEntries(entries, ExplorerSort.modifiedNew);
      final paths = sorted.map((e) => e.path.value).toList();
      expect(
        paths,
        equals(['folderZ', 'folderA', 'b.md', 'A.md', '9.md', '10.md']),
      );
    });

    test('modifiedOld sorts oldest modified first', () {
      final sorted = sortEntries(entries, ExplorerSort.modifiedOld);
      final paths = sorted.map((e) => e.path.value).toList();
      expect(
        paths,
        equals(['folderA', 'folderZ', '10.md', '9.md', 'A.md', 'b.md']),
      );
    });

    test(
      'createdNew sorts newest created first (fallback to modified for null)',
      () {
        final sorted = sortEntries(entries, ExplorerSort.createdNew);
        final paths = sorted.map((e) => e.path.value).toList();
        expect(
          paths,
          equals(['folderZ', 'folderA', 'A.md', '9.md', 'b.md', '10.md']),
        );
      },
    );

    test('createdOld sorts oldest created first', () {
      final sorted = sortEntries(entries, ExplorerSort.createdOld);
      final paths = sorted.map((e) => e.path.value).toList();
      expect(
        paths,
        equals(['folderA', 'folderZ', '10.md', '9.md', 'b.md', 'A.md']),
      );
    });
  });
}
