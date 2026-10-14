// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/editor/edit_operation.dart';
import 'package:tephra/vault/note_document.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

final class _FailingVaultFileSystem implements VaultFileSystem {
  _FailingVaultFileSystem(this._inner);

  final MemoryVaultFileSystem _inner;
  bool shouldFail = false;

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
  Future<List<int>> readBytes(VaultPath path) => _inner.readBytes(path);

  @override
  Future<TextDocument> readText(VaultPath path) => _inner.readText(path);

  @override
  Future<void> writeBytes(VaultPath path, List<int> bytes) async {
    if (shouldFail) {
      throw const PermissionDeniedException('write denied');
    }
    return _inner.writeBytes(path, bytes);
  }

  @override
  Future<void> writeText(VaultPath path, TextDocument doc) async {
    if (shouldFail) {
      throw const PermissionDeniedException('write denied');
    }
    return _inner.writeText(path, doc);
  }

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

final class _FakeNoteEditorBinding implements NoteEditorBinding {
  _FakeNoteEditorBinding(this.currentText);

  String currentText;
  EditOperation? lastAppliedEdit;
  bool replaceAllCalled = false;

  @override
  String readText() => currentText;

  @override
  void applyEdit(EditOperation op) {
    lastAppliedEdit = op;
    currentText = op.applyTo(currentText);
  }

