// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/editor/attachment_paths.dart';
import 'package:tephra_core/tephra_core.dart';

void main() {
  group('attachmentFolderFor', () {
    final rootNote = VaultPath('note.md');
    final nestedNote = VaultPath('A/B/n.md');

    test('setting "/" resolves to root for both root and nested notes', () {
      expect(attachmentFolderFor(rootNote, '/'), equals(VaultPath.root));
      expect(attachmentFolderFor(nestedNote, '/'), equals(VaultPath.root));
    });

    test('setting "./" resolves to note parent folder', () {
      expect(attachmentFolderFor(rootNote, './'), equals(VaultPath.root));
      expect(attachmentFolderFor(nestedNote, './'), equals(VaultPath('A/B')));
    });

    test('setting "./sub" resolves to note parent subfolder', () {
      expect(attachmentFolderFor(rootNote, './sub'), equals(VaultPath('sub')));
      expect(
        attachmentFolderFor(nestedNote, './sub'),
        equals(VaultPath('A/B/sub')),
      );
    });

    test('setting "Attachments" resolves to fixed vault folder', () {
      expect(
        attachmentFolderFor(rootNote, 'Attachments'),
        equals(VaultPath('Attachments')),
      );
      expect(
        attachmentFolderFor(nestedNote, 'Attachments'),
        equals(VaultPath('Attachments')),
      );
    });

    test(
      'invalid folder setting "bad:folder" logs warning and falls back to root',
      () {
        expect(
          attachmentFolderFor(rootNote, 'bad:folder'),
          equals(VaultPath.root),
        );
        expect(
          attachmentFolderFor(nestedNote, 'bad:folder'),
          equals(VaultPath.root),
        );
      },
    );
  });

  group('sanitizeAttachmentName', () {
    test('replaces invalid characters with underscores', () {
      expect(sanitizeAttachmentName('a:b?.png'), equals('a_b_.png'));
      expect(
        sanitizeAttachmentName('hello<world>*file|name".ext'),
        equals('hello_world__file_name_.ext'),
      );
    });

    test('trims trailing dots and spaces', () {
      expect(sanitizeAttachmentName('my_file.png...'), equals('my_file.png'));
      expect(sanitizeAttachmentName('my_file   '), equals('my_file'));
    });

    test('converts reserved names or empty results to "attachment"', () {
      expect(sanitizeAttachmentName('con'), equals('attachment'));
      expect(sanitizeAttachmentName('CON.png'), equals('attachment'));
      expect(sanitizeAttachmentName('nul'), equals('attachment'));
      expect(sanitizeAttachmentName(''), equals('attachment'));
      expect(sanitizeAttachmentName('   ...'), equals('attachment'));
    });

    test('limits length to 200 characters keeping extension', () {
      final longName = '${'a' * 250}.png';
      final sanitized = sanitizeAttachmentName(longName);
      expect(sanitized.length, lessThanOrEqualTo(200));
      expect(sanitized.endsWith('.png'), isTrue);
    });
  });

  group('pastedImageName', () {
    test('formats timestamp in local time yyyyMMddHHmmss', () {
      final dt = DateTime(2026, 10, 11, 9, 30, 5);
      expect(
        pastedImageName(dt, 'png'),
        equals('Pasted image 20261011093005.png'),
      );
    });
  });
}
