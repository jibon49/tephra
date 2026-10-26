// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/stickies/data/sticky_positions_store.dart';
import 'package:tephra/stickies/data/sticky_repository.dart';
import 'package:tephra/stickies/model/sticky_color.dart';
import 'package:tephra/stickies/model/sticky_frontmatter.dart';
import 'package:tephra/stickies/windows/sticky_hub.dart';
import 'package:tephra/stickies/windows/sticky_protocol.dart';
import 'package:tephra/stickies/windows/text_merger.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../fakes.dart';
import 'fake_window_bus.dart';

void main() {
  group('StickyHub', () {
    late MemoryVaultFileSystem fs;
    late FakeSearchEngine search;
    late FakeOpenNoteBridge openNotes;
    late Clock clock;
    late StickyRepository repo;
    late StickyPositionsStore positions;
    late FakeWindowNetwork network;
    late FakeWindowBus mainBus;
    late StickyHub hub;

    setUp(() async {
      fs = MemoryVaultFileSystem();
      search = FakeSearchEngine(fs);
      openNotes = FakeOpenNoteBridge();
      clock = ManualClock(DateTime(2026, 10, 11, 10, 0, 0));
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
      positions = StickyPositionsStore(fs: fs, deviceId: 'desktop_test');
      network = FakeWindowNetwork();
      mainBus = network.createBus('main');

      hub = StickyHub(
        bus: mainBus,
        repo: repo,
        openNotes: openNotes,
        merger: const SyncTextMerger(),
        positions: positions,
        conflictNamer: (path) => VaultPath(
          '${path.parent != null ? '${path.parent!.value}/' : ''}${path.stem} (conflict).md',
        ),
        clock: clock,
      );

      await repo.start();
      await positions.load();
      await hub.start();
    });

    tearDown(() async {
      await hub.dispose();
      await mainBus.dispose();
      await repo.dispose();
      openNotes.dispose();
    });

    test('ready is answered with open', () async {
      final sticky = await repo.create(
        body: 'Hello sticky',
        color: NamedStickyColor.yellow,
      );
      final path = sticky.path;

      await hub.open(path);
      expect(hub.openPaths, contains(path));

      final winId = network.openWindowIds.firstWhere((id) => id != 'main');
      final stickyBus = network.busFor(winId)!;

      final receivedBySticky = <StickyMessage>[];
      final completer = Completer<void>();
      stickyBus.incoming.listen((event) {
        receivedBySticky.add(event.$2);
        completer.complete();
      });

      await stickyBus.send('main', ReadyMessage(path: path.value));
      await completer.future;

      expect(receivedBySticky.length, 1);
      final msg = receivedBySticky.first;
      expect(msg, isA<OpenMessage>());
      final openMsg = msg as OpenMessage;
      expect(openMsg.path, path.value);
      expect(openMsg.text, contains('Hello sticky'));
      expect(openMsg.color, 'yellow');
      expect(openMsg.pinned, isFalse);
    });

    test('edit in sticky writes once and broadcasts update', () async {
      final sticky = await repo.create(body: 'Original text');
      final path = sticky.path;
      await hub.open(path);

      final winId = network.openWindowIds.firstWhere((id) => id != 'main');
      final stickyBus = network.busFor(winId)!;

      final openCompleter = Completer<OpenMessage>();
      final updateCompleter = Completer<UpdateMessage>();

      stickyBus.incoming.listen((event) {
        final m = event.$2;
        if (m is OpenMessage) {
          openCompleter.complete(m);
        } else if (m is UpdateMessage) {
          updateCompleter.complete(m);
        }
      });

      await stickyBus.send('main', ReadyMessage(path: path.value));
      final openMsg = await openCompleter.future;

      // Sticky sends edited content
      final newText = openMsg.text.replaceFirst('Original text', 'Edited text');
      await stickyBus.send(
        'main',
        ContentChangedMessage(
          path: path.value,
          text: newText,
          baseHash: openMsg.hash,
        ),
      );

      final updateMsg = await updateCompleter.future;
      expect(updateMsg.text, newText);
      expect(updateMsg.hash, StickyHub.hashProtocolText(newText));

      final onDisk = await fs.readText(path);
      expect(onDisk.text, newText);
    });

    test('edit while note open in main tab goes through openNotes', () async {
      final sticky = await repo.create(body: 'Tab buffer test');
      final path = sticky.path;

      openNotes.openNotes[path] = sticky.text;
      await hub.open(path);

      final winId = network.openWindowIds.firstWhere((id) => id != 'main');
      final stickyBus = network.busFor(winId)!;

      final openCompleter = Completer<OpenMessage>();
      final updateCompleter = Completer<UpdateMessage>();
      stickyBus.incoming.listen((event) {
        final m = event.$2;
        if (m is OpenMessage) openCompleter.complete(m);
        if (m is UpdateMessage) updateCompleter.complete(m);
      });

      await stickyBus.send('main', ReadyMessage(path: path.value));
      final openMsg = await openCompleter.future;

      final newText = openMsg.text.replaceFirst(
        'Tab buffer test',
        'Tab buffer updated',
      );
      await stickyBus.send(
        'main',
        ContentChangedMessage(
          path: path.value,
          text: newText,
          baseHash: openMsg.hash,
        ),
      );

      await updateCompleter.future;

      expect(openNotes.appliedTexts, contains((path, newText)));
    });

    test('main tab edit reaches window', () async {
      final sticky = await repo.create(body: 'Initial content');
      final path = sticky.path;
      await hub.open(path);

      final winId = network.openWindowIds.firstWhere((id) => id != 'main');
      final stickyBus = network.busFor(winId)!;

      final openCompleter = Completer<OpenMessage>();
      final updateCompleter = Completer<UpdateMessage>();
      stickyBus.incoming.listen((event) {
        final m = event.$2;
        if (m is OpenMessage) openCompleter.complete(m);
        if (m is UpdateMessage) updateCompleter.complete(m);
      });

      await stickyBus.send('main', ReadyMessage(path: path.value));
      await openCompleter.future;

      // Edit inside main tab
      final tabText = sticky.text.replaceFirst(
        'Initial content',
        'Edited inside tab',
      );
      openNotes.openNotes[path] = tabText;
      openNotes.emitEdited(path);

      final updateMsg = await updateCompleter.future;
      expect(updateMsg.text, tabText);
    });

    test('concurrent edits merge', () async {
      final sticky = await repo.create(body: 'a\nb\nc\n');
      final path = sticky.path;
      await hub.open(path);

      final winId = network.openWindowIds.firstWhere((id) => id != 'main');
      final stickyBus = network.busFor(winId)!;

      final openCompleter = Completer<OpenMessage>();
      final mergeDone = Completer<void>();
      final updateMessages = <UpdateMessage>[];

      stickyBus.incoming.listen((event) {
        final m = event.$2;
        if (m is OpenMessage) openCompleter.complete(m);
        if (m is UpdateMessage) {
          updateMessages.add(m);
          if (m.text.contains('C\n')) {
            if (!mergeDone.isCompleted) mergeDone.complete();
          }
        }
      });

      await stickyBus.send('main', ReadyMessage(path: path.value));
      final openMsg = await openCompleter.future;

      // Main tab changes line 1
      final mainText = openMsg.text.replaceFirst('a\n', 'A\n');
      await repo.setText(path, mainText);

      // Sticky changes line 3 using the baseHash before main's edit
      final stickyText = openMsg.text.replaceFirst('c\n', 'C\n');
      await stickyBus.send(
        'main',
        ContentChangedMessage(
          path: path.value,
          text: stickyText,
          baseHash: openMsg.hash,
        ),
      );

      await mergeDone.future;

      expect(updateMessages.last.text, contains('A\nb\nC\n'));
      final onDisk = await fs.readText(path);
      expect(onDisk.text, contains('A\nb\nC\n'));
    });

    test('conflicting edits keep both', () async {
      final sticky = await repo.create(body: 'line 1\nline 2\nline 3\n');
      final path = sticky.path;
      await hub.open(path);

      final winId = network.openWindowIds.firstWhere((id) => id != 'main');
      final stickyBus = network.busFor(winId)!;

      final openCompleter = Completer<OpenMessage>();
      final conflictDone = Completer<void>();
      final updateMessages = <UpdateMessage>[];

      stickyBus.incoming.listen((event) {
        final m = event.$2;
        if (m is OpenMessage) openCompleter.complete(m);
        if (m is UpdateMessage) {
          updateMessages.add(m);
          if (m.text.contains('sticky edit')) {
            if (!conflictDone.isCompleted) conflictDone.complete();
          }
        }
      });

      await stickyBus.send('main', ReadyMessage(path: path.value));
      final openMsg = await openCompleter.future;

      // Main tab changes line 2
      final mainText = openMsg.text.replaceFirst('line 2', 'main edit');
      await repo.setText(path, mainText);

      // Sticky changes line 2 as well with stale baseHash
      final stickyText = openMsg.text.replaceFirst('line 2', 'sticky edit');
      await stickyBus.send(
        'main',
        ContentChangedMessage(
          path: path.value,
          text: stickyText,
          baseHash: openMsg.hash,
        ),
      );

      await conflictDone.future;

      // Sticky wins in main note
      final mainNote = await fs.readText(path);
      expect(mainNote.text, contains('sticky edit'));

      // Conflict copy preserves main's version
      final conflictPath = VaultPath('Stickies/${path.stem} (conflict).md');
      expect(await fs.stat(conflictPath), isNotNull);
      final conflictDoc = await fs.readText(conflictPath);
      expect(conflictDoc.text, contains('main edit'));
    });

    test('unknown base hash keeps both', () async {
      final sticky = await repo.create(body: 'Current body');
      final path = sticky.path;
      await hub.open(path);

      final winId = network.openWindowIds.firstWhere((id) => id != 'main');
      final stickyBus = network.busFor(winId)!;

      final updateCompleter = Completer<UpdateMessage>();
      stickyBus.incoming.listen((event) {
        final m = event.$2;
        if (m is UpdateMessage) updateCompleter.complete(m);
      });

      await stickyBus.send(
        'main',
        ContentChangedMessage(
          path: path.value,
          text: 'Unknown base text',
          baseHash: 'completely_unknown_hash',
        ),
      );

      await updateCompleter.future;

      final mainNote = await fs.readText(path);
      expect(mainNote.text, 'Unknown base text');

      final conflictPath = VaultPath('Stickies/${path.stem} (conflict).md');
      expect(await fs.stat(conflictPath), isNotNull);
      final conflictDoc = await fs.readText(conflictPath);
      expect(conflictDoc.text, contains('Current body'));
    });

    test('save answers saved after pending edits', () async {
      final sticky = await repo.create(body: 'Save sequence');
      final path = sticky.path;
      await hub.open(path);

      final winId = network.openWindowIds.firstWhere((id) => id != 'main');
      final stickyBus = network.busFor(winId)!;

      final openCompleter = Completer<OpenMessage>();
      final savedCompleter = Completer<SavedMessage>();
      stickyBus.incoming.listen((event) {
        final m = event.$2;
        if (m is OpenMessage) openCompleter.complete(m);
        if (m is SavedMessage) savedCompleter.complete(m);
      });

      await stickyBus.send('main', ReadyMessage(path: path.value));
      final openMsg = await openCompleter.future;

      final edit1 = openMsg.text.replaceFirst('Save sequence', 'Edit 1');
      final edit2 = openMsg.text.replaceFirst('Save sequence', 'Edit 2');

      await stickyBus.send(
        'main',
        ContentChangedMessage(
          path: path.value,
          text: edit1,
          baseHash: openMsg.hash,
        ),
      );
      await stickyBus.send(
        'main',
        ContentChangedMessage(
          path: path.value,
          text: edit2,
          baseHash: StickyHub.hashProtocolText(edit1),
        ),
      );
      await stickyBus.send('main', SaveMessage(path: path.value));

      final saved = await savedCompleter.future;
      expect(saved.hash, StickyHub.hashProtocolText(edit2));
      final onDisk = await fs.readText(path);
      expect(onDisk.text, edit2);
    });

    test('one window per path', () async {
      final sticky = await repo.create(body: 'Single window');
      final path = sticky.path;

      await hub.open(path);
      await hub.open(path);

      expect(network.openWindowIds.length, 2); // 'main' and 1 sticky
    });

    test('unpin closes window', () async {
      final sticky = await repo.create(body: 'Unpin note');
      final path = sticky.path;
      await hub.open(path);

      final winId = network.openWindowIds.firstWhere((id) => id != 'main');
      final stickyBus = network.busFor(winId)!;

      final closeReqCompleter = Completer<CloseRequestMessage>();
      stickyBus.incoming.listen((event) {
        final m = event.$2;
        if (m is CloseRequestMessage) closeReqCompleter.complete(m);
      });

      // Patch sticky to unpin
      await repo.patch(path, const StickyPatch(sticky: false));

      final req = await closeReqCompleter.future;
      expect(req.reason, 'unpinned');
    });

    test('rename reopens window', () async {
      final sticky = await repo.create(body: 'Rename note');
      final pathA = sticky.path;
      await hub.open(pathA);

      final winIdA = network.openWindowIds.firstWhere((id) => id != 'main');
      final stickyBusA = network.busFor(winIdA)!;

      final closeReqCompleter = Completer<CloseRequestMessage>();
      stickyBusA.incoming.listen((event) {
        final m = event.$2;
        if (m is CloseRequestMessage) closeReqCompleter.complete(m);
      });

      final pathB = VaultPath('Stickies/Renamed.md');
      await fs.move(pathA, pathB);
      fs.emit(FileMoved(pathB, from: pathA));

      final req = await closeReqCompleter.future;
      expect(req.reason, 'unpinned');

      for (var i = 0; i < 20 && !hub.openPaths.contains(pathB); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      // Check hub opened window for pathB
      expect(hub.openPaths, contains(pathB));
    });

    test('window gone is tolerated', () async {
      final sticky = await repo.create(body: 'Gone window note');
      final path = sticky.path;
      await hub.open(path);

      final winId = network.openWindowIds.firstWhere((id) => id != 'main');

      // Close fake window (simulating crash or quit)
      network.close(winId);

      // Repo change should not throw WindowGoneException
      await repo.setText(path, 'Changed after window gone');
    });
  });
}
