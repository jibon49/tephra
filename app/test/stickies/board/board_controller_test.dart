// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/core/providers.dart';
import 'package:tephra/settings/vault_settings.dart';
import 'package:tephra/stickies/board/board_controller.dart';
import 'package:tephra/stickies/board/canvas_document.dart';
import 'package:tephra/stickies/data/sticky_repository.dart';
import 'package:tephra/stickies/providers.dart';
import 'package:tephra/vault/providers.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../fakes.dart';

class WriteTrackingFs implements VaultFileSystem {
  WriteTrackingFs(this._delegate);

  final VaultFileSystem _delegate;
  int writeCount = 0;

  @override
  String get rootDisplayPath => _delegate.rootDisplayPath;

  @override
  Future<List<VaultEntry>> list({
    VaultPath folder = VaultPath.root,
    bool recursive = true,
  }) => _delegate.list(folder: folder, recursive: recursive);

  @override
  Future<VaultEntry?> stat(VaultPath path) => _delegate.stat(path);

  @override
  Future<List<int>> readBytes(VaultPath path) => _delegate.readBytes(path);

  @override
  Future<TextDocument> readText(VaultPath path) => _delegate.readText(path);

  @override
  Future<void> writeBytes(VaultPath path, List<int> bytes) {
    writeCount++;
    return _delegate.writeBytes(path, bytes);
  }

  @override
  Future<void> writeText(VaultPath path, TextDocument doc) {
    writeCount++;
    return _delegate.writeText(path, doc);
  }

  @override
  Future<void> createFolder(VaultPath path) => _delegate.createFolder(path);

  @override
  Future<void> move(VaultPath from, VaultPath to) => _delegate.move(from, to);

  @override
  Future<void> delete(
    VaultPath path, {
    TrashMode mode = TrashMode.vaultTrash,
  }) => _delegate.delete(path, mode: mode);

  @override
  Stream<VaultChange> watch() => _delegate.watch();

  @override
  Future<void> dispose() => _delegate.dispose();
}

