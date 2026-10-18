// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/properties/frontmatter_editor.dart';
import 'package:tephra/properties/properties_exceptions.dart';
import 'package:tephra_index/tephra_index.dart';

void main() {
  group('FrontmatterEditor', () {
    const baseNote = '''---
title: My note # keep
tags:
  - a
  - b

# comment before status
status: draft
---
Body
''';

    test(
      '(1) setValue(B, status, done) preserves every other line byte-identical',
      () {
        final edit = FrontmatterEditor.setValue(baseNote, 'status', 'done');
        expect(edit, isNotNull);
        final updated = applyTextEdits(baseNote, [edit!]);

        const expected = '''---
title: My note # keep
tags:
  - a
  - b

# comment before status
status: done
---
Body
''';
        expect(updated, equals(expected));
      },
    );

    test('(2) setValue(B, tags, [a, b, c]) keeps title, comment, status, body identical', () {
      final edit = FrontmatterEditor.setValue(baseNote, 'tags', [
        'a',
        'b',
        'c',
      ]);
      expect(edit, isNotNull);
      final updated = applyTextEdits(baseNote, [edit!]);

      final readValues = FrontmatterEditor.read(updated);
      expect(readValues['tags'], equals(['a', 'b', 'c']));
      expect(readValues['title'], equals('My note'));
      expect(readValues['status'], equals('draft'));
      expect(updated.contains('title: My note # keep'), isTrue);
      expect(updated.contains('# comment before status'), isTrue);
      expect(updated.contains('status: draft'), isTrue);
      expect(updated.endsWith('\nBody\n'), isTrue);
    });

    test('(3) removeKey(B, title) removes title line and leaves all others identical', () {
      final edit = FrontmatterEditor.removeKey(baseNote, 'title');
      expect(edit, isNotNull);
      final updated = applyTextEdits(baseNote, [edit!]);

      const expected = '''---
tags:
  - a
  - b

# comment before status
status: draft
---
Body
''';
      expect(updated, equals(expected));
    });

    test(
      '(4) renameKey(B, status, state) updates key and preserves comment line',
      () {
        final edit = FrontmatterEditor.renameKey(baseNote, 'status', 'state');
        expect(edit, isNotNull);
        final updated = applyTextEdits(baseNote, [edit!]);

        expect(updated.contains('state: draft'), isTrue);
        expect(updated.contains('# comment before status'), isTrue);

        // Throws PropertyKeyExistsException when newKey exists
        expect(
          () => FrontmatterEditor.renameKey(baseNote, 'status', 'title'),
          throwsA(isA<PropertyKeyExistsException>()),
        );

        // Case-insensitive matching of oldKey works
        final editCase = FrontmatterEditor.renameKey(
          baseNote,
          'Status',
          'state',
        );
        expect(editCase, isNotNull);
      },
    );

    test('(5) moveKey(B, status, 0) moves comment line with status and preserves lines', () {
      final edit = FrontmatterEditor.moveKey(baseNote, 'status', 0);
      expect(edit, isNotNull);
      final updated = applyTextEdits(baseNote, [edit!]);

      final readValues = FrontmatterEditor.read(updated);
      expect(readValues.keys.toList(), equals(['status', 'title', 'tags']));
      expect(
        updated.contains('# comment before status\nstatus: draft'),
        isTrue,
      );
    });

    test('(6) no frontmatter: setValue inserts block at offset 0', () {
      final editScalar = FrontmatterEditor.setValue('Body\n', 'a', 'x');
      expect(editScalar, isNotNull);
      final updatedScalar = applyTextEdits('Body\n', [editScalar!]);
      expect(updatedScalar, equals('---\na: x\n---\nBody\n'));

      final editList = FrontmatterEditor.setValue('Body\n', 'a', ['x', 'y']);
      expect(editList, isNotNull);
      final updatedList = applyTextEdits('Body\n', [editList!]);
      expect(updatedList, equals('---\na:\n  - x\n  - y\n---\nBody\n'));
    });

    test('(7) empty block: setValue inserts after first ---', () {
      final edit = FrontmatterEditor.setValue('---\n---\nBody', 'a', 1);
      expect(edit, isNotNull);
      final updated = applyTextEdits('---\n---\nBody', [edit!]);
      expect(updated, equals('---\na: 1\n---\nBody'));
    });

    test('(8) setValue(B, status, "a: b") quotes scalar', () {
      final edit = FrontmatterEditor.setValue(baseNote, 'status', 'a: b');
      expect(edit, isNotNull);
      final updated = applyTextEdits(baseNote, [edit!]);

      expect(updated.contains('status: "a: b"'), isTrue);
      final read = FrontmatterEditor.read(updated);
      expect(read['status'], equals('a: b'));
    });

    test('(9) typed values and Bangla key and value round-trip', () {
      final editNum = FrontmatterEditor.setValue(baseNote, 'n', 3);
      final withNum = applyTextEdits(baseNote, [editNum!]);
      expect(FrontmatterEditor.read(withNum)['n'], equals(3));

      final editBool = FrontmatterEditor.setValue(baseNote, 'checked', true);
      final withBool = applyTextEdits(baseNote, [editBool!]);
      expect(FrontmatterEditor.read(withBool)['checked'], equals(true));

      final editBangla = FrontmatterEditor.setValue(
        baseNote,
        'শিরোনাম',
        'বাংলা',
      );
      final withBangla = applyTextEdits(baseNote, [editBangla!]);
      expect(FrontmatterEditor.read(withBangla)['শিরোনাম'], equals('বাংলা'));
    });

    test(
      '(10) replaceRaw validates YAML and throws PropertiesYamlException',
      () {
        expect(
          () => FrontmatterEditor.replaceRaw(baseNote, 'a: ['),
          throwsA(
            isA<PropertiesYamlException>().having((e) => e.line, 'line', 0),
          ),
        );

        expect(
          () => FrontmatterEditor.replaceRaw(baseNote, '- x'),
          throwsA(isA<PropertiesYamlException>()),
        );

        final edit = FrontmatterEditor.replaceRaw(
          '---\nold: val\n---\nBody',
          'a: 1',
        );
        expect(edit, isNotNull);
        final updated = applyTextEdits('---\nold: val\n---\nBody', [edit!]);
        expect(updated, equals('---\na: 1\n---\nBody'));
      },
    );
  });
}
