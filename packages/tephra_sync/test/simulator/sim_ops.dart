// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_sync/tephra_sync.dart';
import 'package:tephra_vault/tephra_vault.dart';

import 'sim_device.dart';
import 'sim_world.dart';

/// The 15 distinct operations simulated in multi-device fuzz testing.
enum SimOpKind {
  editLines(30),
  createNote(10),
  createBinary(3),
  overwriteBinary(3),
  deleteFile(6),
  renameFile(4),
  moveFile(3),
  caseOnlyRename(2),
  renameFolder(1),
  editFrontmatter(3),
  syncDevice(25),
  goOffline(3),
  goOnline(3),
  syncWithCrash(3),
  sameLineScenario(1);

  const SimOpKind(this.weight);

  /// Selection weight out of 100.
  final int weight;

  /// Chooses a random operation according to configured weights.
  static SimOpKind choose(Random random) {
    var roll = random.nextInt(100);
    for (final op in SimOpKind.values) {
      if (roll < op.weight) return op;
      roll -= op.weight;
    }
    return SimOpKind.editLines;
  }
}

/// Dispatches simulator operations on [SimWorld].
abstract final class SimOps {
  /// Executes a single randomly weighted operation on [world].
  static Future<void> executeRandomOp(SimWorld world) async {
    final op = SimOpKind.choose(world.random);
    await executeOp(world, op);
    world.advanceClock();
  }

  /// Executes the specified [op] on [world].
  static Future<void> executeOp(SimWorld world, SimOpKind op) async {
    switch (op) {
      case SimOpKind.editLines:
        await _editLines(world);
        break;
      case SimOpKind.createNote:
        await _createNote(world);
        break;
      case SimOpKind.createBinary:
        await _createBinary(world);
        break;
      case SimOpKind.overwriteBinary:
        await _overwriteBinary(world);
        break;
      case SimOpKind.deleteFile:
        await _deleteFile(world);
        break;
      case SimOpKind.renameFile:
        await _renameFile(world);
        break;
      case SimOpKind.moveFile:
        await _moveFile(world);
        break;
      case SimOpKind.caseOnlyRename:
        await _caseOnlyRename(world);
        break;
      case SimOpKind.renameFolder:
        await _renameFolder(world);
        break;
      case SimOpKind.editFrontmatter:
        await _editFrontmatter(world);
        break;
      case SimOpKind.syncDevice:
        await _syncDevice(world);
        break;
      case SimOpKind.goOffline:
        _goOffline(world);
        break;
      case SimOpKind.goOnline:
        _goOnline(world);
        break;
      case SimOpKind.syncWithCrash:
        await _syncWithCrash(world);
        break;
      case SimOpKind.sameLineScenario:
        await _sameLineScenario(world);
        break;
    }
  }

  static Future<void> _editLines(SimWorld world) async {
    final dev = world.randomDevice();
    final notes = await world.listParticipatingNotes(dev);
    if (notes.isEmpty) {
      await _createNote(world, targetDevice: dev);
      return;
    }

    final path = notes[world.random.nextInt(notes.length)];
    final existingBytes = await dev.fs.readBytes(path);
    await dev.localHistory.snapshot(
      path,
      existingBytes,
      reason: SnapshotReason.editing,
    );
    final content = utf8.decode(existingBytes);
    final lines = content.split('\n');

    final numChanges = 1 + world.random.nextInt(3);
    for (var c = 0; c < numChanges; c++) {
      final action = world.random.nextInt(3);
      if (lines.isEmpty || action == 0) {
        // Insert
        final at = lines.isEmpty ? 0 : world.random.nextInt(lines.length);
        lines.insert(
          at,
          'Inserted line ${world.opCount} from ${dev.name}: ${world.random.nextInt(1000)}',
        );
      } else if (action == 1 && lines.length > 1) {
        // Delete
        final at = world.random.nextInt(lines.length);
        lines.removeAt(at);
      } else {
        // Replace
        final at = world.random.nextInt(lines.length);
        lines[at] =
            'Replaced line ${world.opCount} from ${dev.name}: ${world.random.nextInt(1000)}';
      }
    }

    final newContent = lines.join('\n');
    await dev.fs.writeBytes(path, utf8.encode(newContent));
    world.logOp('editLines on ${dev.name}: ${path.value}');
  }