void main() {
  late MemoryVaultFileSystem fs;
  late FakeSearchEngine search;
  late FakeOpenNoteBridge openNotes;
  late ManualClock clock;
  late StickyRepository repository;

  setUp(() async {
    fs = MemoryVaultFileSystem();
    search = FakeSearchEngine(fs);
    openNotes = FakeOpenNoteBridge();
    clock = ManualClock(DateTime(2026, 10, 11, 9, 30, 5));

    repository = StickyRepository(
      fs: fs,
      search: search,
      settings: const StickySettingsView(),
      openNotes: openNotes,
      clock: clock,
    );
    await repository.start();
  });

  tearDown(() async {
    await repository.dispose();
  });

  ProviderContainer makeContainer({Random? random}) {
    return ProviderContainer(
      overrides: [
        vaultFsProvider.overrideWithValue(fs),
        stickyRepositoryProvider.overrideWithValue(repository),
        clockProvider.overrideWithValue(clock),
        if (random != null)
          boardControllerProvider.overrideWith(
            () => BoardController(
              fs: fs,
              repository: repository,
              settings: const VaultSettings(),
              clock: clock,
              random: random,
            ),
          ),
      ],
    );
  }

  group('BoardController', () {
    test('load creates board file on first change', () async {
      await repository.create(body: 'First sticky');

      final container = makeContainer(random: Random(42));
      addTearDown(container.dispose);

      final controller = container.read(boardControllerProvider.notifier);
      await controller.start();
      await controller.flush();

      final boardPath = VaultPath('Stickies/Sticky board.canvas');
      expect((await fs.stat(boardPath)) != null, isTrue);

      final bytes = await fs.readBytes(boardPath);
      final doc = CanvasDocument.parse(utf8.decode(bytes));
      expect(doc.nodes, hasLength(1));
    });

    test('does not save when nothing changed', () async {
      await repository.create(body: 'First sticky');

      // First run creates board
      final container1 = makeContainer(random: Random(42));
      final controller1 = container1.read(boardControllerProvider.notifier);
      await controller1.start();
      await controller1.flush();
      container1.dispose();

      // Second run: board already matches current stickies
      final trackingFs = WriteTrackingFs(fs);
      final container2 = ProviderContainer(
        overrides: [
          vaultFsProvider.overrideWithValue(trackingFs),
          stickyRepositoryProvider.overrideWithValue(repository),
          clockProvider.overrideWithValue(clock),
          boardControllerProvider.overrideWith(
            () => BoardController(
              fs: trackingFs,
              repository: repository,
              settings: const VaultSettings(),
              clock: clock,
              random: Random(42),
            ),
          ),
        ],
      );
      addTearDown(container2.dispose);

      final controller2 = container2.read(boardControllerProvider.notifier);
      await controller2.start();
      await controller2.flush();

      expect(trackingFs.writeCount, 0);
    });

    test('broken board file is never overwritten', () async {
      final boardPath = VaultPath('Stickies/Sticky board.canvas');
      await fs.writeText(boardPath, const TextDocument(text: '{ broken json '));

      final container = makeContainer(random: Random(42));
      addTearDown(container.dispose);

      final controller = container.read(boardControllerProvider.notifier);
      await controller.start();

      final state = container.read(boardControllerProvider);
      expect(state.isBroken, isTrue);

      await controller.flush();

      final currentText = (await fs.readText(boardPath)).text;
      expect(currentText, '{ broken json ');
    });

    test('drag end saves once after debounce', () async {
      final sticky = await repository.create(body: 'Test note');

      fakeAsync((async) {
        final initialDoc = CanvasDocument(
          nodes: [
            CanvasNode(
              id: 'n1',
              type: 'file',
              file: sticky.path.value,
              x: 0,
              y: 0,
              width: 260,
              height: 220,
            ),
          ],
          edges: [],
        );
        fs.writeText(
          VaultPath('Stickies/Sticky board.canvas'),
          TextDocument(text: initialDoc.encode()),
        );

        final trackingFs = WriteTrackingFs(fs);
        final container = ProviderContainer(
          overrides: [
            vaultFsProvider.overrideWithValue(trackingFs),
            stickyRepositoryProvider.overrideWithValue(repository),
            clockProvider.overrideWithValue(clock),
            boardControllerProvider.overrideWith(
              () => BoardController(
                fs: trackingFs,
                repository: repository,
                settings: const VaultSettings(),
                clock: clock,
                random: Random(42),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(boardControllerProvider.notifier);
        controller.start();
        async.elapse(const Duration(milliseconds: 100));

        trackingFs.writeCount = 0;

        controller.updateNodePosition('n1', const Offset(400, 300));
        async.flushMicrotasks();
        expect(trackingFs.writeCount, 0);

        // Elapse 500ms (not yet 1000ms debounce)
        async.elapse(const Duration(milliseconds: 500));
        expect(trackingFs.writeCount, 0);

        // Elapse remaining 600ms (total 1100ms > 1000ms)
        async.elapse(const Duration(milliseconds: 600));
        expect(trackingFs.writeCount, 1);

        var saved = '';
        fs
            .readText(VaultPath('Stickies/Sticky board.canvas'))
            .then((d) => saved = d.text);
        async.flushMicrotasks();
        expect(saved, contains('"x": 400'));
        expect(saved, contains('"y": 300'));
      });
    });

    test('sticky added elsewhere appears', () async {
      final container = makeContainer(random: Random(42));
      addTearDown(container.dispose);

      final controller = container.read(boardControllerProvider.notifier);
      await controller.start();

      expect(container.read(boardControllerProvider).doc.nodes, isEmpty);

      // Create sticky through repository
      final sticky = await repository.create(body: 'External sticky');
      await controller.flush();

      final nodes = container.read(boardControllerProvider).doc.nodes;
      expect(nodes, hasLength(1));
      expect(nodes.first.file, sticky.path.value);
    });
  });
}
