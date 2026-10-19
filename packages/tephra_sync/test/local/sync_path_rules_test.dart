// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_sync/tephra_sync.dart';
import 'package:test/test.dart';

void main() {
  group('SyncPathRules', () {
    const rules = SelectiveSyncRules();

    test('normal notes and files participate', () {
      expect(
        SyncPathRules.participates(VaultPath('note.md'), 100, rules),
        isTrue,
      );
      expect(
        SyncPathRules.participates(
          VaultPath('folder/subfolder/meeting.md'),
          500,
          rules,
        ),
        isTrue,
      );
      expect(
        SyncPathRules.participates(VaultPath('assets/image.png'), 2048, rules),
        isTrue,
      );
    });

    test('root and negative size do not participate', () {
      expect(SyncPathRules.participates(VaultPath.root, 0, rules), isFalse);
      expect(
        SyncPathRules.participates(VaultPath('note.md'), -1, rules),
        isFalse,
      );
    });

    test('ignored segments are rejected anywhere in path', () {
      const ignored = ['.obsidian', '.git', '.trash', 'node_modules'];
      for (final seg in ignored) {
        expect(
          SyncPathRules.participates(VaultPath('$seg/file.txt'), 100, rules),
          isFalse,
          reason: 'root-level $seg',
        );
        expect(
          SyncPathRules.participates(
            VaultPath('nested/$seg/config.json'),
            100,
            rules,
          ),
          isFalse,
          reason: 'nested $seg',
        );
      }
    });

    test(
      'synced .tephra files participate, all other .tephra files do not',
      () {
        final allowed = [
          '.tephra/settings.json',
          '.tephra/hotkeys.json',
          '.tephra/bookmarks.json',
          '.tephra/types.json',
          '.tephra/workspace.json',
          '.tephra/stickies.json',
        ];
        for (final path in allowed) {
          expect(
            SyncPathRules.participates(VaultPath(path), 120, rules),
            isTrue,
            reason: '$path must participate',
          );
        }

        final rejected = [
          '.tephra/vault.json',
          '.tephra/cache/probe.tmp',
          '.tephra/history/note.1.md',
          '.tephra/other.json',
          '.tephra/subfolder/settings.json',
        ];
        for (final path in rejected) {
          expect(
            SyncPathRules.participates(VaultPath(path), 120, rules),
            isFalse,
            reason: '$path must not participate',
          );
        }
      },
    );

    test('hidden files and folders outside .tephra do not participate', () {
      expect(
        SyncPathRules.participates(VaultPath('.hidden_root.md'), 100, rules),
        isFalse,
      );
      expect(
        SyncPathRules.participates(VaultPath('.private/note.md'), 100, rules),
        isFalse,
      );
      expect(
        SyncPathRules.participates(
          VaultPath('folder/.hidden/note.md'),
          100,
          rules,
        ),
        isFalse,
      );
      expect(
        SyncPathRules.participates(VaultPath('folder/.secret.txt'), 100, rules),
        isFalse,
      );
    });

    test('temporary executor files do not participate', () {
      expect(
        SyncPathRules.participates(VaultPath('note.md.tephra-tmp'), 100, rules),
        isFalse,
      );
      expect(
        SyncPathRules.participates(
          VaultPath('note.tephra-case-12345678.md'),
          100,
          rules,
        ),
        isFalse,
      );
      expect(
        SyncPathRules.participates(
          VaultPath('folder.tephra-tmp/sub/note.md'),
          100,
          rules,
        ),
        isFalse,
      );
      expect(
        SyncPathRules.participates(
          VaultPath('folder/conflict.tephra-case-probe/file.txt'),
          100,
          rules,
        ),
        isFalse,
      );
    });

    test('SelectiveSyncRules exclusions are honored', () {
      const customRules = SelectiveSyncRules(
        excludedFolders: ['archive', 'private/raw'],
        excludedExtensions: {'pdf', 'iso'},
        maxFileSizeBytes: 1000,
        mobileMode: true,
      );

      // Excluded folders
      expect(
        SyncPathRules.participates(
          VaultPath('archive/old_note.md'),
          50,
          customRules,
        ),
        isFalse,
      );
      expect(
        SyncPathRules.participates(
          VaultPath('private/raw/data.csv'),
          50,
          customRules,
        ),
        isFalse,
      );
      expect(
        SyncPathRules.participates(
          VaultPath('notes/active.md'),
          50,
          customRules,
        ),
        isTrue,
      );

      // Excluded extensions
      expect(
        SyncPathRules.participates(VaultPath('manual.pdf'), 50, customRules),
        isFalse,
      );
      expect(
        SyncPathRules.participates(VaultPath('disk.iso'), 50, customRules),
        isFalse,
      );

      // Mobile mode video exclusions
      expect(
        SyncPathRules.participates(VaultPath('video.mp4'), 50, customRules),
        isFalse,
      );
      expect(
        SyncPathRules.participates(VaultPath('clip.mkv'), 50, customRules),
        isFalse,
      );

      // Max file size
      expect(
        SyncPathRules.participates(VaultPath('large.md'), 1001, customRules),
        isFalse,
      );
      expect(
        SyncPathRules.participates(VaultPath('small.md'), 1000, customRules),
        isTrue,
      );
    });
  });
}