  static Future<void> _createNote(
    SimWorld world, {
    SimDevice? targetDevice,
  }) async {
    final dev = targetDevice ?? world.randomDevice();

    final folderChoices = ['', 'folder1', 'folder2/sub'];
    final folder = folderChoices[world.random.nextInt(folderChoices.length)];

    String fileName;
    final fileNum = world.random.nextInt(12);

    // Occasionally use mixed casing
    final isCapitalized = world.random.nextBool();
    final stem = isCapitalized ? 'Note_$fileNum' : 'note_$fileNum';

    // On Android, 5% of the time test invalid Windows names
    if (!dev.isWindows && world.random.nextInt(20) == 0) {
      fileName = 'invalid:name_$fileNum.md';
    } else {
      fileName = '$stem.md';
    }

    final path = folder.isEmpty
        ? VaultPath.raw(fileName)
        : VaultPath.raw('$folder/$fileName');

    final lineCount = 1 + world.random.nextInt(40);
    final buffer = StringBuffer();
    buffer.writeln('# $stem');
    for (var i = 1; i <= lineCount; i++) {
      buffer.writeln('Line $i of $stem created by ${dev.name}');
    }

    final stat = await dev.fs.stat(path);
    if (stat != null) {
      final existingBytes = await dev.fs.readBytes(path);
      await dev.localHistory.snapshot(
        path,
        existingBytes,
        reason: SnapshotReason.editing,
      );
    }

    await dev.fs.writeBytes(path, utf8.encode(buffer.toString()));
    world.logOp('createNote on ${dev.name}: ${path.value} ($lineCount lines)');
  }

  static Future<void> _createBinary(SimWorld world) async {
    final dev = world.randomDevice();
    final id = world.random.nextInt(8);
    final ext = world.random.nextBool() ? 'bin' : 'png';
    final path = VaultPath('media/asset_$id.$ext');

    final stat = await dev.fs.stat(path);
    if (stat != null) {
      final existingBytes = await dev.fs.readBytes(path);
      final hex = contentHash(existingBytes).substring(0, 8);
      final trashPath = VaultPath.raw('.trash/${path.value}.$hex');
      await dev.fs.writeBytes(trashPath, existingBytes);
    }

    // 5% chance > 4 MiB (e.g. 4.2 MiB), else 1 KiB to 64 KiB
    final isLarge = world.random.nextInt(20) == 0;
    final size = isLarge
        ? 4 * 1024 * 1024 + world.random.nextInt(200 * 1024)
        : 1024 + world.random.nextInt(64 * 1024);

    final bytes = Uint8List(size);
    for (var i = 0; i < size; i += 1024) {
      bytes[i] = world.random.nextInt(256);
    }

    await dev.fs.writeBytes(path, bytes);
    world.logOp('createBinary on ${dev.name}: ${path.value} ($size bytes)');
  }

  static Future<void> _overwriteBinary(SimWorld world) async {
    final dev = world.randomDevice();
    final binaries = await world.listParticipatingBinaries(dev);
    if (binaries.isEmpty) {
      await _createBinary(world);
      return;
    }

    final path = binaries[world.random.nextInt(binaries.length)];
    final existingBytes = await dev.fs.readBytes(path);
    final hex = contentHash(existingBytes).substring(0, 8);
    final trashPath = VaultPath.raw('.trash/${path.value}.$hex');
    await dev.fs.writeBytes(trashPath, existingBytes);

    final size = 2048 + world.random.nextInt(32 * 1024);
    final bytes = Uint8List(size);
    for (var i = 0; i < size; i += 512) {
      bytes[i] = world.random.nextInt(256);
    }

    await dev.fs.writeBytes(path, bytes);
    world.logOp('overwriteBinary on ${dev.name}: ${path.value} ($size bytes)');
  }

  static Future<void> _deleteFile(SimWorld world) async {
    final dev = world.randomDevice();
    final files = await world.listParticipatingFiles(dev);
    if (files.isEmpty) return;

    final path = files[world.random.nextInt(files.length)];
    await dev.fs.delete(path, mode: TrashMode.vaultTrash);
    world.logOp('deleteFile on ${dev.name}: ${path.value}');
  }

  static Future<void> _renameFile(SimWorld world) async {
    final dev = world.randomDevice();
    final files = await world.listParticipatingFiles(dev);
    if (files.isEmpty) return;

    final path = files[world.random.nextInt(files.length)];
    final ext = path.extension.isEmpty ? '' : '.${path.extension}';
    final newName = 'renamed_${world.opCount}_${world.random.nextInt(100)}$ext';
    final newPath = path.withName(newName);

    if (await dev.fs.stat(newPath) != null) return;

    await dev.fs.move(path, newPath);
    world.logOp('renameFile on ${dev.name}: ${path.value} -> ${newPath.value}');
  }

  static Future<void> _moveFile(SimWorld world) async {
    final dev = world.randomDevice();
    final files = await world.listParticipatingFiles(dev);
    if (files.isEmpty) return;

    final path = files[world.random.nextInt(files.length)];
    final folders = ['', 'archive', 'notes/misc'];
    final folder = folders[world.random.nextInt(folders.length)];
    final fileName = path.name;
    final newPath = folder.isEmpty
        ? VaultPath.raw(fileName)
        : VaultPath.raw('$folder/$fileName');

    if (path == newPath || await dev.fs.stat(newPath) != null) return;

    await dev.fs.move(path, newPath);
    world.logOp('moveFile on ${dev.name}: ${path.value} -> ${newPath.value}');
  }

