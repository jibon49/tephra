// © 2026 Tephra. All rights reserved.

import 'dart:io';
import 'dart:math';
import 'package:drift/drift.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/src/testing/index_dump.dart';
import 'package:tephra_index/tephra_index.dart';
import 'package:tephra_vault/tephra_vault.dart';
import 'package:test/test.dart';

class _IncrementingClock implements Clock {
  DateTime _current = DateTime.utc(2026, 1, 1);

  @override
  DateTime now() {
    _current = _current.add(const Duration(milliseconds: 10));
    return _current;
  }
}

const folders = ['', 'A', 'A/B', 'C', 'বাংলা'];
final noteNames = [
  for (var i = 0; i < 30; i++) 'Note$i',
  'Café0',
  'Café1',
  'নোট0',
  'নোট1',
];
final aliasNames = [for (var i = 0; i < 8; i++) 'Alias$i'];
const tags = ['t0', 't1', 't2', 't3', 't4', 't5', 't0/sub'];
final attachments = [for (var i = 0; i < 4; i++) 'img$i.png'];

VaultPath _makePath(String folder, String name) {
  return folder.isEmpty ? VaultPath(name) : VaultPath('$folder/$name');
}

String _generateNoteContent(Random rng, String noteName) {
  final sb = StringBuffer();

  // 50% optional frontmatter
  if (rng.nextBool()) {
    sb.writeln('---');
    final aliasCount = rng.nextInt(3);
    final chosenAliases = <String>{};
    for (var i = 0; i < aliasCount; i++) {
      chosenAliases.add(aliasNames[rng.nextInt(aliasNames.length)]);
    }
    if (chosenAliases.isNotEmpty) {
      sb.writeln('aliases: [${chosenAliases.join(', ')}]');
    }

    final tagCount = rng.nextInt(3);
    final chosenTags = <String>{};
    for (var i = 0; i < tagCount; i++) {
      chosenTags.add(tags[rng.nextInt(tags.length)]);
    }
    if (chosenTags.isNotEmpty) {
      sb.writeln('tags: [${chosenTags.join(', ')}]');
    }

    sb.writeln('status: ${rng.nextBool() ? 'draft' : 'done'}');
    sb.writeln('n: ${rng.nextInt(100)}');
    sb.writeln('---');
  }

  // 3-12 body lines
  final lineCount = 3 + rng.nextInt(10);
  for (var i = 0; i < lineCount; i++) {
    final lineType = rng.nextInt(12);
    switch (lineType) {
      case 0:
        sb.writeln('# Heading ${rng.nextInt(5)}');
      case 1:
        sb.writeln('## Heading ${rng.nextInt(5)}');
      case 2:
        final target = noteNames[rng.nextInt(noteNames.length)];
        sb.writeln('Link to [[$target]] here.');
      case 3:
        final f = folders[rng.nextInt(folders.length)];
        final n = noteNames[rng.nextInt(noteNames.length)];
        final target = f.isEmpty ? n : '$f/$n';
        sb.writeln('Folder link [[$target]] in note.');
      case 4:
        final target = noteNames[rng.nextInt(noteNames.length)];
        sb.writeln('Subpath link [[$target#Heading 1]].');
      case 5:
        final alias = aliasNames[rng.nextInt(aliasNames.length)];
        sb.writeln('Alias link [[$alias]].');
      case 6:
        final img = attachments[rng.nextInt(attachments.length)];
        sb.writeln('Embed ![[$img]].');
      case 7:
        final target = noteNames[rng.nextInt(noteNames.length)];
        sb.writeln('Markdown link [t]($target.md).');
      case 8:
        final f = folders[rng.nextInt(folders.length)];
        final n = noteNames[rng.nextInt(noteNames.length)];
        final path = f.isEmpty ? '$n.md' : '${Uri.encodeComponent(f)}/$n.md';
        sb.writeln('Encoded link [t]($path).');
      case 9:
        final tag = tags[rng.nextInt(tags.length)];
        sb.writeln('Tag reference #$tag.');
      case 10:
        final done = rng.nextBool();
        sb.writeln('- [${done ? 'x' : ' '}] task ${rng.nextInt(10)}');
      case 11:
        if (rng.nextBool()) {
          sb.writeln('Paragraph with block id ^b${rng.nextInt(10)}');
        } else {
          final probe = ftsProbeWords[rng.nextInt(ftsProbeWords.length)];
          sb.writeln('Some text with $probe probe word.');
        }
    }
  }

  return sb.toString();
}

