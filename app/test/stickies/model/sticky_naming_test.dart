// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/stickies/model/sticky_naming.dart';
import 'package:tephra_core/tephra_core.dart';

void main() {
  group('newStickyPath', () {
    final fixedTime = DateTime(2026, 10, 11, 9, 30, 5);

    test('basic name', () {
      final path = newStickyPath(
        VaultPath('Stickies'),
        fixedTime,
        (p) => false,
      );
      expect(path.value, 'Stickies/Sticky 2026-10-11 093005.md');
    });

    test('collision adds suffix 1 then 2', () {
      final existing = <String>{
        'Stickies/Sticky 2026-10-11 093005.md',
        'Stickies/Sticky 2026-10-11 093005 1.md',
      };

      final path = newStickyPath(
        VaultPath('Stickies'),
        fixedTime,
        (p) => existing.contains(p.value),
      );
      expect(path.value, 'Stickies/Sticky 2026-10-11 093005 2.md');
    });

    test('case-insensitive collision', () {
      final existing = <String>{'stickies/sticky 2026-10-11 093005.md'};

      final path = newStickyPath(
        VaultPath('Stickies'),
        fixedTime,
        (p) => existing.contains(p.value.toLowerCase()),
      );
      expect(path.value, 'Stickies/Sticky 2026-10-11 093005 1.md');
    });
  });
}
