// © 2026 Tephra. All rights reserved.

import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/core/providers.dart';
import 'package:tephra/editor/attachment_service.dart';
import 'package:tephra/editor/providers.dart';
import 'package:tephra/settings/vault_settings.dart';
import 'package:tephra/vault/providers.dart';
import 'package:tephra/vault/vault_session.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../helpers/test_app.dart';

final class _HugeByteList extends ListBase<int> {
  @override
  int get length => AttachmentService.maxBytes + 1;

  @override
  set length(int newLength) => throw UnsupportedError('read-only');

  @override
  int operator [](int index) => 0;

  @override
  void operator []=(int index, int value) =>
      throw UnsupportedError('read-only');
}

void main() {
  group('AttachmentService', () {
    late MemoryVaultFileSystem fs;
    late ProviderContainer container;
    late ManualClock clock;
    final fixedTime = DateTime(2026, 10, 11, 9, 30, 0);

    setUp(() {
      fs = MemoryVaultFileSystem();
      clock = ManualClock(fixedTime);
      final session = VaultSession(
        vaultId: 'test-vault',
        rootDir: '/memory',
        name: 'TestVault',
        fs: fs,
        settings: const VaultSettings(),
      );

      container = ProviderContainer(
        overrides: [
          vaultSessionProvider.overrideWith(
            () => FixedVaultSessionNotifier(session),
          ),
          clockProvider.overrideWithValue(clock),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('savePastedImage saves image bytes with timestamped name in default folder', () async {
      final service = container.read(attachmentServiceProvider);
      final pngBytes = [
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
        0x01,
        0x02,
      ];
      final note = VaultPath('notes/my_note.md');

      final savedPath = await service.savePastedImage(
        note: note,
        bytes: pngBytes,
      );
      expect(savedPath.name, equals('Pasted image 20261011093000.png'));
      expect(
        savedPath.parent,
        equals(VaultPath.root),
      ); // default setting '/' is root

      final diskBytes = await fs.readBytes(savedPath);
      expect(diskBytes, equals(pngBytes));
    });

    test('second save in the same second gets " 1" suffix', () async {
      final service = container.read(attachmentServiceProvider);
      final pngBytes = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
      final note = VaultPath('note.md');

      final first = await service.savePastedImage(note: note, bytes: pngBytes);
      final second = await service.savePastedImage(note: note, bytes: pngBytes);

      expect(first.name, equals('Pasted image 20261011093000.png'));
      expect(second.name, equals('Pasted image 20261011093000 1.png'));
    });

    test(
      'folder is created when configured to fixed folder "Attachments"',
      () async {
        container
            .read(vaultSettingsProvider.notifier)
            .update((s) => s.copyWith(attachmentFolder: 'Attachments'));
        final service = container.read(attachmentServiceProvider);
        final note = VaultPath('note.md');

        final saved = await service.save(
          note: note,
          bytes: [1, 2, 3],
          fileName: 'doc.pdf',
        );

        expect(saved.value, equals('Attachments/doc.pdf'));
        final stat = await fs.stat(VaultPath('Attachments'));
        expect(stat, isNotNull);
        expect(stat!.isFolder, isTrue);
      },
    );

    test(
      'setting "./attachments" resolves relative to the note folder',
      () async {
        container
            .read(vaultSettingsProvider.notifier)
            .update((s) => s.copyWith(attachmentFolder: './attachments'));
        final service = container.read(attachmentServiceProvider);
        final note = VaultPath('Work/Project/note.md');

        final saved = await service.save(
          note: note,
          bytes: [1, 2, 3],
          fileName: 'diagram.png',
        );

        expect(saved.value, equals('Work/Project/attachments/diagram.png'));
      },
    );

    test('embedTextFor returns simple name if unique across vault', () async {
      final service = container.read(attachmentServiceProvider);
      final saved = VaultPath('Attachments/photo.png');
      await fs.createFolder(VaultPath('Attachments'));
      await fs.writeBytes(saved, [1, 2]);

      final embed = await service.embedTextFor(saved);
      expect(embed, equals('![[photo.png]]'));
    });

    test(
      'embedTextFor returns full path when ambiguous name exists in vault',
      () async {
        final service = container.read(attachmentServiceProvider);
        final first = VaultPath('FolderA/photo.png');
        final second = VaultPath('FolderB/photo.png');

        await fs.createFolder(VaultPath('FolderA'));
        await fs.createFolder(VaultPath('FolderB'));
        await fs.writeBytes(first, [1]);
        await fs.writeBytes(second, [2]);

        final embed = await service.embedTextFor(second);
        expect(embed, equals('![[FolderB/photo.png]]'));
      },
    );

    test('throws AttachmentTooLargeException if file exceeds 200 MB', () async {
      final service = container.read(attachmentServiceProvider);
      final hugeList = _HugeByteList();

      expect(
        () => service.save(
          note: VaultPath('note.md'),
          bytes: hugeList,
          fileName: 'huge.bin',
        ),
        throwsA(isA<AttachmentTooLargeException>()),
      );
    });

    test('never overwrites existing file with same name', () async {
      final service = container.read(attachmentServiceProvider);
      final note = VaultPath('note.md');

      await fs.writeBytes(VaultPath('doc.pdf'), [1, 1, 1]);
      final saved = await service.save(
        note: note,
        bytes: [2, 2, 2],
        fileName: 'doc.pdf',
      );

      expect(saved.name, equals('doc 1.pdf'));
      expect(await fs.readBytes(VaultPath('doc.pdf')), equals([1, 1, 1]));
      expect(await fs.readBytes(saved), equals([2, 2, 2]));
    });
  });
}
