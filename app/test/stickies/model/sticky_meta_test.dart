// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/stickies/model/sticky_color.dart';
import 'package:tephra/stickies/model/sticky_meta.dart';

void main() {
  group('StickyMeta', () {
    test('full keys', () {
      final fm = <String, Object?>{
        'tephra-sticky': true,
        'sticky-color': 'pink',
        'sticky-pinned': true,
        'sticky-remind': '2026-10-12T09:00',
        'sticky-expire': '2026-10-20',
        'sticky-locked': true,
      };

      final meta = StickyMeta.fromFrontmatter(fm);
      expect(meta.isSticky, isTrue);
      expect(meta.color, equals(NamedStickyColor.pink));
      expect(meta.pinned, isTrue);
      expect(meta.remind, equals(const LocalDateTime(2026, 10, 12, 9, 0)));
      expect(meta.expire, equals(const LocalDate(2026, 10, 20)));
      expect(meta.locked, isTrue);
    });

    test('string booleans', () {
      final fm1 = <String, Object?>{
        'tephra-sticky': 'TRUE',
        'sticky-pinned': 'yes',
        'sticky-locked': 'True ',
      };
      final meta1 = StickyMeta.fromFrontmatter(fm1);
      expect(meta1.isSticky, isTrue);
      expect(meta1.pinned, isTrue);
      expect(meta1.locked, isTrue);

      final fm2 = <String, Object?>{
        'tephra-sticky': 'no',
        'sticky-pinned': 'false',
        'sticky-locked': 'other',
      };
      final meta2 = StickyMeta.fromFrontmatter(fm2);
      expect(meta2.isSticky, isFalse);
      expect(meta2.pinned, isFalse);
      expect(meta2.locked, isFalse);
    });

    test('remind formats', () {
      // 1. YYYY-MM-DDTHH:mm
      final fm1 = {'sticky-remind': '2026-10-12T09:30'};
      expect(
        StickyMeta.fromFrontmatter(fm1).remind,
        equals(const LocalDateTime(2026, 10, 12, 9, 30)),
      );

      // 2. YYYY-MM-DDTHH:mm:ss (seconds dropped)
      final fm2 = {'sticky-remind': '2026-10-12T09:30:45'};
      expect(
        StickyMeta.fromFrontmatter(fm2).remind,
        equals(const LocalDateTime(2026, 10, 12, 9, 30)),
      );

      // 3. YYYY-MM-DD HH:mm
      final fm3 = {'sticky-remind': '2026-10-12 09:30'};
      expect(
        StickyMeta.fromFrontmatter(fm3).remind,
        equals(const LocalDateTime(2026, 10, 12, 9, 30)),
      );

      // Invalid date (February 30th)
      final fmInvalid = {'sticky-remind': '2026-02-30T10:00'};
      expect(StickyMeta.fromFrontmatter(fmInvalid).remind, isNull);

      // Invalid format
      final fmGarbage = {'sticky-remind': 'not-a-date'};
      expect(StickyMeta.fromFrontmatter(fmGarbage).remind, isNull);
    });

    test('DateTime values', () {
      final dt = DateTime(2026, 10, 12, 9, 0);
      final fm = <String, Object?>{'sticky-remind': dt, 'sticky-expire': dt};
      final meta = StickyMeta.fromFrontmatter(fm);
      expect(meta.remind, equals(const LocalDateTime(2026, 10, 12, 9, 0)));
      expect(meta.expire, equals(const LocalDate(2026, 10, 12)));
    });

    test('missing keys -> defaults', () {
      final meta = StickyMeta.fromFrontmatter(const {});
      expect(meta.isSticky, isFalse);
      expect(meta.color, equals(StickyColor.fallback));
      expect(meta.pinned, isFalse);
      expect(meta.remind, isNull);
      expect(meta.expire, isNull);
      expect(meta.locked, isFalse);
    });
  });
}
