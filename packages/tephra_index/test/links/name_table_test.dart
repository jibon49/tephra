// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/src/links/name_table.dart';
import 'package:test/test.dart';

void main() {
  group('NameTable', () {
    test('add/remove/setAliases update all three lookups', () {
      final table = NameTable();
      final n1 = VaultPath('Folder/Note.md');
      final n2 = VaultPath('Other/Note.md');

      table.addFile(n1);
      table.setAliases(n1, ['N1', 'My Note']);

      expect(table.files, contains(n1));
      expect(table.byCaseKey('folder/note.md'), equals(n1));
      expect(table.byNameKey('note.md'), equals([n1]));
      expect(table.byAliasKey('n1'), equals([n1]));
      expect(table.byAliasKey('my note'), equals([n1]));
      expect(table.aliasesOf(n1), equals(['N1', 'My Note']));

      table.addFile(n2);
      expect(table.byNameKey('note.md'), containsAll([n1, n2]));

      // Update aliases
      table.setAliases(n1, ['N1_Renamed']);
      expect(table.byAliasKey('my note'), isEmpty);
      expect(table.byAliasKey('n1_renamed'), equals([n1]));

      // Remove n1
      table.removeFile(n1);
      expect(table.files, isNot(contains(n1)));
      expect(table.byCaseKey('folder/note.md'), isNull);
      expect(table.byNameKey('note.md'), equals([n2]));
      expect(table.byAliasKey('n1_renamed'), isEmpty);
      expect(table.aliasesOf(n1), isEmpty);
    });

    test('copy() creates an independent deep copy', () {
      final table = NameTable();
      final p1 = VaultPath('A.md');
      table.addFile(p1);
      table.setAliases(p1, ['Alpha']);

      final copied = table.copy();
      expect(copied.files, contains(p1));
      expect(copied.byCaseKey('a.md'), equals(p1));
      expect(copied.byAliasKey('alpha'), equals([p1]));

      // Mutating the copy leaves original unchanged
      final p2 = VaultPath('B.md');
      copied.addFile(p2);
      copied.setAliases(p2, ['Beta']);
      copied.removeFile(p1);

      expect(table.files, contains(p1));
      expect(table.files, isNot(contains(p2)));
      expect(table.byAliasKey('alpha'), equals([p1]));
      expect(table.byAliasKey('beta'), isEmpty);

      expect(copied.files, isNot(contains(p1)));
      expect(copied.files, contains(p2));
      expect(copied.byAliasKey('alpha'), isEmpty);
      expect(copied.byAliasKey('beta'), equals([p2]));
    });

    test('two files a.md and A.md produce 2 in byNameKey and alphabetical in byCaseKey', () {
      final table = NameTable();
      final lower = VaultPath('a.md');
      final upper = VaultPath('A.md');

      table.addFile(lower);
      table.addFile(upper);

      final byName = table.byNameKey('a.md');
      expect(byName.length, equals(2));
      expect(byName, containsAll([lower, upper]));

      // 'A.md'.compareTo('a.md') < 0 because uppercase ASCII is before lowercase ASCII
      expect(table.byCaseKey('a.md'), equals(upper));

      // Removing upper leaves lower
      table.removeFile(upper);
      expect(table.byCaseKey('a.md'), equals(lower));
      expect(table.byNameKey('a.md'), equals([lower]));
    });
  });
}
