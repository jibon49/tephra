// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tephra/editor/edit_operation.dart';
import 'package:tephra/vault/note_document.dart';
import 'package:tephra/vault/note_document_store.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import 'recording_fs.dart';

Directory _findVaultsDir() {
  var dir = Directory('test_vaults');
  if (dir.existsSync()) return dir;
  dir = Directory('../test_vaults');
  if (dir.existsSync()) return dir;
  dir = Directory('../../test_vaults');
  if (dir.existsSync()) return dir;
  throw StateError('test_vaults not found');
}

Directory _copyDir(Directory src, String name) {
  final tempDir = Directory.systemTemp.createTempSync(name);
  for (final entity in src.listSync(recursive: true)) {
    final rel = p.relative(entity.path, from: src.path);
    final target = p.join(tempDir.path, rel);
    if (entity is Directory) {
      Directory(target).createSync(recursive: true);
    } else if (entity is File) {
      File(target).parent.createSync(recursive: true);
      entity.copySync(target);
    }
  }
  return tempDir;
}

Future<void> _safeDelete(Directory dir) async {
  for (var attempt = 0; attempt < 5; attempt++) {
    try {
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
      return;
    } catch (_) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }
}

void main() {
  final vaultsDir = _findVaultsDir();

  test('1. open + save without edit writes nothing', () async {
    var totalFiles = 0;
    var totalWrites = 0;
    var changedBytes = 0;

    for (final vaultName in ['syntax', 'edge', 'real']) {
      final srcDir = Directory(p.join(vaultsDir.path, vaultName));
      final tempVault = _copyDir(srcDir, 'roundtrip_no_write_${vaultName}_');
      try {
        final innerFs = IoVaultFileSystem(
          tempVault.path,
          ignore: const VaultIgnore(showHidden: true),
        );
        final recordingFs = RecordingVaultFileSystem(innerFs);
        final store = NoteDocumentStore(recordingFs, const SystemClock());

        final allEntries = await innerFs.list(recursive: true);
        final mdEntries = allEntries
            .where((e) => !e.isFolder && e.path.extension.toLowerCase() == 'md')
            .toList();

        final preBytesMap = <VaultPath, List<int>>{};
        final preMtimeMap = <VaultPath, DateTime>{};

        for (final entry in mdEntries) {
          final filePath = p.join(tempVault.path, entry.path.value);
          final file = File(filePath);
          preBytesMap[entry.path] = file.readAsBytesSync();
          preMtimeMap[entry.path] = file.statSync().modified;
        }

        for (final entry in mdEntries) {
          totalFiles++;
          final doc = store.acquire(entry.path);
          await doc.load();
          final outcome = await doc.save();
          expect(
            outcome == SaveOutcome.unchanged || outcome == SaveOutcome.readOnly,
            isTrue,
            reason:
                'Save outcome for ${entry.path} should be unchanged or readOnly but was $outcome',
          );
          store.release(entry.path);

          final filePath = p.join(tempVault.path, entry.path.value);
          final file = File(filePath);
          final postBytes = file.readAsBytesSync();
          final postMtime = file.statSync().modified;

          final preBytes = preBytesMap[entry.path]!;
          if (postBytes.length != preBytes.length) {
            changedBytes += (postBytes.length - preBytes.length).abs();
          } else {
            for (var i = 0; i < preBytes.length; i++) {
              if (preBytes[i] != postBytes[i]) {
                changedBytes++;
              }
            }
          }
          expect(
            postBytes,
            equals(preBytes),
            reason: 'Bytes changed for ${entry.path}',
          );
          expect(
            postMtime,
            equals(preMtimeMap[entry.path]!),
            reason: 'Mtime changed for ${entry.path}',
          );
        }

        totalWrites += recordingFs.writeCount;
        expect(recordingFs.writeCount, equals(0));
        store.dispose();
        await recordingFs.dispose();
      } finally {
        await _safeDelete(tempVault);
      }
    }

    // Required assertion summary line
    // ignore: avoid_print
    print(
      'ROUNDTRIP files=$totalFiles writes_without_edit=$totalWrites changed_bytes=$changedBytes',
    );
    expect(totalWrites, equals(0));
    expect(changedBytes, equals(0));
    expect(totalFiles, greaterThanOrEqualTo(342));
  });

  test('2. open + edit + undo-to-original + save writes nothing', () async {
    final edgeDir = Directory(p.join(vaultsDir.path, 'edge'));
    final tempVault = _copyDir(edgeDir, 'roundtrip_undo_');
    try {
      final innerFs = IoVaultFileSystem(
        tempVault.path,
        ignore: const VaultIgnore(showHidden: true),
      );
      final recordingFs = RecordingVaultFileSystem(innerFs);
      final store = NoteDocumentStore(recordingFs, const SystemClock());

      final allEntries = await innerFs.list(recursive: true);
      final mdEntries = allEntries
          .where((e) => !e.isFolder && e.path.extension.toLowerCase() == 'md')
          .toList();

      for (final entry in mdEntries) {
        if (entry.path.value == 'malformed-utf8.md') continue;

        final doc = store.acquire(entry.path);
        await doc.load();
        final orig = doc.text;

        doc.setText('${orig}x');
        expect(doc.isDirty, isTrue);

        doc.setText(orig);
        expect(doc.isDirty, isFalse);

        final outcome = await doc.save();
        expect(outcome, equals(SaveOutcome.unchanged));
        store.release(entry.path);
      }

      expect(recordingFs.writeCount, equals(0));
      store.dispose();
      await recordingFs.dispose();
    } finally {
      await _safeDelete(tempVault);
    }
  });

  test('3. open + edit + save keeps BOM and line endings', () async {
    final edgeDir = Directory(p.join(vaultsDir.path, 'edge'));
    final tempVault = _copyDir(edgeDir, 'roundtrip_bom_endings_');
    try {
      final innerFs = IoVaultFileSystem(
        tempVault.path,
        ignore: const VaultIgnore(showHidden: true),
      );
      final recordingFs = RecordingVaultFileSystem(innerFs);
      final store = NoteDocumentStore(recordingFs, const SystemClock());

      final allEntries = await innerFs.list(recursive: true);
      final mdEntries = allEntries
          .where((e) => !e.isFolder && e.path.extension.toLowerCase() == 'md')
          .toList();

      for (final entry in mdEntries) {
        if (entry.path.value == 'malformed-utf8.md') continue;

        final filePath = p.join(tempVault.path, entry.path.value);
        final origBytes = File(filePath).readAsBytesSync();
        final origDoc = TextDocument.decode(origBytes);

        final doc = store.acquire(entry.path);
        await doc.load();

        final editOk = doc.edit(const EditOperation(0, 0, 'Z'));
        expect(editOk, isTrue);

        final outcome = await doc.save();
        expect(outcome, equals(SaveOutcome.written));
        store.release(entry.path);

        final newBytes = File(filePath).readAsBytesSync();
        final expectedEnding = origDoc.lineEnding; // dominant ending
        final expectedDoc = TextDocument(
          text: 'Z${origDoc.text}',
          hasBom: origDoc.hasBom,
          lineEnding: expectedEnding,
        );
        expect(newBytes, equals(expectedDoc.encode()));

        final decoded = TextDocument.decode(newBytes);
        expect(decoded.hasBom, equals(origDoc.hasBom));
        expect(decoded.lineEnding, equals(expectedEnding));
      }

      // Assert no .tephra-tmp- file remains in the folder
      final tmpFiles = tempVault
          .listSync(recursive: true)
          .where((e) => e.path.contains('.tephra-tmp'))
          .toList();
      expect(tmpFiles, isEmpty);

      store.dispose();
      await recordingFs.dispose();
    } finally {
      await _safeDelete(tempVault);
    }
  });

  test('4. malformed-utf8.md', () async {
    final edgeDir = Directory(p.join(vaultsDir.path, 'edge'));
    final tempVault = _copyDir(edgeDir, 'roundtrip_malformed_');
    try {
      final innerFs = IoVaultFileSystem(
        tempVault.path,
        ignore: const VaultIgnore(showHidden: true),
      );
      final recordingFs = RecordingVaultFileSystem(innerFs);
      final store = NoteDocumentStore(recordingFs, const SystemClock());

      final path = VaultPath('malformed-utf8.md');
      final filePath = p.join(tempVault.path, path.value);
      final origBytes = File(filePath).readAsBytesSync();

      final doc = store.acquire(path);
      await doc.load();

      expect(doc.isReadOnly, isTrue);
      final editResult = doc.edit(const EditOperation(0, 0, 'Z'));
      expect(editResult, isFalse);

      final outcome = await doc.save();
      expect(outcome, equals(SaveOutcome.readOnly));
      store.release(path);

      expect(File(filePath).readAsBytesSync(), equals(origBytes));
      expect(recordingFs.writeCount, equals(0));
      store.dispose();
      await recordingFs.dispose();
    } finally {
      await _safeDelete(tempVault);
    }
  });

  test(
    '5. empty.md and only-frontmatter.md and no-trailing-newline.md',
    () async {
      final edgeDir = Directory(p.join(vaultsDir.path, 'edge'));
      final tempVault = _copyDir(edgeDir, 'roundtrip_edge_special_');
      try {
        final innerFs = IoVaultFileSystem(
          tempVault.path,
          ignore: const VaultIgnore(showHidden: true),
        );
        final recordingFs = RecordingVaultFileSystem(innerFs);
        final store = NoteDocumentStore(recordingFs, const SystemClock());

        // no-trailing-newline.md
        {
          final path = VaultPath('no-trailing-newline.md');
          final filePath = p.join(tempVault.path, path.value);
          final doc = store.acquire(path);
          await doc.load();
          doc.edit(const EditOperation(0, 0, 'Z'));
          await doc.save();
          store.release(path);

          final newBytes = File(filePath).readAsBytesSync();
          final newText = utf8.decode(newBytes);
          expect(newText.startsWith('Z'), isTrue);
          expect(
            newText.endsWith('\n'),
            isFalse,
            reason: 'must not add trailing newline',
          );
        }

        // empty.md
        {
          final path = VaultPath('empty.md');
          final filePath = p.join(tempVault.path, path.value);
          final doc = store.acquire(path);
          await doc.load();
          doc.edit(const EditOperation(0, 0, 'Z'));
          await doc.save();
          store.release(path);

          final newBytes = File(filePath).readAsBytesSync();
          expect(utf8.decode(newBytes), equals('Z'));
        }

        // only-frontmatter.md
        {
          final path = VaultPath('only-frontmatter.md');
          final filePath = p.join(tempVault.path, path.value);
          final origBytes = File(filePath).readAsBytesSync();
          final origText = utf8.decode(origBytes);

          final doc = store.acquire(path);
          await doc.load();
          doc.edit(const EditOperation(0, 0, 'Z'));
          await doc.save();
          store.release(path);

          final newBytes = File(filePath).readAsBytesSync();
          expect(utf8.decode(newBytes), equals('Z$origText'));
        }

        store.dispose();
        await recordingFs.dispose();
      } finally {
        await _safeDelete(tempVault);
      }
    },
  );

  test(
    '6. Names: notes with Bangla, emoji, spaces and NFD names open and save',
    () async {
      final edgeDir = Directory(p.join(vaultsDir.path, 'edge'));
      final tempVault = _copyDir(edgeDir, 'roundtrip_names_');
      try {
        final innerFs = IoVaultFileSystem(
          tempVault.path,
          ignore: const VaultIgnore(showHidden: true),
        );
        final recordingFs = RecordingVaultFileSystem(innerFs);
        final store = NoteDocumentStore(recordingFs, const SystemClock());

        final specialNames = [
          'নোট.md',
          '🌋 Volcano.md',
          'Spaces in name.md',
          'unicode-nfd.md',
        ];

        for (final name in specialNames) {
          final path = VaultPath(name);
          final filePath = p.join(tempVault.path, path.value);
          final file = File(filePath);
          expect(file.existsSync(), isTrue, reason: '$name should exist');

          final origBytes = file.readAsBytesSync();
          final origDoc = TextDocument.decode(origBytes);

          final doc = store.acquire(path);
          await doc.load();
          expect(doc.text, equals(origDoc.text));

          // Edit + save
          final editOk = doc.edit(const EditOperation(0, 0, '# '));
          expect(editOk, isTrue);
          final outcome = await doc.save();
          expect(outcome, equals(SaveOutcome.written));
          store.release(path);

          final newBytes = file.readAsBytesSync();
          final newDoc = TextDocument.decode(newBytes);
          expect(newDoc.text, equals('# ${origDoc.text}'));
        }

        store.dispose();
        await recordingFs.dispose();
      } finally {
        await _safeDelete(tempVault);
      }
    },
  );
}
