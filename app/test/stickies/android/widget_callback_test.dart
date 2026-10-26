// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/stickies/android/widget_callback.dart';
import 'package:tephra/stickies/android/widget_data.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

void main() {
  group('handleWidgetToggle', () {
    late MemoryVaultFileSystem fs;
    const testPath = 'Stickies/Test.md';

    setUp(() {
      fs = MemoryVaultFileSystem();
    });

    tearDown(() async {
      await fs.dispose();
    });

    test('toggles line when hash matches', () async {
      const initialText = '''---
tephra-sticky: true
---
# Checklist
- [ ] First task
- [x] Second task''';

      await fs.writeText(VaultPath(testPath), TextDocument(text: initialText));
      final hash = stickyProtocolHash(initialText);

      // Line 4 is `- [ ] First task`
      final result = await handleWidgetToggle(fs, testPath, 4, hash);
      expect(result, isA<WidgetToggleSuccess>());

      final updatedBytes = await fs.readBytes(VaultPath(testPath));
      final updatedDoc = TextDocument.decode(updatedBytes);
      expect(
        updatedDoc.text,
        equals('''---
tephra-sticky: true
---
# Checklist
- [x] First task
- [x] Second task'''),
      );
    });

    test('stale hash does not toggle', () async {
      const initialText = '''---
tephra-sticky: true
---
- [ ] Task''';

      await fs.writeText(VaultPath(testPath), TextDocument(text: initialText));

      final result = await handleWidgetToggle(fs, testPath, 3, 'stale-hash');
      expect(result, isA<WidgetToggleStaleHash>());

      final doc = TextDocument.decode(await fs.readBytes(VaultPath(testPath)));
      expect(doc.text, equals(initialText));
    });

    test('non-task line does nothing', () async {
      const initialText = '''---
tephra-sticky: true
---
# Regular Heading
Some plain text''';

      await fs.writeText(VaultPath(testPath), TextDocument(text: initialText));
      final hash = stickyProtocolHash(initialText);

      // Line 3 is `# Regular Heading`
      final result = await handleWidgetToggle(fs, testPath, 3, hash);
      expect(result, isA<WidgetToggleNotTask>());

      final doc = TextDocument.decode(await fs.readBytes(VaultPath(testPath)));
      expect(doc.text, equals(initialText));
    });

    test('file changed between read and write is not overwritten', () async {
      const initialText = '- [ ] Task 1';
      await fs.writeText(VaultPath(testPath), TextDocument(text: initialText));
      final hash = stickyProtocolHash(initialText);

      final raceFs = _RaceVaultFileSystem(
        fs,
        onAfterFirstRead: () async {
          await fs.writeText(
            VaultPath(testPath),
            TextDocument(text: '- [ ] Task 1 - concurrently modified'),
          );
        },
      );

      final result = await handleWidgetToggle(raceFs, testPath, 0, hash);
      expect(result, isA<WidgetToggleConflict>());

      final doc = TextDocument.decode(await fs.readBytes(VaultPath(testPath)));
      expect(doc.text, equals('- [ ] Task 1 - concurrently modified'));
    });
  });
}

class _RaceVaultFileSystem implements VaultFileSystem {
  _RaceVaultFileSystem(this._inner, {required this.onAfterFirstRead});

  final MemoryVaultFileSystem _inner;
  final Future<void> Function() onAfterFirstRead;
  int _readCount = 0;

  @override
  String get rootDisplayPath => _inner.rootDisplayPath;

  @override
  Future<List<VaultEntry>> list({
    VaultPath folder = VaultPath.root,
    bool recursive = true,
  }) => _inner.list(folder: folder, recursive: recursive);

  @override
  Future<VaultEntry?> stat(VaultPath path) => _inner.stat(path);

  @override
  Future<List<int>> readBytes(VaultPath path) async {
    _readCount++;
    final bytes = await _inner.readBytes(path);
    if (_readCount == 1) {
      await onAfterFirstRead();
    }
    return bytes;
  }

  @override
  Future<TextDocument> readText(VaultPath path) => _inner.readText(path);

  @override
  Future<void> writeBytes(VaultPath path, List<int> bytes) =>
      _inner.writeBytes(path, bytes);

  @override
  Future<void> writeText(VaultPath path, TextDocument doc) =>
      _inner.writeText(path, doc);

  @override
  Future<void> createFolder(VaultPath path) => _inner.createFolder(path);

  @override
  Future<void> move(VaultPath from, VaultPath to) => _inner.move(from, to);

  @override
  Future<void> delete(
    VaultPath path, {
    TrashMode mode = TrashMode.vaultTrash,
  }) => _inner.delete(path, mode: mode);

  @override
  Stream<VaultChange> watch() => _inner.watch();

  @override
  Future<void> dispose() => _inner.dispose();
}