  @override
  void replaceAll(
    String text, {
    required bool keepCursor,
    bool clearHistory = false,
  }) {
    replaceAllCalled = true;
    currentText = text;
  }
}

void main() {
  final clock = ManualClock(DateTime(2026, 10, 11, 9, 30));

  test('load decodes flags', () async {
    final fs = MemoryVaultFileSystem();
    final path = VaultPath('note.md');
    final rawBytes = [
      0xEF, 0xBB, 0xBF, // BOM
      ...utf8.encode('Line 1\r\nLine 2\r\n'),
    ];
    await fs.writeBytes(path, rawBytes);

    final doc = NoteDocument(path: path, fs: fs, clock: clock);
    await doc.load();

    expect(doc.isLoaded, isTrue);
    expect(doc.base.hasBom, isTrue);
    expect(doc.base.lineEnding, equals(LineEnding.crlf));
    expect(doc.text.contains('\r'), isFalse);
    expect(doc.text, equals('Line 1\nLine 2\n'));
    expect(doc.isDirty, isFalse);
  });

  test('save without edit writes nothing', () async {
    final fs = MemoryVaultFileSystem();
    final path = VaultPath('note.md');
    final rawBytes = [0xEF, 0xBB, 0xBF, ...utf8.encode('Hello\r\n')];
    await fs.writeBytes(path, rawBytes);
    fs.writeCount = 0;

    final doc = NoteDocument(path: path, fs: fs, clock: clock);
    await doc.load();

    final outcome = await doc.save();
    expect(outcome, equals(SaveOutcome.unchanged));
    expect(fs.writeCount, equals(0));
    final readBack = await fs.readBytes(path);
    expect(readBack, equals(rawBytes));
  });

  test('edit then undo to original writes nothing', () async {
    final fs = MemoryVaultFileSystem();
    final path = VaultPath('note.md');
    const original = 'Initial content';
    await fs.writeText(path, const TextDocument(text: original));
    fs.writeCount = 0;

    final doc = NoteDocument(path: path, fs: fs, clock: clock);
    await doc.load();

    doc.setText('x');
    expect(doc.isDirty, isTrue);
    doc.setText(original);
    expect(doc.isDirty, isFalse);

    final outcome = await doc.save();
    expect(outcome, equals(SaveOutcome.unchanged));
    expect(fs.writeCount, equals(0));
  });

  test('edit keeps BOM and CRLF', () async {
    final fs = MemoryVaultFileSystem();
    final path = VaultPath('note.md');
    final rawBytes = [0xEF, 0xBB, 0xBF, ...utf8.encode('Hello\r\nWorld\r\n')];
    await fs.writeBytes(path, rawBytes);

    final doc = NoteDocument(path: path, fs: fs, clock: clock);
    await doc.load();

    final original = doc.text;
    doc.setText('${original}z');
    final outcome = await doc.save();

    expect(outcome, equals(SaveOutcome.written));
    expect(doc.isDirty, isFalse);
    expect(doc.savedText, equals('${original}z'));

    final writtenBytes = await fs.readBytes(path);
    expect(writtenBytes.sublist(0, 3), equals([0xEF, 0xBB, 0xBF]));
    final writtenText = utf8.decode(writtenBytes.sublist(3));
    expect(writtenText, equals('Hello\r\nWorld\r\nz'));
  });

  test('mixed endings use dominant on edit', () async {
    final fs = MemoryVaultFileSystem();
    final path = VaultPath('mixed-endings.md');
    // 3 LF, 2 CRLF -> dominant is LF
    final mixedBytes = utf8.encode('L1\nL2\r\nL3\nL4\r\nL5\n');
    await fs.writeBytes(path, mixedBytes);

    final doc = NoteDocument(path: path, fs: fs, clock: clock);
    await doc.load();
    expect(doc.base.lineEnding, equals(LineEnding.lf));

    doc.setText('${doc.text}new');
    await doc.save();

    final written = await fs.readBytes(path);
    final str = utf8.decode(written);
    expect(str.contains('\r'), isFalse);
  });

  test('malformed is read only', () async {
    final fs = MemoryVaultFileSystem();
    final path = VaultPath('bad.md');
    final badBytes = [0x61, 0xFF];
    await fs.writeBytes(path, badBytes);

    final doc = NoteDocument(path: path, fs: fs, clock: clock);
    await doc.load();

    expect(doc.isReadOnly, isTrue);
    expect(doc.edit(const EditOperation(0, 0, 'more')), isFalse);
    final outcome = await doc.save();
    expect(outcome, equals(SaveOutcome.readOnly));
    final readBack = await fs.readBytes(path);
    expect(readBack, equals(badBytes));
  });

  test('edit applies operation', () async {
    final fs = MemoryVaultFileSystem();
    final path = VaultPath('note.md');
    await fs.writeText(path, const TextDocument(text: 'Title'));

    final doc = NoteDocument(path: path, fs: fs, clock: clock);
    await doc.load();
    final initialRev = doc.revision;

    final success = doc.edit(const EditOperation(0, 0, '# '));
    expect(success, isTrue);
    expect(doc.text, equals('# Title'));
    expect(doc.revision, equals(initialRev + 1));

    final invalidSuccess = doc.edit(const EditOperation(100, 200, 'boom'));
    expect(invalidSuccess, isFalse);
    expect(doc.text, equals('# Title'));
    expect(doc.revision, equals(initialRev + 1));
  });

  test('failed write keeps the buffer', () async {
    final inner = MemoryVaultFileSystem();
    final fs = _FailingVaultFileSystem(inner);
    final path = VaultPath('note.md');
    await inner.writeText(path, const TextDocument(text: 'Original'));

    final doc = NoteDocument(path: path, fs: fs, clock: clock);
    await doc.load();

    doc.setText('Modified');
    fs.shouldFail = true;

    final outcome = await doc.save();
    expect(outcome, equals(SaveOutcome.failed));
    expect(doc.saveState, equals(SaveState.error));
    expect(doc.isDirty, isTrue);
    expect(doc.lastError, isNotNull);
    expect(doc.text, equals('Modified'));
  });

  test('missing file', () async {
    final fs = MemoryVaultFileSystem();
    final path = VaultPath('missing.md');

    final doc = NoteDocument(path: path, fs: fs, clock: clock);
    await doc.load();

    expect(doc.isLoaded, isTrue);
    expect(doc.isMissing, isTrue);
    expect(doc.text, isEmpty);
  });

  test('attached editor is the source of text', () async {
    final fs = MemoryVaultFileSystem();
    final path = VaultPath('note.md');
    await fs.writeText(path, const TextDocument(text: 'Disk'));

    final doc = NoteDocument(path: path, fs: fs, clock: clock);
    await doc.load();

    final fakeEditor = _FakeNoteEditorBinding('live');
    doc.attachEditor(fakeEditor);
    expect(doc.text, equals('live'));

    doc.notifyEditorChanged();
    expect(doc.saveState, equals(SaveState.unsaved));

    final editOp = const EditOperation(0, 0, 'new ');
    final editSuccess = doc.edit(editOp);
    expect(editSuccess, isTrue);
    expect(fakeEditor.lastAppliedEdit, equals(editOp));
    expect(doc.text, equals('new live'));

    doc.detachEditor(fakeEditor);
    expect(doc.text, equals('new live'));
  });

  test('empty file stays empty', () async {
    final fs = MemoryVaultFileSystem();
    final path = VaultPath('empty.md');
    await fs.writeBytes(path, []);

    final doc = NoteDocument(path: path, fs: fs, clock: clock);
    await doc.load();

    expect(doc.text, isEmpty);
    doc.setText('');
    final outcome = await doc.save();
    expect(outcome, equals(SaveOutcome.unchanged));
  });
}
