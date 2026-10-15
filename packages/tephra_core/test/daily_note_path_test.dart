// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';
import 'package:test/test.dart';

void main() {
  group('dailyNotePath', () {
    final date = DateTime(2026, 10, 11);

    test('folder Daily, YYYY-MM-DD -> Daily/2026-10-11.md', () {
      final p = dailyNotePath(date, folder: 'Daily', format: 'YYYY-MM-DD');
      expect(p.value, equals('Daily/2026-10-11.md'));
    });

    test('folder empty, YYYY/MM/YYYY-MM-DD -> 2026/10/2026-10-11.md', () {
      final p = dailyNotePath(date, folder: '', format: 'YYYY/MM/YYYY-MM-DD');
      expect(p.value, equals('2026/10/2026-10-11.md'));
    });

    test('format YYYY-MM-DD[.md] does not duplicate .md', () {
      final p = dailyNotePath(date, folder: '', format: 'YYYY-MM-DD[.md]');
      expect(p.value, equals('2026-10-11.md'));
    });

    test('format ../x throws InvalidPathException', () {
      expect(
        () => dailyNotePath(date, folder: '', format: '../x'),
        throwsA(isA<InvalidPathException>()),
      );
    });
  });
}
