// © 2026 Tephra. All rights reserved.

import 'package:tephra_sync/tephra_sync.dart';
import 'package:test/test.dart';

void main() {
  group('WindowsNames', () {
    test('valid filenames pass isValid', () {
      final validCases = [
        'normal.txt',
        'my note.md',
        'document (1).pdf',
        'file-name_v2.0.json',
        'COM0.txt', // COM0 is not reserved
        'LPT0.log', // LPT0 is not reserved
        'CON_FILE.txt', // base name is CON_FILE
        'AUXILIARY.md', // base name is AUXILIARY
        'PRINTER.dat', // base name is PRINTER
        'NULL.bin', // base name is NULL, not NUL
      ];

      for (final name in validCases) {
        expect(
          WindowsNames.isValid(name),
          isTrue,
          reason: '$name should be valid',
        );
        expect(
          WindowsNames.sanitize(name),
          equals(name),
          reason: '$name should not be modified by sanitize',
        );
      }
    });

    test('20+ invalid and edge cases with sanitization verification', () {
      final invalidCases = <String, String>{
        // Reserved device names (exact and with extensions)
        'CON': 'CON_',
        'con': 'con_',
        'CON.txt': 'CON_.txt',
        'con.md': 'con_.md',
        'PRN': 'PRN_',
        'prn.txt': 'prn_.txt',
        'AUX': 'AUX_',
        'aux.tar.gz': 'aux_.tar.gz',
        'NUL': 'NUL_',
        'nul.bin': 'nul_.bin',
        'COM1': 'COM1_',
        'com1.dat': 'com1_.dat',
        'COM5.txt': 'COM5_.txt',
        'COM9': 'COM9_',
        'LPT1': 'LPT1_',
        'lpt1.log': 'lpt1_.log',
        'LPT9.txt': 'LPT9_.txt',

        // Invalid characters: < > : " / \ | ? *
        'file<name>.txt': 'file_name_.txt',
        'note:title.md': 'note_title.md',
        'quoted"word.txt': 'quoted_word.txt',
        'slash/file.txt': 'slash_file.txt',
        'backslash\\file.txt': 'backslash_file.txt',
        'pipe|file.txt': 'pipe_file.txt',
        'question?file.txt': 'question_file.txt',
        'asterisk*file.txt': 'asterisk_file.txt',
        'all<>:"/\\|?*chars.txt': 'all_________chars.txt',

        // ASCII control characters (< 32)
        'ctrl\x00file.txt': 'ctrl_file.txt',
        'ctrl\x01file.txt': 'ctrl_file.txt',
        'ctrl\x1Ffile.txt': 'ctrl_file.txt',

        // Trailing dots and spaces
        'trailing_dot.': 'trailing_dot_',
        'multiple_dots...': 'multiple_dots___',
        'trailing_space ': 'trailing_space_',
        'multiple_spaces   ': 'multiple_spaces___',
        'dot_and_space. ': 'dot_and_space__',
        'space_and_dot .': 'space_and_dot__',

        // Combined edge cases
        'con.': 'con_',
        'AUX. ': 'AUX__',
        '.': '_',
        '..': '__',
        ' ': '_',
      };

      for (final entry in invalidCases.entries) {
        final original = entry.key;
        final expectedSanitized = entry.value;

        expect(
          WindowsNames.isValid(original),
          isFalse,
          reason: '$original should be invalid',
        );

        final sanitized = WindowsNames.sanitize(original);
        expect(
          sanitized,
          equals(expectedSanitized),
          reason: 'Sanitizing $original should produce $expectedSanitized',
        );

        expect(
          WindowsNames.isValid(sanitized),
          isTrue,
          reason: 'Sanitized form "$sanitized" must be valid on Windows',
        );
      }
    });

    test('empty string handling', () {
      expect(WindowsNames.isValid(''), isFalse);
      final sanitized = WindowsNames.sanitize('');
      expect(sanitized, equals('_'));
      expect(WindowsNames.isValid(sanitized), isTrue);
    });
  });
}
