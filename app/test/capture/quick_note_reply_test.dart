// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/capture/quick_note_reply.dart';
import 'package:tephra/core/headless_config.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

void main() {
  group('quick_note_reply', () {
    late MemoryVaultFileSystem fs;
    final fixedTime = DateTime(2026, 10, 11, 14, 5);

    HeadlessConfig makeConfig({
      String fsKind = 'io',
      String quickTarget = 'dailyNote',
      String inboxPath = 'Inbox.md',
      String folder = 'Daily',
      String format = 'YYYY-MM-DD',
      String template = '',
    }) {
      return HeadlessConfig(
        vaultId: 'test-vault',
        vaultRoot: '/vault',
        fsKind: fsKind,
        stickyFolder: 'Stickies',
        dailyNote: HeadlessDailyNoteConfig(
          folder: folder,
          format: format,
          template: template,
        ),
        quickTarget: quickTarget,
        inboxPath: inboxPath,
        deviceName: 'Test Phone',
      );
    }

    setUp(() {
      fs = MemoryVaultFileSystem();
    });

    test('appends to existing daily note', () async {
      final cfg = makeConfig();
      final dailyPath = VaultPath('Daily/2026-10-11.md');
      await fs.createFolder(VaultPath('Daily'));
      await fs.writeText(
        dailyPath,
        const TextDocument(text: '# Daily 2026-10-11\n'),
      );

      final result = await appendQuickNote(fs, cfg, 'buy milk', fixedTime);
      expect(result, dailyPath);

      final doc = await fs.readText(dailyPath);
      expect(doc.text, '# Daily 2026-10-11\n- 14:05 buy milk\n');
    });

    test('creates daily note without template', () async {
      final cfg = makeConfig(template: 'Templates/Daily.md');
      final dailyPath = VaultPath('Daily/2026-10-11.md');

      expect(await fs.stat(dailyPath), isNull);

      final result = await appendQuickNote(
        fs,
        cfg,
        'read book chapter 3',
        fixedTime,
      );
      expect(result, dailyPath);

      final doc = await fs.readText(dailyPath);
      expect(doc.text, '- 14:05 read book chapter 3\n');
      expect(doc.text.contains('Templates'), isFalse);
    });

    test('inbox target', () async {
      final cfg = makeConfig(quickTarget: 'inbox', inboxPath: 'Notes/Inbox.md');
      final inboxPath = VaultPath('Notes/Inbox.md');

      final result = await appendQuickNote(fs, cfg, 'call plumber', fixedTime);
      expect(result, inboxPath);

      final doc = await fs.readText(inboxPath);
      expect(doc.text, '- 14:05 call plumber\n');
    });

    test('saf config does nothing', () async {
      final cfg = makeConfig(fsKind: 'saf');
      final result = await appendQuickNote(fs, cfg, 'ignored note', fixedTime);

      expect(result, isNull);
      final list = await fs.list(recursive: true);
      expect(list, isEmpty);
    });

    test('multi-line reply indented', () async {
      final cfg = makeConfig();
      const multiLine = 'First line\nSecond line details\nThird line footer';
      final dailyPath = VaultPath('Daily/2026-10-11.md');

      final result = await appendQuickNote(fs, cfg, multiLine, fixedTime);
      expect(result, dailyPath);

      final doc = await fs.readText(dailyPath);
      expect(
        doc.text,
        '- 14:05 First line\n  Second line details\n  Third line footer\n',
      );
    });
  });
}
