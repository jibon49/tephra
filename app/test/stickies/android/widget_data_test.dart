// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/stickies/android/widget_data.dart';
import 'package:tephra/stickies/model/sticky.dart';
import 'package:tephra/stickies/model/sticky_color.dart';
import 'package:tephra/stickies/model/sticky_meta.dart';
import 'package:tephra_core/tephra_core.dart';

void main() {
  group('WidgetData', () {
    test('unconfigured json', () {
      final json = stickyWidgetJson(
        null,
        vaultId: 'vault-1',
        configured: false,
      );
      expect(json, equals(<String, Object?>{'v': 1, 'configured': false}));
    });

    test('missing note json', () {
      final json = stickyWidgetJson(
        null,
        vaultId: 'vault-1',
        configured: true,
        missingPath: 'Stickies/Gone.md',
      );
      expect(
        json,
        equals(<String, Object?>{
          'v': 1,
          'configured': true,
          'missing': true,
          'path': 'Stickies/Gone.md',
        }),
      );
    });

    test('single widget json matches golden map', () {
      final sticky = Sticky(
        path: VaultPath('Stickies/Sticky 2026-10-11 093005.md'),
        meta: const StickyMeta(
          isSticky: true,
          color: NamedStickyColor.yellow,
          locked: false,
        ),
        text: '''---
tephra-sticky: true
color: yellow
---
Call the printer guy
- [ ] ask about toner''',
        hash: 'dummy-hash',
        modified: DateTime.utc(2026, 10, 11, 9, 30),
      );

      final json = stickyWidgetJson(
        sticky,
        vaultId: 'vault-test',
        configured: true,
      );

      final expectedHash = stickyProtocolHash(sticky.text);

      expect(
        json,
        equals(<String, Object?>{
          'v': 1,
          'configured': true,
          'vaultId': 'vault-test',
          'path': 'Stickies/Sticky 2026-10-11 093005.md',
          'title': 'Sticky 2026-10-11 093005',
          'bg': NamedStickyColor.yellow.argb,
          'fg': NamedStickyColor.yellow.textArgb,
          'locked': false,
          'hash': expectedHash,
          'more': 0,
          'lines': [
            {'t': 'Call the printer guy', 'k': 'text', 'c': false, 'l': 4},
            {'t': 'ask about toner', 'k': 'task', 'c': false, 'l': 5},
          ],
        }),
      );
    });

    test('stack limited to 6 with total', () {
      final stickies = List.generate(
        9,
        (i) => Sticky(
          path: VaultPath('Stickies/Note $i.md'),
          meta: const StickyMeta(isSticky: true),
          text: 'Body $i',
          hash: 'h$i',
          modified: DateTime.utc(2026, 10, 11, 10, i),
        ),
      );

      final json = stackWidgetJson(stickies, vaultId: 'vault-1');

      expect(json['v'], equals(1));
      expect(json['vaultId'], equals('vault-1'));
      expect(json['total'], equals(9));

      final items = json['items'] as List;
      expect(items.length, equals(6));

      // Sorted descending by modified: Note 8 is newest
      final firstItem = items.first as Map<String, Object?>;
      expect(firstItem['title'], equals('Note 8'));
      expect(firstItem['preview'], equals('Body 8'));

      final lastItem = items.last as Map<String, Object?>;
      expect(lastItem['title'], equals('Note 3'));
      expect(lastItem['preview'], equals('Body 3'));
    });

    test('colours are argb ints', () {
      final sticky = Sticky(
        path: VaultPath('Stickies/Color.md'),
        meta: const StickyMeta(isSticky: true, color: HexStickyColor(0x336699)),
        text: 'Text',
        hash: 'h',
        modified: DateTime.utc(2026, 10, 11),
      );

      final json = stickyWidgetJson(
        sticky,
        vaultId: 'vault-1',
        configured: true,
      );
      expect(json['bg'], isA<int>());
      expect(json['fg'], isA<int>());
      expect(json['bg'], equals(0xFF336699));
    });
  });
}
