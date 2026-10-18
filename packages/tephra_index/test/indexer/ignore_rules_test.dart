// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/src/indexer/ignore_rules.dart';
import 'package:tephra_index/src/model/index_options.dart';
import 'package:test/test.dart';

void main() {
  group('isIndexable', () {
    const options = IndexOptions(excludedFolders: ['Archive/Old', 'private']);

    test('accepts normal notes and files', () {
      expect(isIndexable(VaultPath('Note.md'), options), isTrue);
      expect(isIndexable(VaultPath('Folder/Sub/Deep.md'), options), isTrue);
      expect(isIndexable(VaultPath('images/photo.png'), options), isTrue);
    });

    test('rejects dot-prefixed folders and files', () {
      expect(isIndexable(VaultPath('.obsidian/app.json'), options), isFalse);
      expect(isIndexable(VaultPath('.tephra/vault.json'), options), isFalse);
      expect(isIndexable(VaultPath('.trash/deleted.md'), options), isFalse);
      expect(isIndexable(VaultPath('.git/HEAD'), options), isFalse);
      expect(isIndexable(VaultPath('.hidden.md'), options), isFalse);
      expect(isIndexable(VaultPath('Folder/.hidden.md'), options), isFalse);
    });

    test('rejects node_modules', () {
      expect(
        isIndexable(VaultPath('node_modules/package/index.js'), options),
        isFalse,
      );
      expect(
        isIndexable(VaultPath('sub/node_modules/file.md'), options),
        isFalse,
      );
    });

    test('rejects excluded folders case-insensitively', () {
      expect(isIndexable(VaultPath('Archive/Old/note.md'), options), isFalse);
      expect(isIndexable(VaultPath('archive/old/note.md'), options), isFalse);
      expect(isIndexable(VaultPath('Archive/Old'), options), isFalse);
      expect(isIndexable(VaultPath('Private/secret.md'), options), isFalse);
      expect(isIndexable(VaultPath('private/secret.md'), options), isFalse);

      // Sibling is not excluded
      expect(isIndexable(VaultPath('Archive/New/note.md'), options), isTrue);
      expect(isIndexable(VaultPath('privatedata/note.md'), options), isTrue);
    });
  });
}
