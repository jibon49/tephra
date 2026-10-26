// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/stickies/windows/sticky_protocol.dart';
import 'package:tephra/stickies/windows/window_bus.dart';

import 'fake_window_bus.dart';

void main() {
  group('StickyWindowArgs', () {
    test('encode/decode round trip', () {
      const args = StickyWindowArgs(
        mainWindowId: 'main_win_42',
        path: 'Stickies/Sticky 1.md',
        protocolVersion: 1,
      );
      final raw = args.encode();
      final decoded = StickyWindowArgs.tryDecode(raw);
      expect(decoded, isNotNull);
      expect(decoded, equals(args));
      expect(decoded?.mainWindowId, 'main_win_42');
      expect(decoded?.path, 'Stickies/Sticky 1.md');
      expect(decoded?.protocolVersion, 1);
    });

    test('main window args empty or whitespace decode to null', () {
      expect(StickyWindowArgs.tryDecode(''), isNull);
      expect(StickyWindowArgs.tryDecode('   '), isNull);
    });

    test('invalid json or unexpected format decodes to null', () {
      expect(StickyWindowArgs.tryDecode('not json'), isNull);
      expect(StickyWindowArgs.tryDecode('123'), isNull);
      expect(StickyWindowArgs.tryDecode('{"kind":"other"}'), isNull);
      expect(StickyWindowArgs.tryDecode('{"kind":"tephra-sticky"}'), isNull);
      expect(
        StickyWindowArgs.tryDecode(
          '{"kind":"tephra-sticky","v":"bad","main":"m","path":"p"}',
        ),
        isNull,
      );
    });
  });

  group('StickyMessage protocol v1', () {
    test('every message round-trips through JSON', () {
      final messages = <StickyMessage>[
        const ReadyMessage(path: 'Stickies/test.md'),
        const OpenMessage(
          path: 'Stickies/test.md',
          text: 'Hello world',
          hash: 'hash123',
          color: 'yellow',
          pinned: true,
          locked: false,
          collapsed: false,
          title: 'test',
        ),
        const UpdateMessage(
          path: 'Stickies/test.md',
          text: 'Updated world',
          hash: 'hash456',
          color: 'pink',
          pinned: false,
          locked: true,
          title: 'test',
        ),
        const ContentChangedMessage(
          path: 'Stickies/test.md',
          text: 'Edited text',
          baseHash: 'hash123',
        ),
        const SaveMessage(path: 'Stickies/test.md'),
        const SavedMessage(path: 'Stickies/test.md', hash: 'hash999'),
        const SetColorMessage(path: 'Stickies/test.md', color: 'blue'),
        const SetPinnedMessage(path: 'Stickies/test.md', pinned: true),
        const SetLockedMessage(path: 'Stickies/test.md', locked: false),
        const PositionChangedMessage(
          path: 'Stickies/test.md',
          x: 100,
          y: 200,
          w: 320,
          h: 240,
          screen: 'primary',
          collapsed: false,
        ),
        const CloseMessage(path: 'Stickies/test.md'),
        const CloseRequestMessage(path: 'Stickies/test.md', reason: 'hideAll'),
        const OpenInMainMessage(path: 'Stickies/test.md'),
        const NewStickyMessage(),
      ];

      expect(messages.length, 14);

      for (final msg in messages) {
        final json = msg.toJson();
        expect(json['v'], equals(kStickyProtocolVersion));
        expect(json['type'], isA<String>());

        final roundTripped = StickyMessage.fromJson(json);
        expect(
          roundTripped,
          isNotNull,
          reason: 'Failed for ${msg.runtimeType}',
        );
        expect(roundTripped, equals(msg));
      }
    });

    test('unknown type returns null', () {
      final json = {
        'v': kStickyProtocolVersion,
        'type': 'futureMessageTypeUnknown',
        'foo': 'bar',
      };
      expect(StickyMessage.fromJson(json), isNull);
    });

    test('wrong version returns null', () {
      final json = {'v': 999, 'type': 'ready', 'path': 'Stickies/test.md'};
      expect(StickyMessage.fromJson(json), isNull);
    });

    test('missing field returns null without throwing', () {
      expect(
        StickyMessage.fromJson({'v': kStickyProtocolVersion, 'type': 'ready'}),
        isNull,
      );

      expect(
        StickyMessage.fromJson({
          'v': kStickyProtocolVersion,
          'type': 'open',
          'path': 'Stickies/test.md',
          // missing text, hash, color, etc.
        }),
        isNull,
      );

      expect(
        StickyMessage.fromJson({
          'v': kStickyProtocolVersion,
          'type': 'positionChanged',
          'path': 'Stickies/test.md',
          'x': 'invalid_string_not_num',
          'y': 10,
          'w': 20,
          'h': 30,
          'screen': 's1',
          'collapsed': false,
        }),
        isNull,
      );
    });
  });

  group('FakeWindowBus', () {
    test('delivers in order asynchronously via microtasks', () async {
      final network = FakeWindowNetwork();
      final mainBus = network.createBus('main');
      final stickyBus = network.createBus('sticky_1');

      final received = <StickyMessage>[];
      final completer = Completer<void>();

      stickyBus.incoming.listen((event) {
        final (from, msg) = event;
        expect(from, 'main');
        received.add(msg);
        if (received.length == 3) {
          completer.complete();
        }
      });

      const msg1 = ReadyMessage(path: 'Stickies/1.md');
      const msg2 = SetColorMessage(path: 'Stickies/1.md', color: 'pink');
      const msg3 = CloseMessage(path: 'Stickies/1.md');

      await mainBus.send('sticky_1', msg1);
      await mainBus.send('sticky_1', msg2);
      await mainBus.send('sticky_1', msg3);

      await completer.future;

      expect(received, equals([msg1, msg2, msg3]));

      await mainBus.dispose();
      await stickyBus.dispose();
    });

    test(
      'throws WindowGoneException when target is closed or nonexistent',
      () async {
        final network = FakeWindowNetwork();
        final mainBus = network.createBus('main');

        expect(
          () => mainBus.send('nonexistent', const NewStickyMessage()),
          throwsA(isA<WindowGoneException>()),
        );

        final stickyBus = network.createBus('sticky_1');
        await stickyBus.dispose();

        expect(
          () => mainBus.send('sticky_1', const NewStickyMessage()),
          throwsA(isA<WindowGoneException>()),
        );

        await mainBus.dispose();
      },
    );

    test('tracks openWindowIds and creates sticky windows', () async {
      final network = FakeWindowNetwork();
      final mainBus = network.createBus('main');

      final openIdsEvents = <Set<String>>[];
      mainBus.openWindowIds.listen(openIdsEvents.add);

      const args = StickyWindowArgs(
        mainWindowId: 'main',
        path: 'Stickies/note.md',
      );

      final winId = await mainBus.createStickyWindow(args);
      expect(winId, startsWith('sticky_'));
      expect(network.argsFor(winId), equals(args));

      expect(network.openWindowIds, containsAll(['main', winId]));

      network.close(winId);
      expect(network.openWindowIds, equals({'main'}));

      await mainBus.dispose();
    });
  });
}
