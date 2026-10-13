// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/vault/note_document_store.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

void main() {
  final clock = ManualClock(DateTime(2026, 10, 11, 9, 30));

  test('two acquires return the same instance', () {
    final fs = MemoryVaultFileSystem();
    final store = NoteDocumentStore(fs, clock);
    final path = VaultPath('note.md');

    final doc1 = store.acquire(path);
    final doc2 = store.acquire(path);

    expect(identical(doc1, doc2), isTrue);
  });

  test('release twice then third acquire creates a new instance', () async {
    final fs = MemoryVaultFileSystem();
    final store = NoteDocumentStore(fs, clock);
    final path = VaultPath('note.md');

    final doc1 = store.acquire(path);
    final doc2 = store.acquire(path);
    expect(identical(doc1, doc2), isTrue);

    store.release(path);
    expect(store.peek(path), isNotNull);

    store.release(path);
    expect(store.peek(path), isNull);

    final doc3 = store.acquire(path);
    expect(identical(doc1, doc3), isFalse);
  });

  test('dirty doc is saved on last release', () async {
    final fs = MemoryVaultFileSystem();
    final store = NoteDocumentStore(fs, clock);
    final path = VaultPath('note.md');
    await fs.writeText(path, const TextDocument(text: 'Initial'));
    fs.writeCount = 0;

    final doc = store.acquire(path);
    await pumpEventQueue();

    doc.setText('Changed');
    expect(doc.isDirty, isTrue);

    store.release(path);
    await pumpEventQueue();

    expect(fs.writeCount, equals(1));
    final readBack = await fs.readText(path);
    expect(readBack.text, equals('Changed'));
  });

  test(
    'retargetPath file and folder forms re-key and update doc.path',
    () async {
      final fs = MemoryVaultFileSystem();
      final store = NoteDocumentStore(fs, clock);

      // File form
      final fileFrom = VaultPath('a.md');
      final fileTo = VaultPath('b.md');
      final docFile = store.acquire(fileFrom);
      await pumpEventQueue();

      store.retargetPath(fileFrom, fileTo);
      expect(docFile.path, equals(fileTo));
      expect(store.peek(fileFrom), isNull);
      expect(store.peek(fileTo), equals(docFile));

      // Folder form
      final folderFrom = VaultPath('Folder');
      final folderTo = VaultPath('NewFolder');
      final nestedPath = VaultPath('Folder/note.md');
      final docFolder = store.acquire(nestedPath);
      await pumpEventQueue();

      store.retargetPath(folderFrom, folderTo);
      final expectedNewNested = VaultPath('NewFolder/note.md');
      expect(docFolder.path, equals(expectedNewNested));
      expect(store.peek(nestedPath), isNull);
      expect(store.peek(expectedNewNested), equals(docFolder));
    },
  );

  test('flushPath saves dirty docs within path', () async {
    final fs = MemoryVaultFileSystem();
    final store = NoteDocumentStore(fs, clock);

    final p1 = VaultPath('Folder/one.md');
    final p2 = VaultPath('Folder/Sub/two.md');
    final p3 = VaultPath('Other/three.md');

    await fs.writeText(p1, const TextDocument(text: 'one'));
    await fs.writeText(p2, const TextDocument(text: 'two'));
    await fs.writeText(p3, const TextDocument(text: 'three'));
    fs.writeCount = 0;

    final doc1 = store.acquire(p1);
    final doc2 = store.acquire(p2);
    final doc3 = store.acquire(p3);
    await pumpEventQueue();

    doc1.setText('one changed');
    doc2.setText('two changed');
    doc3.setText('three changed');

    await store.flushPath(VaultPath('Folder'));

    expect(doc1.isDirty, isFalse);
    expect(doc2.isDirty, isFalse);
    expect(doc3.isDirty, isTrue); // Not in Folder

    final r1 = await fs.readText(p1);
    final r2 = await fs.readText(p2);
    final r3 = await fs.readText(p3);
    expect(r1.text, equals('one changed'));
    expect(r2.text, equals('two changed'));
    expect(r3.text, equals('three'));
  });

  test('discardPath drops without writing', () async {
    final fs = MemoryVaultFileSystem();
    final store = NoteDocumentStore(fs, clock);
    final path = VaultPath('Folder/note.md');
    await fs.writeText(path, const TextDocument(text: 'Original'));
    fs.writeCount = 0;

    final doc = store.acquire(path);
    await pumpEventQueue();

    doc.setText('Modified');
    expect(doc.isDirty, isTrue);

    store.discardPath(VaultPath('Folder'));
    expect(store.peek(path), isNull);
    expect(fs.writeCount, equals(0));

    final r = await fs.readText(path);
    expect(r.text, equals('Original'));
  });
}
