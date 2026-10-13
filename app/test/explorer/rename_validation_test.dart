// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra_core/tephra_core.dart';

void main() {
  group('rename_validation_test', () {
    test('valid names are accepted', () {
      expect(VaultPath.checkName('Valid Name'), isNull);
      expect(VaultPath.checkName('note-1_test'), isNull);
      expect(VaultPath.checkName('বাংলা নোট'), isNull);
      expect(VaultPath.checkName('Document.md'), isNull);
    });

    test('empty name is rejected', () {
      expect(VaultPath.checkName(''), isNotNull);
      expect(VaultPath.checkName('   '), isNotNull);
    });

    test('names with path separators are rejected', () {
      expect(VaultPath.checkName('a/b'), isNotNull);
      expect(VaultPath.checkName(r'a\b'), isNotNull);
    });

    test('names with illegal characters are rejected', () {
      expect(VaultPath.checkName('a:b'), isNotNull);
      expect(VaultPath.checkName('a*b'), isNotNull);
      expect(VaultPath.checkName('a?b'), isNotNull);
      expect(VaultPath.checkName('a"b'), isNotNull);
      expect(VaultPath.checkName('a<b'), isNotNull);
      expect(VaultPath.checkName('a>b'), isNotNull);
      expect(VaultPath.checkName('a|b'), isNotNull);
    });

    test('Windows reserved names are rejected', () {
      expect(VaultPath.checkName('con'), isNotNull);
      expect(VaultPath.checkName('PRN'), isNotNull);
      expect(VaultPath.checkName('aux.md'), isNotNull);
      expect(VaultPath.checkName('nul.txt'), isNotNull);
      expect(VaultPath.checkName('com1'), isNotNull);
      expect(VaultPath.checkName('lpt9'), isNotNull);
    });
  });
}
