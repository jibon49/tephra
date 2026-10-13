// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/reading/task_toggler.dart';
import 'package:tephra/vault/note_document.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_markdown/tephra_markdown.dart';
import 'package:tephra_vault/tephra_vault.dart';

void main() {
  const toggler = TaskToggler();
  final clock = ManualClock(DateTime(2026, 10, 11, 10, 0));

  test(
    'toggling - [ ] a writes - [x] a and verifies writeCount == 1',
    () async {
      final fs = MemoryVaultFileSystem();
      final path = VaultPath('task.md');
      await fs.writeText(path, const TextDocument(text: '- [ ] a\n'));
      fs.writeCount = 0;

      final doc = NoteDocument(path: path, fs: fs, clock: clock);
      await doc.load();

      final parsed = MarkdownParser.parse(doc.text);
      expect(parsed.tasks.length, equals(1));
      final task = parsed.tasks.first;

      final result = await toggler.toggleTask(doc, task, 'x');
      expect(result, isTrue);
      expect(doc.text, equals('- [x] a\n'));
      expect(fs.writeCount, equals(1));

      final fromDisk = await fs.readText(path);
      expect(fromDisk.text, equals('- [x] a\n'));
    },
  );

  test('toggling x -> space and / -> space', () async {
    final fs = MemoryVaultFileSystem();
    final path = VaultPath('task.md');
    await fs.writeText(
      path,
      const TextDocument(text: '- [x] first\n- [/] second\n'),
    );
    final doc = NoteDocument(path: path, fs: fs, clock: clock);
    await doc.load();

    var parsed = MarkdownParser.parse(doc.text);
    expect(parsed.tasks.length, equals(2));

    // Toggle x -> ' '
    final res1 = await toggler.toggleTask(doc, parsed.tasks[0], ' ');
    expect(res1, isTrue);
    expect(doc.text, equals('- [ ] first\n- [/] second\n'));

    // Re-parse and toggle / -> ' '
    parsed = MarkdownParser.parse(doc.text);
    final res2 = await toggler.toggleTask(doc, parsed.tasks[1], ' ');
    expect(res2, isTrue);
    expect(doc.text, equals('- [ ] first\n- [ ] second\n'));
  });

  test('stale offset returns false and does not write', () async {
    final fs = MemoryVaultFileSystem();
    final path = VaultPath('task.md');
    await fs.writeText(path, const TextDocument(text: '- [ ] initial\n'));
    final doc = NoteDocument(path: path, fs: fs, clock: clock);
    await doc.load();

    final parsed = MarkdownParser.parse(doc.text);
    final task = parsed.tasks.first;

    // Document is modified behind the reading view's back
    doc.setText('Some new prefix\n- [ ] initial\n');
    fs.writeCount = 0;

    final result = await toggler.toggleTask(doc, task, 'x');
    expect(result, isFalse);
    expect(fs.writeCount, equals(0));
    expect(doc.text, equals('Some new prefix\n- [ ] initial\n'));
  });

  test('read-only document does not toggle and does not write', () async {
    final fs = MemoryVaultFileSystem();
    final path = VaultPath('task.md');
    // Malformed UTF-8 bytes makes TextDocument malformed and NoteDocument read-only
    await fs.writeBytes(path, const [45, 32, 91, 32, 93, 32, 0xC0, 0xAF, 10]);
    final doc = NoteDocument(path: path, fs: fs, clock: clock);
    await doc.load();
    expect(doc.isReadOnly, isTrue);

    final parsed = MarkdownParser.parse(doc.text);
    expect(parsed.tasks.isNotEmpty, isTrue);
    final task = parsed.tasks.first;
    fs.writeCount = 0;

    final result = await toggler.toggleTask(doc, task, 'x');
    expect(result, isFalse);
    expect(fs.writeCount, equals(0));
  });

  test('CRLF line endings are preserved on save', () async {
    final fs = MemoryVaultFileSystem();
    final path = VaultPath('crlf.md');
    await fs.writeBytes(
      path,
      const [45, 32, 91, 32, 93, 32, 97, 13, 10], // "- [ ] a\r\n"
    );
    final doc = NoteDocument(path: path, fs: fs, clock: clock);
    await doc.load();
    expect(doc.base.lineEnding, equals(LineEnding.crlf));

    final parsed = MarkdownParser.parse(doc.text);
    final task = parsed.tasks.first;

    final result = await toggler.toggleTask(doc, task, 'x');
    expect(result, isTrue);

    final rawBytes = await fs.readBytes(path);
    expect(
      rawBytes,
      equals(const [45, 32, 91, 120, 93, 32, 97, 13, 10]),
    ); // "- [x] a\r\n"
  });

  test('UTF-8 BOM is preserved on save', () async {
    final fs = MemoryVaultFileSystem();
    final path = VaultPath('bom.md');
    await fs.writeBytes(
      path,
      const [
        0xEF,
        0xBB,
        0xBF,
        45,
        32,
        91,
        32,
        93,
        32,
        97,
        10,
      ], // BOM + "- [ ] a\n"
    );
    final doc = NoteDocument(path: path, fs: fs, clock: clock);
    await doc.load();
    expect(doc.base.hasBom, isTrue);

    final parsed = MarkdownParser.parse(doc.text);
    final task = parsed.tasks.first;

    final result = await toggler.toggleTask(doc, task, 'x');
    expect(result, isTrue);

    final rawBytes = await fs.readBytes(path);
    expect(
      rawBytes,
      equals(const [0xEF, 0xBB, 0xBF, 45, 32, 91, 120, 93, 32, 97, 10]),
    );
  });

  test(
    'non-ASCII Bangla text before checkbox preserves offset correctness',
    () async {
      final fs = MemoryVaultFileSystem();
      final path = VaultPath('bangla.md');
      // Bangla line before the task list item
      const content = '# শিরোনাম\nবাংলা বিবরণ লাইন\n\n- [ ] কাজ\n';
      await fs.writeText(path, const TextDocument(text: content));

      final doc = NoteDocument(path: path, fs: fs, clock: clock);
      await doc.load();

      final parsed = MarkdownParser.parse(doc.text);
      expect(parsed.tasks.length, equals(1));
      final task = parsed.tasks.first;

      final result = await toggler.toggleTask(doc, task, 'x');
      expect(result, isTrue);
      expect(doc.text, equals('# শিরোনাম\nবাংলা বিবরণ লাইন\n\n- [x] কাজ\n'));
    },
  );

  test('task with surrogate pair emoji status is replaced fully', () async {
    final fs = MemoryVaultFileSystem();
    final path = VaultPath('emoji.md');
    // '🔥' is U+1F525 (2 UTF-16 code units: 0xD83D, 0xDD25)
    const content = '- [🔥] fire task\n';
    await fs.writeText(path, const TextDocument(text: content));

    final doc = NoteDocument(path: path, fs: fs, clock: clock);
    await doc.load();

    final parsed = MarkdownParser.parse(doc.text);
    expect(parsed.tasks.length, equals(1));
    final task = parsed.tasks.first;
    expect(task.status.char, equals('🔥'));
    expect(task.status.char.length, equals(2));

    final result = await toggler.toggleTask(doc, task, ' ');
    expect(result, isTrue);
    expect(doc.text, equals('- [ ] fire task\n'));
  });
}