  static Future<void> _caseOnlyRename(SimWorld world) async {
    final dev = world.randomDevice();
    final files = await world.listParticipatingFiles(dev);
    if (files.isEmpty) return;

    final path = files[world.random.nextInt(files.length)];
    final name = path.name;
    // Invert first letter
    final firstChar = name[0];
    final swapped = firstChar == firstChar.toUpperCase()
        ? firstChar.toLowerCase()
        : firstChar.toUpperCase();
    final newName = '$swapped${name.substring(1)}';
    final p = path.parent;
    final newPath = p == null || p.isRoot
        ? VaultPath.raw(newName)
        : VaultPath.raw('${p.value}/$newName');
    if (newPath == path) return;
    if (!dev.isWindows && await dev.fs.stat(newPath) != null) return;

    await dev.fs.move(path, newPath);
    world.logOp(
      'caseOnlyRename on ${dev.name}: ${path.value} -> ${newPath.value}',
    );
  }

  static Future<void> _renameFolder(SimWorld world) async {
    final dev = world.randomDevice();
    final files = await world.listParticipatingFiles(dev);
    final folders = <VaultPath>{};
    for (final f in files) {
      final p = f.parent;
      if (p != null && !p.isRoot) {
        folders.add(p);
      }
    }
    if (folders.isEmpty) return;

    final folderList = folders.toList();
    final folder = folderList[world.random.nextInt(folderList.length)];
    final stem = folder.name.split('_renamed_').first;
    final parentPrefix = folder.parent != null && !folder.parent!.isRoot
        ? '${folder.parent!.value}/'
        : '';
    final targetFolder = VaultPath.raw(
      '$parentPrefix${stem}_renamed_${world.opCount}',
    );

    for (final f in files) {
      if (f.isWithin(folder)) {
        final rel = f.value.substring(folder.value.length + 1);
        final newPath = VaultPath.raw('${targetFolder.value}/$rel');
        await dev.fs.move(f, newPath);
      }
    }
    world.logOp(
      'renameFolder on ${dev.name}: ${folder.value} -> ${targetFolder.value}',
    );
  }

  static Future<void> _editFrontmatter(SimWorld world) async {
    final dev = world.randomDevice();
    final notes = await world.listParticipatingNotes(dev);
    if (notes.isEmpty) return;

    final path = notes[world.random.nextInt(notes.length)];
    final existingBytes = await dev.fs.readBytes(path);
    await dev.localHistory.snapshot(
      path,
      existingBytes,
      reason: SnapshotReason.editing,
    );
    final content = utf8.decode(existingBytes);

    String newContent;
    if (content.startsWith('---\n')) {
      final end = content.indexOf('\n---\n', 4);
      if (end != -1) {
        final body = content.substring(end + 5);
        newContent =
            '---\ntags: [fuzz_${world.opCount}, tag_${world.random.nextInt(5)}]\nstatus: updated\n---\n$body';
      } else {
        newContent = '---\ntags: [fuzz_${world.opCount}]\n---\n$content';
      }
    } else {
      newContent =
          '---\ntags: [fuzz_${world.opCount}]\nstatus: initial\n---\n$content';
    }

    await dev.fs.writeBytes(path, utf8.encode(newContent));
    world.logOp('editFrontmatter on ${dev.name}: ${path.value}');
  }

  static Future<void> _syncDevice(SimWorld world) async {
    final dev = world.randomOnlineDevice();
    if (dev == null) {
      world.devices.first.offlineSwitch.isOnline = true;
      return;
    }
    await world.syncDevice(dev);
  }

  static void _goOffline(SimWorld world) {
    final dev = world.randomDevice();
    dev.offlineSwitch.isOnline = false;
    world.logOp('goOffline: ${dev.name}');
  }

  static void _goOnline(SimWorld world) {
    final dev = world.randomDevice();
    dev.offlineSwitch.isOnline = true;
    world.logOp('goOnline: ${dev.name}');
  }

  static Future<void> _syncWithCrash(SimWorld world) async {
    final dev = world.randomOnlineDevice() ?? world.devices.first;
    dev.offlineSwitch.isOnline = true;

    final points = CrashPoint.values;
    final point = points[world.random.nextInt(points.length)];

    await world.syncDevice(dev, crashPoint: point);
  }

  static Future<void> _sameLineScenario(SimWorld world) async {
    final devA = world.devices[0];
    final devB = world.devices[1];

    final path = VaultPath('same_line_note_${world.opCount}.md');
    final initialContent =
        '# Same Line Title\nLine 1: baseline\nLine 2: stable\n';
    await devA.fs.writeBytes(path, utf8.encode(initialContent));

    // Ensure A and B are online and sync initial file
    devA.offlineSwitch.isOnline = true;
    devB.offlineSwitch.isOnline = true;
    await world.syncDevice(devA);
    await world.syncDevice(devB);

    // B goes offline
    devB.offlineSwitch.isOnline = false;

    // A edits line 1 and syncs
    final contentA = '# Same Line Title\nLine 1: edited by A\nLine 2: stable\n';
    await devA.fs.writeBytes(path, utf8.encode(contentA));
    await world.syncDevice(devA);

    // B edits line 1 concurrently
    final contentB = '# Same Line Title\nLine 1: edited by B\nLine 2: stable\n';
    await devB.fs.writeBytes(path, utf8.encode(contentB));

    world.logOp('sameLineScenario prepared on ${path.value}');
  }
}