Future<void> runFuzz({
  required int seed,
  required int totalOps,
  required int checkInterval,
}) async {
  final clock = _IncrementingClock();
  final fs = MemoryVaultFileSystem(clock: clock);
  final index = await NoteIndex.open(':memory:', fs, clock: clock);
  final rng = Random(seed);

  final activeNotes = <VaultPath>{};
  final activeAttachments = <VaultPath>{};

  var lastOpDescription = 'init';

  Future<void> createNoteOp() async {
    final folder = folders[rng.nextInt(folders.length)];
    var name = noteNames[rng.nextInt(noteNames.length)];
    var path = _makePath(folder, '$name.md');
    var attempts = 0;
    while (activeNotes.contains(path) && attempts < 20) {
      name = noteNames[rng.nextInt(noteNames.length)];
      path = _makePath(folder, '$name.md');
      attempts++;
    }
    if (activeNotes.contains(path)) {
      name = 'Note${rng.nextInt(10000)}';
      path = _makePath(folder, '$name.md');
    }

    final content = _generateNoteContent(rng, name);
    await fs.writeText(path, TextDocument(text: content));
    await index.onChange(FileCreated(path));
    activeNotes.add(path);
    lastOpDescription = 'create note $path';
  }

  for (var i = 0; i < totalOps; i++) {
    final op = rng.nextInt(100);

    if (op < 25) {
      // 0–24: create note
      await createNoteOp();
    } else if (op < 50) {
      // 25–49: edit existing note
      if (activeNotes.isEmpty) {
        await createNoteOp();
      } else {
        final path = activeNotes.elementAt(rng.nextInt(activeNotes.length));
        final content = _generateNoteContent(rng, path.stem);
        await fs.writeText(path, TextDocument(text: content));
        await index.onChange(FileModified(path));
        lastOpDescription = 'edit note $path';
      }
    } else if (op < 65) {
      // 50–64: rename/move a note
      if (activeNotes.isEmpty) {
        await createNoteOp();
      } else {
        final oldPath = activeNotes.elementAt(rng.nextInt(activeNotes.length));
        final sameFolder = rng.nextBool();
        final folder = sameFolder
            ? (oldPath.parent?.value ?? '')
            : folders[rng.nextInt(folders.length)];
        final name = sameFolder ? 'Note${rng.nextInt(10000)}' : oldPath.name;
        final newPath = _makePath(folder, name);

        if (newPath == oldPath ||
            activeNotes.contains(newPath) ||
            activeAttachments.contains(newPath)) {
          lastOpDescription = 'skip rename $oldPath -> $newPath';
        } else {
          await fs.move(oldPath, newPath);
          await index.onChange(FileMoved(newPath, from: oldPath));
          activeNotes.remove(oldPath);
          activeNotes.add(newPath);
          lastOpDescription = 'move note $oldPath -> $newPath';
        }
      }
    } else if (op < 75) {
      // 65–74: delete a note
      if (activeNotes.isEmpty) {
        await createNoteOp();
      } else {
        final path = activeNotes.elementAt(rng.nextInt(activeNotes.length));
        await fs.delete(path, mode: TrashMode.permanent);
        await index.onChange(FileDeleted(path));
        activeNotes.remove(path);
        lastOpDescription = 'delete note $path';
      }
    } else if (op < 82) {
      // 75–81: create/overwrite an attachment
      final folder = folders[rng.nextInt(folders.length)];
      final name = attachments[rng.nextInt(attachments.length)];
      final path = _makePath(folder, name);
      final exists = activeAttachments.contains(path);
      final bytes = Uint8List.fromList([rng.nextInt(256), rng.nextInt(256)]);
      await fs.writeBytes(path, bytes);
      await index.onChange(exists ? FileModified(path) : FileCreated(path));
      activeAttachments.add(path);
      lastOpDescription = 'write attachment $path (exists: $exists)';
    } else if (op < 90) {
      // 82–89: move a folder
      final nonRootFolders = folders.where((f) => f.isNotEmpty).toList();
      final candFolders = nonRootFolders.where((f) {
        final prefix = '$f/';
        return activeNotes.any((n) => n.value.startsWith(prefix)) ||
            activeAttachments.any((a) => a.value.startsWith(prefix));
      }).toList();

      if (candFolders.isEmpty) {
        await createNoteOp();
      } else {
        final oldFolder = candFolders[rng.nextInt(candFolders.length)];
        final newTargetName = 'Folder${rng.nextInt(1000)}';
        final newFolder = rng.nextBool() ? newTargetName : 'A/$newTargetName';

        final toPath = VaultPath(newFolder);
        final targetExists =
            await fs.stat(toPath) != null ||
            activeNotes.any(
              (n) => n.value == newFolder || n.value.startsWith('$newFolder/'),
            ) ||
            activeAttachments.any(
              (a) => a.value == newFolder || a.value.startsWith('$newFolder/'),
            );

        if (newFolder == oldFolder ||
            newFolder.startsWith('$oldFolder/') ||
            oldFolder.startsWith('$newFolder/') ||
            targetExists) {
          lastOpDescription = 'skip folder move $oldFolder -> $newFolder';
        } else {
          final oldPrefix = '$oldFolder/';
          final newPrefix = '$newFolder/';
          await fs.move(VaultPath(oldFolder), VaultPath(newFolder));
          await index.onChange(
            FileMoved(VaultPath(newFolder), from: VaultPath(oldFolder)),
          );

          // Update active paths in memory
          final notesToMove = activeNotes
              .where((n) => n.value.startsWith(oldPrefix))
              .toList();
          for (final n in notesToMove) {
            activeNotes.remove(n);
            final rel = n.value.substring(oldPrefix.length);
            activeNotes.add(VaultPath('$newPrefix$rel'));
          }

          final attachToMove = activeAttachments
              .where((a) => a.value.startsWith(oldPrefix))
              .toList();
          for (final a in attachToMove) {
            activeAttachments.remove(a);
            final rel = a.value.substring(oldPrefix.length);
            activeAttachments.add(VaultPath('$newPrefix$rel'));
          }

          lastOpDescription = 'move folder $oldFolder -> $newFolder';
        }
      }
    } else if (op < 95) {
      // 90–94: delete a folder
      final nonRootFolders = folders.where((f) => f.isNotEmpty).toList();
      final candFolders = nonRootFolders.where((f) {
        final prefix = '$f/';
        return activeNotes.any((n) => n.value.startsWith(prefix)) ||
            activeAttachments.any((a) => a.value.startsWith(prefix));
      }).toList();

      if (candFolders.isEmpty) {
        await createNoteOp();
      } else {
        final delFolder = candFolders[rng.nextInt(candFolders.length)];
        final delPrefix = '$delFolder/';
        await fs.delete(VaultPath(delFolder), mode: TrashMode.permanent);
        await index.onChange(FileDeleted(VaultPath(delFolder)));

        activeNotes.removeWhere((n) => n.value.startsWith(delPrefix));
        activeAttachments.removeWhere((a) => a.value.startsWith(delPrefix));
        lastOpDescription = 'delete folder $delFolder';
      }
    } else {
      // 95–99: edit only frontmatter aliases of an existing note
      if (activeNotes.isEmpty) {
        await createNoteOp();
      } else {
        final path = activeNotes.elementAt(rng.nextInt(activeNotes.length));
        final doc = await fs.readText(path);
        final alias1 = aliasNames[rng.nextInt(aliasNames.length)];
        final alias2 = aliasNames[rng.nextInt(aliasNames.length)];

        var text = doc.text;
        if (text.startsWith('---\n')) {
          final endFm = text.indexOf('\n---\n', 4);
          if (endFm != -1) {
            final body = text.substring(endFm + 5);
            text = '---\naliases: [$alias1, $alias2]\n---\n$body';
          } else {
            text = '---\naliases: [$alias1, $alias2]\n---\n$text';
          }
        } else {
          text = '---\naliases: [$alias1, $alias2]\n---\n$text';
        }

        await fs.writeText(path, TextDocument(text: text));
        await index.onChange(FileModified(path));
        lastOpDescription = 'edit aliases of $path';
      }
    }

    if ((i + 1) % checkInterval == 0 || i == totalOps - 1) {
      printOnFailure('seed=$seed op=$i last=$lastOpDescription');
      final fresh = await NoteIndex.open(':memory:', fs, clock: clock);
      await fresh.reconcile();
      final incDump = await dumpIndex(index);
      final freshDump = await dumpIndex(fresh);
      expect(incDump, equals(freshDump));
      await fresh.close();
    }
  }

  await index.close();
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('fuzz smoke (300 ops, seed 7)', () async {
    await runFuzz(seed: 7, totalOps: 300, checkInterval: 100);
  });

  final envSeed = Platform.environment['TEPHRA_FUZZ_SEED'];
  final seeds = envSeed != null ? [int.parse(envSeed)] : [1, 2, 3];
  final envOps = Platform.environment['TEPHRA_FUZZ_OPS'];
  final opsPerSeed = envOps != null ? int.parse(envOps) : 10000;

  for (final seed in seeds) {
    test('fuzz consistency seed=$seed ($opsPerSeed ops)', () async {
      await runFuzz(seed: seed, totalOps: opsPerSeed, checkInterval: 1000);
    }, tags: ['fuzz']);
  }
}
