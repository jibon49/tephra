// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_sync/tephra_sync.dart';
import 'package:test/test.dart';

void main() {
  group('sanitizeDeviceName', () {
    test('removes forbidden characters, trims and collapses spaces', () {
      expect(
        sanitizeDeviceName('Pixel 8: Pro / Test * ? " < > | \x00'),
        equals('Pixel 8 Pro Test'),
      );
      expect(sanitizeDeviceName('   Device   Name   '), equals('Device Name'));
      expect(sanitizeDeviceName(':::'), equals('Device'));
      expect(sanitizeDeviceName(''), equals('Device'));
      expect(sanitizeDeviceName('a' * 50), equals('a' * 40));
    });
  });

  group('conflictCopyName', () {
    final fixedTime = DateTime(2026, 10, 11, 14, 5); // 2026-10-11 14-05

    test('generates standard conflict copy name in root folder', () {
      final existing = <VaultPath>{};
      final name = conflictCopyName(
        VaultPath('Note.md'),
        fixedTime,
        'Pixel 8',
        existing.contains,
      );

      expect(name, equals('Note (conflict 2026-10-11 14-05 Pixel 8).md'));
    });

    test('generates conflict copy in the same folder as the original note', () {
      final existing = <VaultPath>{};
      final name = conflictCopyName(
        VaultPath('folder/sub/Note.md'),
        fixedTime,
        'Pixel 8',
        existing.contains,
      );

      expect(
        name,
        equals('folder/sub/Note (conflict 2026-10-11 14-05 Pixel 8).md'),
      );
    });

    test('handles collisions by incrementing suffix inside parentheses', () {
      final existing = <VaultPath>{
        VaultPath('Note (conflict 2026-10-11 14-05 Pixel 8).md'),
        VaultPath('Note (conflict 2026-10-11 14-05 Pixel 8 2).md'),
      };

      final name = conflictCopyName(
        VaultPath('Note.md'),
        fixedTime,
        'Pixel 8',
        existing.contains,
      );

      expect(name, equals('Note (conflict 2026-10-11 14-05 Pixel 8 3).md'));
    });

    test('files without extension have no trailing dot', () {
      final existing = <VaultPath>{};
      final name1 = conflictCopyName(
        VaultPath('LICENSE'),
        fixedTime,
        'Pixel 8',
        existing.contains,
      );
      expect(name1, equals('LICENSE (conflict 2026-10-11 14-05 Pixel 8)'));

      existing.add(VaultPath('LICENSE (conflict 2026-10-11 14-05 Pixel 8)'));
      final name2 = conflictCopyName(
        VaultPath('LICENSE'),
        fixedTime,
        'Pixel 8',
        existing.contains,
      );
      expect(name2, equals('LICENSE (conflict 2026-10-11 14-05 Pixel 8 2)'));
    });
  });

  group('caseConflictName', () {
    test('generates case conflict name without collision', () {
      final existing = <VaultPath>{};
      final name = caseConflictName(VaultPath('Note.md'), existing.contains);
      expect(name, equals('Note (case conflict).md'));
    });

    test('generates case conflict name in subfolder', () {
      final existing = <VaultPath>{};
      final name = caseConflictName(
        VaultPath('folder/sub/Note.md'),
        existing.contains,
      );
      expect(name, equals('folder/sub/Note (case conflict).md'));
    });

    test('increments counter on collisions inside parentheses', () {
      final existing = <VaultPath>{
        VaultPath('Note (case conflict).md'),
        VaultPath('Note (case conflict 2).md'),
      };

      final name = caseConflictName(VaultPath('Note.md'), existing.contains);
      expect(name, equals('Note (case conflict 3).md'));
    });

    test('files without extension have no trailing dot', () {
      final existing = <VaultPath>{};
      final name = caseConflictName(VaultPath('Makefile'), existing.contains);
      expect(name, equals('Makefile (case conflict)'));
    });
  });
}
