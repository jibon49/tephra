// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/core/deep_links/deep_link.dart';
import 'package:tephra_core/tephra_core.dart';

void main() {
  group('DeepLink', () {
    test('round-trip for all link types with vaultId', () {
      final links = <DeepLink>[
        OpenNoteLink(vaultId: 'vault_123', path: VaultPath('Notes/Work.md')),
        const CaptureLink(vaultId: 'vault_123'),
        const NewStickyLink(vaultId: 'vault_123'),
        const DailyLink(vaultId: 'vault_123'),
        const BoardLink(vaultId: 'vault_123'),
        const WidgetConfigLink(vaultId: 'vault_123', widgetId: 42),
      ];

      for (final link in links) {
        final uri = link.toUri();
        expect(uri.scheme, 'tephra');
        final parsed = DeepLink.parse(uri);
        expect(parsed, isNotNull, reason: 'Failed for ${link.runtimeType}');
        expect(parsed, equals(link));
        expect(parsed?.vaultId, 'vault_123');
      }
    });

    test('missing vault is allowed', () {
      final open = OpenNoteLink(path: VaultPath('Inbox.md'));
      final uri = open.toUri();
      expect(uri.queryParameters.containsKey('vault'), isFalse);

      final parsed = DeepLink.parse(uri);
      expect(parsed, isA<OpenNoteLink>());
      expect(parsed?.vaultId, isNull);
      expect((parsed as OpenNoteLink).path.value, 'Inbox.md');

      const capture = CaptureLink();
      expect(DeepLink.parse(capture.toUri()), equals(capture));

      const daily = DailyLink();
      expect(DeepLink.parse(daily.toUri()), equals(daily));

      const sticky = NewStickyLink();
      expect(DeepLink.parse(sticky.toUri()), equals(sticky));

      const board = BoardLink();
      expect(DeepLink.parse(board.toUri()), equals(board));

      const widget = WidgetConfigLink(widgetId: 7);
      expect(DeepLink.parse(widget.toUri()), equals(widget));
    });

    test('path with spaces and Bangla characters', () {
      final link = OpenNoteLink(
        vaultId: 'vault_bangla',
        path: VaultPath('Stickies/কাজ 1.md'),
      );
      final uri = link.toUri();

      // Ensure proper URI encoding
      expect(
        uri.toString(),
        contains('path=Stickies%2F%E0%A6%95%E0%A6%BE%E0%A6%9C+1.md'),
      );

      final parsed = DeepLink.parse(uri);
      expect(parsed, isA<OpenNoteLink>());
      final open = parsed as OpenNoteLink;
      expect(open.path.value, 'Stickies/কাজ 1.md');
      expect(open.vaultId, 'vault_bangla');
      expect(open, equals(link));
    });

    test('unknown host returns null', () {
      expect(
        DeepLink.parse(Uri.parse('tephra://unknown-action?vault=v1')),
        isNull,
      );
      expect(DeepLink.parse(Uri.parse('tephra://')), isNull);
      expect(DeepLink.parse(Uri.parse('https://tephra.app/open')), isNull);
    });

    test('invalid or missing parameters return null', () {
      expect(DeepLink.parse(Uri.parse('tephra://open')), isNull);
      expect(DeepLink.parse(Uri.parse('tephra://open?path=')), isNull);
      expect(DeepLink.parse(Uri.parse('tephra://widget-config')), isNull);
      expect(
        DeepLink.parse(
          Uri.parse('tephra://widget-config?widgetId=not_a_number'),
        ),
        isNull,
      );
    });
  });
}
