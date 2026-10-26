// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/stickies/android/overlay_protocol.dart';

void main() {
  group('OverlayProtocol', () {
    test('round trip of every message', () {
      const open = OverlayOpenMessage(
        path: 'Stickies/Note 1.md',
        text: '# Header\nContent',
        hash: 'h123',
        color: 'pink',
        locked: true,
        title: 'Custom Title',
      );
      final openDecoded = OverlayMessage.fromJson(open.toJson());
      expect(openDecoded, equals(open));

      const update = OverlayUpdateMessage(
        path: 'Stickies/Note 2.md',
        text: 'Updated text',
        hash: 'h456',
        color: 'blue',
        locked: false,
        title: 'Note 2',
      );
      final updateDecoded = OverlayMessage.fromJson(update.toJson());
      expect(updateDecoded, equals(update));

      const contentChanged = OverlayContentChangedMessage(
        path: 'Stickies/Note 3.md',
        text: 'Edited text from bubble',
        baseHash: 'h789',
      );
      final contentChangedDecoded = OverlayMessage.fromJson(
        contentChanged.toJson(),
      );
      expect(contentChangedDecoded, equals(contentChanged));

      const ack = OverlayAckMessage(path: 'Stickies/Note 3.md', hash: 'hFinal');
      final ackDecoded = OverlayMessage.fromJson(ack.toJson());
      expect(ackDecoded, equals(ack));

      const close = OverlayCloseMessage(path: 'Stickies/Note 1.md');
      final closeDecoded = OverlayMessage.fromJson(close.toJson());
      expect(closeDecoded, equals(close));

      const ping = OverlayPingMessage();
      final pingDecoded = OverlayMessage.fromJson(ping.toJson());
      expect(pingDecoded, equals(ping));

      const pong = OverlayPongMessage();
      final pongDecoded = OverlayMessage.fromJson(pong.toJson());
      expect(pongDecoded, equals(pong));
    });

    test('round trip through fromDynamic string and map', () {
      const open = OverlayOpenMessage(
        path: 'Stickies/A.md',
        text: 'Hi',
        hash: 'h1',
        color: 'yellow',
        locked: false,
      );
      final mapDynamic = OverlayMessage.fromDynamic(open.toJson());
      expect(mapDynamic, equals(open));

      const jsonStr =
          '{"v":1,"type":"contentChanged","path":"Stickies/A.md","text":"Edited","baseHash":"h1"}';
      final strDynamic = OverlayMessage.fromDynamic(jsonStr);
      expect(
        strDynamic,
        equals(
          const OverlayContentChangedMessage(
            path: 'Stickies/A.md',
            text: 'Edited',
            baseHash: 'h1',
          ),
        ),
      );
    });

    test('unknown/old messages ignored', () {
      // Wrong version
      expect(
        OverlayMessage.fromJson({
          'v': 2,
          'type': 'open',
          'path': 'A.md',
          'text': 'x',
          'hash': 'h',
          'color': 'yellow',
          'locked': false,
        }),
        isNull,
      );

      // Unknown type
      expect(
        OverlayMessage.fromJson({
          'v': 1,
          'type': 'someFutureType',
          'foo': 'bar',
        }),
        isNull,
      );

      // Non-map / invalid string
      expect(OverlayMessage.fromDynamic('not json'), isNull);
      expect(OverlayMessage.fromDynamic(12345), isNull);
    });
  });
}
