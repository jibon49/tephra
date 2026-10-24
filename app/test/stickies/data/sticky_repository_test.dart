// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/stickies/data/sticky_repository.dart';
import 'package:tephra/stickies/model/sticky_color.dart';
import 'package:tephra/stickies/model/sticky_frontmatter.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../fakes.dart';

void main() {
  group('StickyRepository', () {
    late MemoryVaultFileSystem fs;
    late FakeSearchEngine search;
    late FakeOpenNoteBridge openNotes;
    late Clock clock;
    late StickyRepository repo;

    setUp(() {
      fs = MemoryVaultFileSystem();
      search = FakeSearchEngine(fs);
      openNotes = FakeOpenNoteBridge();
      clock = ManualClock(DateTime(2026, 10, 11, 9, 30, 5));
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
    });

    tearDown(() async {
      await repo.dispose();
      openNotes.dispose();
    });

    test('loads only real stickies', () async {
      // 1. Real sticky
      await fs.writeText(
        VaultPath('Note1.md'),
        TextDocument(text: '---\ntephra-sticky: true\n---\nHello'),
      );
      // 2. tephra-sticky: false
      await fs.writeText(
        VaultPath('Note2.md'),
        TextDocument(text: '---\ntephra-sticky: false\n---\nWorld'),
      );
      // 3. Normal note
      await fs.writeText(
        VaultPath('Note3.md'),
        TextDocument(text: 'Just regular text'),
      );

      await repo.start();

      expect(repo.all.length, 1);
      expect(repo.all.first.path.value, 'Note1.md');
      expect(repo.archived, isEmpty);
    });

    test('archive folder is separate', () async {
      await fs.writeText(
        VaultPath('Stickies/Archive/OldSticky.md'),
        TextDocument(text: '---\ntephra-sticky: true\n---\nOld note'),
      );

      await repo.start();

      expect(repo.all, isEmpty);
      expect(repo.archived.length, 1);
      expect(repo.archived.first.path.value, 'Stickies/Archive/OldSticky.md');
    });

    test('create writes file and emits StickyAdded', () async {
      await repo.start();

      final changes = <StickyChange>[];
      final sub = repo.changes.listen(changes.add);

      final sticky = await repo.create();

      expect(sticky.path.value, 'Stickies/Sticky 2026-10-11 093005.md');
      expect(
        sticky.text,
        '---\ntephra-sticky: true\nsticky-color: yellow\n---\n',
      );

      final fileDoc = await fs.readText(sticky.path);
      expect(
        fileDoc.text,
        '---\ntephra-sticky: true\nsticky-color: yellow\n---\n',
      );

      expect(changes.length, 1);
      expect(changes.first, isA<StickyAdded>());
      expect((changes.first as StickyAdded).path, sticky.path);

      await sub.cancel();
    });

    test('patch colour through open document', () async {
      final path = VaultPath('Stickies/Open.md');
      const initialText =
          '---\ntephra-sticky: true\nsticky-color: yellow\n---\nBody\n';
      await fs.writeText(path, TextDocument(text: initialText));

      await repo.start();

      // Open the note in the bridge
      openNotes.openNotes[path] = initialText;

      await repo.patch(path, const StickyPatch(color: NamedStickyColor.pink));

      // openNotes.applyText was called
      expect(openNotes.appliedTexts.length, 1);
      expect(openNotes.appliedTexts.first.$1, path);
      expect(
        openNotes.appliedTexts.first.$2,
        '---\ntephra-sticky: true\nsticky-color: pink\n---\nBody\n',
      );

      // File on disk was NOT written by the repository
      final diskDoc = await fs.readText(path);
      expect(diskDoc.text, initialText);

      // Repository reflects the updated color
      expect(repo.byPath(path)?.meta.color, NamedStickyColor.pink);
    });

    test('patch on closed note writes file', () async {
      final path = VaultPath('Stickies/Closed.md');
      const initialText =
          '---\ntephra-sticky: true\nsticky-color: yellow\n---\nBody\n';
      await fs.writeText(path, TextDocument(text: initialText));

      await repo.start();

      await repo.patch(path, const StickyPatch(color: NamedStickyColor.blue));

      expect(openNotes.appliedTexts, isEmpty);

      final diskDoc = await fs.readText(path);
      expect(
        diskDoc.text,
        '---\ntephra-sticky: true\nsticky-color: blue\n---\nBody\n',
      );
      expect(repo.byPath(path)?.meta.color, NamedStickyColor.blue);
    });

    test('unpin emits StickyRemoved and keeps body', () async {
      final path = VaultPath('Stickies/ToUnpin.md');
      const initialText = '---\ntephra-sticky: true\n---\nNote body content\n';
      await fs.writeText(path, TextDocument(text: initialText));

      await repo.start();
      expect(repo.all.length, 1);

      final changes = <StickyChange>[];
      final sub = repo.changes.listen(changes.add);

      await repo.patch(path, const StickyPatch(removeAll: true));
      await pumpEventQueue();

      expect(changes.length, 1);
      expect(changes.first, isA<StickyRemoved>());
      expect(repo.all, isEmpty);

      final diskDoc = await fs.readText(path);
      expect(diskDoc.text, 'Note body content\n');

      await sub.cancel();
    });

    test('external edit emits StickyUpdated', () async {
      final path = VaultPath('Stickies/External.md');
      const initialText = '---\ntephra-sticky: true\n---\nInitial\n';
      await fs.writeText(path, TextDocument(text: initialText));

      await repo.start();

      final changes = <StickyChange>[];
      final sub = repo.changes.listen(changes.add);

      const updatedText =
          '---\ntephra-sticky: true\n---\nUpdated from outside\n';
      await fs.writeText(path, TextDocument(text: updatedText));
      fs.emit(FileModified(path));
      await pumpEventQueue();

      expect(changes.length, 1);
      expect(changes.first, isA<StickyUpdated>());
      final updated = changes.first as StickyUpdated;
      expect(updated.sticky.text, updatedText);

      await sub.cancel();
    });

    test('deleted file emits StickyRemoved', () async {
      final path = VaultPath('Stickies/ToDelete.md');
      const initialText = '---\ntephra-sticky: true\n---\nGoodbye\n';
      await fs.writeText(path, TextDocument(text: initialText));

      await repo.start();
      expect(repo.all.length, 1);

      final changes = <StickyChange>[];
      final sub = repo.changes.listen(changes.add);

      await fs.delete(path);
      fs.emit(FileDeleted(path));
      await pumpEventQueue();

      expect(changes.length, 1);
      expect(changes.first, isA<StickyRemoved>());
      expect(repo.all, isEmpty);

      await sub.cancel();
    });
  });
}
