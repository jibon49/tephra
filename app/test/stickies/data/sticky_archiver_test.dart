// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/stickies/data/sticky_archiver.dart';
import 'package:tephra/stickies/data/sticky_repository.dart';
import 'package:tephra/stickies/model/sticky_color.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../fakes.dart';

void main() {
  group('StickyArchiver', () {
    late MemoryVaultFileSystem fs;
    late FakeSearchEngine search;
    late FakeOpenNoteBridge openNotes;
    late ManualClock clock;
    late StickyRepository repo;
    late List<(VaultPath, VaultPath)> renameCalls;
    late StickyArchiver archiver;

    final baseTime = DateTime(2026, 10, 15, 12, 0);

    setUp(() {
      fs = MemoryVaultFileSystem();
      search = FakeSearchEngine(fs);
      openNotes = FakeOpenNoteBridge();
      clock = ManualClock(baseTime);
      renameCalls = [];

      repo = StickyRepository(
        fs: fs,
        search: search,
        settings: const StickySettingsView(
          stickyFolder: 'Stickies',
          defaultColor: NamedStickyColor.yellow,
        ),
        openNotes: openNotes,
        clock: clock,
      );

      archiver = StickyArchiver(
        repo: repo,
        rename: (from, to) async {
          renameCalls.add((from, to));
          final doc = await fs.readText(from);
          await fs.writeText(to, doc);
          await fs.delete(from);
        },
        clock: clock,
        stickyFolder: 'Stickies',
        fs: fs,
      );
    });

    tearDown(() async {
      await repo.dispose();
      openNotes.dispose();
      archiver.dispose();
    });

    test('expired yesterday moves', () async {
      await fs.createFolder(VaultPath('Stickies'));
      final notePath = VaultPath('Stickies/Yesterday.md');
      await fs.writeText(
        notePath,
        const TextDocument(
          text:
              '---\ntephra-sticky: true\nsticky-expire: 2026-10-14\n---\nTask',
        ),
      );

      await repo.start();
      expect(repo.all.length, 1);

      final moved = await archiver.archiveExpired();
      expect(moved.length, 1);
      expect(moved.first, VaultPath('Stickies/Archive/Yesterday.md'));
      expect(
        await fs.stat(VaultPath('Stickies/Archive/Yesterday.md')),
        isNotNull,
      );
      expect(await fs.stat(notePath), isNull);
    });

    test('expiring today stays', () async {
      await fs.createFolder(VaultPath('Stickies'));
      final notePath = VaultPath('Stickies/Today.md');
      await fs.writeText(
        notePath,
        const TextDocument(
          text:
              '---\ntephra-sticky: true\nsticky-expire: 2026-10-15\n---\nTask',
        ),
      );

      await repo.start();
      expect(repo.all.length, 1);

      final moved = await archiver.archiveExpired();
      expect(moved, isEmpty);
      expect(await fs.stat(notePath), isNotNull);
    });

    test('no expiry stays', () async {
      await fs.createFolder(VaultPath('Stickies'));
      final notePath = VaultPath('Stickies/NoExpire.md');
      await fs.writeText(
        notePath,
        const TextDocument(text: '---\ntephra-sticky: true\n---\nTask'),
      );

      await repo.start();
      expect(repo.all.length, 1);

      final moved = await archiver.archiveExpired();
      expect(moved, isEmpty);
      expect(await fs.stat(notePath), isNotNull);
    });

    test('collision adds suffix', () async {
      await fs.createFolder(VaultPath('Stickies'));
      await fs.createFolder(VaultPath('Stickies/Archive'));
      await fs.writeText(
        VaultPath('Stickies/Archive/Collision.md'),
        const TextDocument(text: 'Old archive'),
      );

      final notePath = VaultPath('Stickies/Collision.md');
      await fs.writeText(
        notePath,
        const TextDocument(
          text:
              '---\ntephra-sticky: true\nsticky-expire: 2026-10-10\n---\nTask',
        ),
      );

      await repo.start();
      final moved = await archiver.archiveExpired();

      expect(moved.length, 1);
      expect(moved.first, VaultPath('Stickies/Archive/Collision 1.md'));
      expect(
        await fs.stat(VaultPath('Stickies/Archive/Collision 1.md')),
        isNotNull,
      );
      expect(
        await fs.stat(VaultPath('Stickies/Archive/Collision.md')),
        isNotNull,
      );
    });

    test('uses rename service (fake records the call)', () async {
      await fs.createFolder(VaultPath('Stickies'));
      final notePath = VaultPath('Stickies/Renamed.md');
      await fs.writeText(
        notePath,
        const TextDocument(
          text:
              '---\ntephra-sticky: true\nsticky-expire: 2026-10-12\n---\nTask',
        ),
      );

      await repo.start();
      await archiver.archiveExpired();

      expect(renameCalls.length, 1);
      expect(renameCalls.first.$1, notePath);
      expect(renameCalls.first.$2, VaultPath('Stickies/Archive/Renamed.md'));
    });

    test('already archived ignored', () async {
      await fs.createFolder(VaultPath('Stickies'));
      await fs.createFolder(VaultPath('Stickies/Archive'));
      final notePath = VaultPath('Stickies/Archive/Archived.md');
      await fs.writeText(
        notePath,
        const TextDocument(
          text: '---\ntephra-sticky: true\nsticky-expire: 2026-10-10\n---\nOld',
        ),
      );

      await repo.start();
      expect(repo.archived.length, 1);
      expect(repo.all, isEmpty);

      final moved = await archiver.archiveExpired();
      expect(moved, isEmpty);
      expect(renameCalls, isEmpty);
    });
  });
}
