// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/src/links/link_resolver.dart';
import 'package:tephra_index/src/links/name_table.dart';
import 'package:test/test.dart';

void main() {
  group('LinkResolver 38-case matrix', () {
    late NameTable table;
    late LinkResolver resolver;

    setUp(() {
      final filePaths = [
        'Note.md',
        'Folder/Note.md',
        'Folder/Sub/Deep.md',
        'Other/Deep.md',
        'a/b/Note.md',
        'Projects/Alpha.md',
        'Beta.md',
        'Gamma Notes/Gamma.md',
        'Images/photo.png',
        'photo.png.md',
        'Café.md',
        'বাংলা নোট.md',
        'v1.2 release.md',
        'README',
        'Assets/diagram.canvas',
        'Daily/2026-10-11.md',
        'Archive/2026-10-11.md',
        'UPPER.md',
        'Folder/Sub/Same.md',
        'Same.md',
      ].map(VaultPath.new);

      final aliases = <VaultPath, List<String>>{
        VaultPath('Projects/Alpha.md'): ['A1', 'Project Alpha'],
        VaultPath('Beta.md'): ['Alpha', 'Gamma'],
      };

      table = NameTable.from(filePaths, aliases);
      resolver = LinkResolver(table);
    });

    void assertMatrix(
      String testNum,
      String target,
      String from,
      String? expectedPath, {
      bool? viaAlias,
    }) {
      test('#$testNum $target from $from', () {
        final res = resolver.resolve(target, from: VaultPath(from));
        if (expectedPath == null) {
          expect(res, isNull);
        } else {
          expect(res, isNotNull);
          expect(res!.path, equals(VaultPath(expectedPath)));
          if (viaAlias != null) {
            expect(res.viaAlias, equals(viaAlias));
          }
        }
      });
    }

    assertMatrix('01', 'Note', 'X.md', 'Note.md');
    assertMatrix('02', 'note', 'X.md', 'Note.md');
    assertMatrix('03', 'Note.md', 'X.md', 'Note.md');
    assertMatrix('04', 'Folder/Note', 'X.md', 'Folder/Note.md');
    assertMatrix('05', 'folder/NOTE.md', 'X.md', 'Folder/Note.md');
    assertMatrix('06', 'Note', 'Folder/Y.md', 'Note.md');
    assertMatrix('07', 'b/Note', 'X.md', 'a/b/Note.md');
    assertMatrix('08', '/Note', 'Folder/Y.md', 'Note.md');
    assertMatrix('09', '/Missing', 'X.md', null);
    assertMatrix('10', 'Deep', 'X.md', 'Other/Deep.md');
    assertMatrix('11', 'Deep', 'Folder/Sub/Z.md', 'Folder/Sub/Deep.md');
    assertMatrix('12', '../Note', 'Folder/Sub/Z.md', 'Folder/Note.md');
    assertMatrix('13', './Deep', 'Other/Z.md', 'Other/Deep.md');
    assertMatrix('14', './Note', 'Other/Z.md', null);
    assertMatrix('15', '../../../Note', 'Folder/Z.md', null);
    assertMatrix('16', 'Alpha', 'X.md', 'Projects/Alpha.md', viaAlias: false);
    assertMatrix('17', 'A1', 'X.md', 'Projects/Alpha.md', viaAlias: true);
    assertMatrix(
      '18',
      'project alpha',
      'X.md',
      'Projects/Alpha.md',
      viaAlias: true,
    );
    assertMatrix(
      '19',
      'Gamma',
      'X.md',
      'Gamma Notes/Gamma.md',
      viaAlias: false,
    );
    assertMatrix('20', 'Projects/A1', 'X.md', null);
    assertMatrix('21', 'photo.png', 'X.md', 'photo.png.md');
    assertMatrix('22', 'Images/photo.png', 'X.md', 'Images/photo.png');
    assertMatrix('23', 'cafe', 'X.md', null);
    assertMatrix('24', 'Café', 'X.md', 'Café.md');
    assertMatrix('25', 'বাংলা নোট', 'X.md', 'বাংলা নোট.md');
    assertMatrix('26', 'v1.2 release', 'X.md', 'v1.2 release.md');
    assertMatrix('27', 'README', 'X.md', 'README');
    assertMatrix('28', 'diagram', 'X.md', null);
    assertMatrix('29', 'diagram.canvas', 'X.md', 'Assets/diagram.canvas');
    assertMatrix('30', '2026-10-11', 'X.md', 'Archive/2026-10-11.md');
    assertMatrix('31', '2026-10-11', 'Daily/T.md', 'Daily/2026-10-11.md');
    assertMatrix('32', 'upper', 'X.md', 'UPPER.md');
    assertMatrix('33', 'Same', 'Folder/Sub/Q.md', 'Same.md');
    assertMatrix('33b', 'Sub/Same', 'Folder/Q.md', 'Folder/Sub/Same.md');
    assertMatrix('34', '', 'Folder/Note.md', 'Folder/Note.md');
    assertMatrix('35', 'Missing Note', 'X.md', null);
    assertMatrix('36', '  Note  ', 'X.md', 'Note.md');
    assertMatrix('37', r'Folder\Note', 'X.md', 'Folder/Note.md');
  });
}
