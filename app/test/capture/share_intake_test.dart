// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/capture/share_intake.dart';
import 'package:tephra/core/platform/share_intent_service.dart';

void main() {
  group('share_intake', () {
    test('single url becomes autolink', () {
      final items = [const SharedText('https://example.com/article?id=123')];
      final draft = draftFromShare(items);

      expect(draft.text, '<https://example.com/article?id=123>');
      expect(draft.title, 'httpsexample.comarticleid=123');
      expect(draft.files, isEmpty);
    });

    test('multiple texts joined', () {
      final items = [
        const SharedText('First section'),
        const SharedText('Second section with more details'),
      ];
      final draft = draftFromShare(items);

      expect(draft.text, 'First section\n\nSecond section with more details');
      expect(draft.title, 'First section');
      expect(draft.files, isEmpty);
    });

    test('files only uses date title', () {
      final fixedDate = DateTime(2026, 10, 26, 14, 30);
      final items = [
        const SharedFile(path: '/cache/doc.pdf', mimeType: 'application/pdf'),
      ];
      final draft = draftFromShare(items, now: fixedDate);

      expect(draft.text, isEmpty);
      expect(draft.title, 'Shared 2026-10-26 1430');
      expect(draft.files.length, 1);
      expect(draft.files.first.path, '/cache/doc.pdf');
    });

    test('title strips invalid chars', () {
      final items = [
        const SharedText('Title: with *special* <chars> / \\ ? " |'),
      ];
      final draft = draftFromShare(items);

      expect(draft.title, 'Title with special chars');
    });

    test('long title cut at 60', () {
      final longText =
          'This is an exceptionally long first line intended to test truncation of title length when shared into the application';
      final items = [SharedText(longText)];
      final draft = draftFromShare(items);

      expect(draft.title?.length, lessThanOrEqualTo(60));
      expect(draft.title, longText.substring(0, 60).trim());
    });
  });
}
