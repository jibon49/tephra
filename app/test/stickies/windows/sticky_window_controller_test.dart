// © 2026 Tephra. All rights reserved.

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/stickies/windows/sticky_protocol.dart';
import 'package:tephra/stickies/windows/sticky_window_controller.dart';

import 'fake_window_bus.dart';

void main() {
  group('StickyWindowController', () {
    late FakeWindowNetwork network;
    late FakeWindowBus mainBus;
    late FakeWindowBus stickyBus;

    setUp(() {
      network = FakeWindowNetwork();
      mainBus = network.createBus('main');
      stickyBus = network.createBus('sticky_1');
    });

    tearDown(() async {
      await mainBus.dispose();
      await stickyBus.dispose();
    });

    test('debounces typing into one contentChanged', () {
      fakeAsync((async) {
        final controller = StickyWindowController(
          bus: stickyBus,
          mainWindowId: 'main',
          path: 'Stickies/test.md',
        );
        controller.start();
        async.flushMicrotasks();

        final receivedMessages = <StickyMessage>[];
        mainBus.incoming.listen((event) {
          receivedMessages.add(event.$2);
        });

        // Simulate initial open
        mainBus.send(
          'sticky_1',
          const OpenMessage(
            path: 'Stickies/test.md',
            text: 'Initial',
            hash: 'hash_init',
            color: 'yellow',
            pinned: false,
            locked: false,
            collapsed: false,
            title: 'test',
          ),
        );
        async.flushMicrotasks();
        receivedMessages.clear();

        controller.onTextChanged('Typing 1');
        async.elapse(const Duration(milliseconds: 200));
        controller.onTextChanged('Typing 2');
        async.elapse(const Duration(milliseconds: 200));
        controller.onTextChanged('Typing 3');

        // Before 500 ms debounce finishes
        async.elapse(const Duration(milliseconds: 300));
        expect(receivedMessages, isEmpty);

        // After full 500 ms passes
        async.elapse(const Duration(milliseconds: 300));
        async.flushMicrotasks();

        expect(receivedMessages.length, 1);
        final msg = receivedMessages.first;
        expect(msg, isA<ContentChangedMessage>());
        final contentMsg = msg as ContentChangedMessage;
        expect(contentMsg.text, 'Typing 3');
        expect(contentMsg.baseHash, 'hash_init');
        expect(controller.dirty, isFalse);

        controller.dispose();
      });
    });

    test('update while clean replaces text', () {
      fakeAsync((async) {
        final controller = StickyWindowController(
          bus: stickyBus,
          mainWindowId: 'main',
          path: 'Stickies/test.md',
        );
        controller.start();
        async.flushMicrotasks();

        mainBus.send(
          'sticky_1',
          const OpenMessage(
            path: 'Stickies/test.md',
            text: 'Hello',
            hash: 'h1',
            color: 'yellow',
            pinned: false,
            locked: false,
            collapsed: false,
            title: 'test',
          ),
        );
        async.flushMicrotasks();

        expect(controller.localText, 'Hello');

        mainBus.send(
          'sticky_1',
          const UpdateMessage(
            path: 'Stickies/test.md',
            text: 'Updated remote',
            hash: 'h2',
            color: 'pink',
            pinned: true,
            locked: false,
            title: 'test',
          ),
        );
        async.flushMicrotasks();

        expect(controller.localText, 'Updated remote');
        expect(controller.color, 'pink');
        expect(controller.pinned, isTrue);

        controller.dispose();
      });
    });

    test('update while dirty keeps local text and resends with new base', () {
      fakeAsync((async) {
        final controller = StickyWindowController(
          bus: stickyBus,
          mainWindowId: 'main',
          path: 'Stickies/test.md',
        );
        controller.start();
        async.flushMicrotasks();

        final receivedByMain = <StickyMessage>[];
        mainBus.incoming.listen((event) {
          receivedByMain.add(event.$2);
        });

        mainBus.send(
          'sticky_1',
          const OpenMessage(
            path: 'Stickies/test.md',
            text: 'Initial text',
            hash: 'h_initial',
            color: 'yellow',
            pinned: false,
            locked: false,
            collapsed: false,
            title: 'test',
          ),
        );
        async.flushMicrotasks();
        receivedByMain.clear();

        // User edits locally
        controller.onTextChanged('Local edits in progress');
        expect(controller.dirty, isTrue);

        // Remote update arrives before debounce completes
        mainBus.send(
          'sticky_1',
          const UpdateMessage(
            path: 'Stickies/test.md',
            text: 'Remote arrived meanwhile',
            hash: 'h_remote_new',
            color: 'yellow',
            pinned: false,
            locked: false,
            title: 'test',
          ),
        );
        async.flushMicrotasks();

        // Local text is kept, base hash is updated to h_remote_new
        expect(controller.localText, 'Local edits in progress');
        expect(controller.appliedHash, 'h_remote_new');

        // Let debounce elapse
        async.elapse(const Duration(milliseconds: 600));
        async.flushMicrotasks();

        expect(receivedByMain.length, 1);
        final sent = receivedByMain.first as ContentChangedMessage;
        expect(sent.text, 'Local edits in progress');
        expect(sent.baseHash, 'h_remote_new');

        controller.dispose();
      });
    });

    test('close waits for saved', () async {
      var closed = false;
      final controller = StickyWindowController(
        bus: stickyBus,
        mainWindowId: 'main',
        path: 'Stickies/test.md',
        onCloseWindow: () async {
          closed = true;
        },
      );
      await controller.start();

      final sentToMain = <StickyMessage>[];
      mainBus.incoming.listen((event) async {
        final msg = event.$2;
        sentToMain.add(msg);
        if (msg is SaveMessage) {
          // Reply with SavedMessage after a slight delay
          await Future<void>.delayed(const Duration(milliseconds: 10));
          await mainBus.send(
            'sticky_1',
            const SavedMessage(path: 'Stickies/test.md', hash: 'saved_hash'),
          );
        }
      });

      await controller.requestClose();

      expect(closed, isTrue);
      expect(
        sentToMain.map((m) => m.runtimeType),
        containsAllInOrder([SaveMessage, CloseMessage]),
      );

      controller.dispose();
    });

    test('locked blocks editing', () {
      fakeAsync((async) {
        final controller = StickyWindowController(
          bus: stickyBus,
          mainWindowId: 'main',
          path: 'Stickies/test.md',
        );
        controller.start();
        async.flushMicrotasks();

        mainBus.send(
          'sticky_1',
          const OpenMessage(
            path: 'Stickies/test.md',
            text: '- [ ] Task 1',
            hash: 'h1',
            color: 'yellow',
            pinned: false,
            locked: true,
            collapsed: false,
            title: 'test',
          ),
        );
        async.flushMicrotasks();

        expect(controller.locked, isTrue);

        controller.onTextChanged('attempt to edit');
        expect(controller.localText, '- [ ] Task 1');
        expect(controller.dirty, isFalse);

        controller.toggleTask(0);
        expect(controller.localText, '- [ ] Task 1');
        expect(controller.dirty, isFalse);

        controller.dispose();
      });
    });
  });
}
