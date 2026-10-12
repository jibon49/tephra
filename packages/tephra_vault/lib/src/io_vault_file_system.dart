// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:tephra_core/tephra_core.dart';

import 'atomic_file_writer.dart';
import 'system_trash.dart';
import 'text_document.dart';
import 'trash_mode.dart';
import 'vault_change.dart';
import 'vault_entry.dart';
import 'vault_file_system.dart';
import 'vault_ignore.dart';
import 'watcher_mode.dart';

final class IoVaultFileSystem implements VaultFileSystem {
  IoVaultFileSystem(
    String rootDir, {
    this.ignore = const VaultIgnore(),
    this.systemTrash,
    this.watcherMode = WatcherMode.native,
    this.clock = const SystemClock(),
    bool? caseInsensitive,
    AtomicFileWriter? writer,
    this.debounce = const Duration(milliseconds: 150),
  }) : rootDir = _normalizeRoot(rootDir),
       caseInsensitive = caseInsensitive ?? Platform.isWindows,
       _writer =
           writer ??
           AtomicFileWriter(isWindows: caseInsensitive ?? Platform.isWindows);

  final String rootDir;
  final VaultIgnore ignore;
  final SystemTrash? systemTrash;
  final WatcherMode watcherMode;
  final Clock clock;
  final bool caseInsensitive;
  final Duration debounce;

  final AtomicFileWriter _writer;
  final _log = Logger('tephra.io_vault_file_system');
  final _watchController = StreamController<VaultChange>.broadcast();
  final _random = Random();

  final Map<VaultPath, (String hash, DateTime until)> _selfWrites = {};
  final Map<VaultPath, DateTime> _selfCreated = {};
  final Map<VaultPath, DateTime> _selfDeleted = {};

  static String _normalizeRoot(String raw) {
    final normalized = p.normalize(p.absolute(raw));
    if (normalized.endsWith(p.separator) &&
        normalized != p.rootPrefix(normalized)) {
      return normalized.substring(0, normalized.length - p.separator.length);
    }
    return normalized;
  }

  @override
  String get rootDisplayPath => rootDir;

  File _file(VaultPath path) {
    if (path.isRoot) {
      return File(rootDir);
    }
    final segments = path.value.split('/');
    return File(p.joinAll([rootDir, ...segments]));
  }

  Directory _dir(VaultPath path) {
    if (path.isRoot) {
      return Directory(rootDir);
    }
    final segments = path.value.split('/');
    return Directory(p.joinAll([rootDir, ...segments]));
  }

  Future<T> _guard<T>(VaultPath path, Future<T> Function() body) async {
    try {
      return await body();
    } on PathNotFoundException {
      throw FileNotFoundException(path);
    } on FileSystemException catch (e) {
      final code = e.osError?.errorCode;
      if (code == 5 || code == 13 || code == 1) {
        throw PermissionDeniedException(e.message);
      }
      if (code == 2 || code == 3) {
        throw FileNotFoundException(path);
      }
      rethrow;
    }
  }

  @override
  Future<List<VaultEntry>> list({
    VaultPath folder = VaultPath.root,
    bool recursive = true,
  }) async {
    final targetDir = _dir(folder);
    if (!targetDir.existsSync()) {
      return [];
    }

    final result = <VaultEntry>[];
    try {
      final stream = targetDir.list(recursive: recursive, followLinks: false);
      await for (final entity in stream) {
        if (entity is Link) continue;
        try {
          final rel = p.relative(entity.path, from: rootDir);
          final path = VaultPath.tryParse(rel);
          if (path == null) {
            _log.warning('skipped invalid path: $rel');
            continue;
          }
          if (ignore.isIgnored(path)) {
            continue;
          }
          final stat = entity.statSync();
          final isFolder = entity is Directory;
          final created =
              Platform.isWindows &&
                  stat.changed != DateTime.fromMillisecondsSinceEpoch(0)
              ? stat.changed
              : null;
          result.add(
            VaultEntry(
              path: path,
              isFolder: isFolder,
              size: isFolder ? 0 : stat.size,
              modified: stat.modified,
              created: created,
            ),
          );
        } on FileSystemException {
          // Entity vanished during listing, ignore
        }
      }
    } on FileSystemException {
      return [];
    }

    result.sort((a, b) => a.path.value.compareTo(b.path.value));
    return result;
  }

  @override
  Future<VaultEntry?> stat(VaultPath path) async {
    if (path.isRoot) {
      final dir = Directory(rootDir);
      if (!dir.existsSync()) return null;
      final st = dir.statSync();
      return VaultEntry(
        path: VaultPath.root,
        isFolder: true,
        size: 0,
        modified: st.modified,
        created: Platform.isWindows ? st.changed : null,
      );
    }

    final entityPath = _file(path).path;
    final type = FileSystemEntity.typeSync(entityPath, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      return null;
    }

    final isFolder = type == FileSystemEntityType.directory;
    final fileStat = FileStat.statSync(entityPath);
    return VaultEntry(
      path: path,
      isFolder: isFolder,
      size: isFolder ? 0 : fileStat.size,
      modified: fileStat.modified,
      created: Platform.isWindows ? fileStat.changed : null,
    );
  }

  @override
  Future<List<int>> readBytes(VaultPath path) async {
    return _guard(path, () => _file(path).readAsBytes());
  }

  @override
  Future<TextDocument> readText(VaultPath path) async {
    final bytes = await readBytes(path);
    return TextDocument.decode(bytes);
  }

  void _rememberSelfWrite(VaultPath path, String hash) {
    _selfWrites[path] = (hash, clock.now().add(const Duration(seconds: 2)));
  }

  void _forgetSelfWrite(VaultPath path) {
    _selfWrites.remove(path);
  }

  @override
  Future<void> writeBytes(VaultPath path, List<int> bytes) async {
    final file = _file(path);
    if (FileSystemEntity.isDirectorySync(file.path)) {
      throw FileConflictException(path);
    }

    final hash = contentHash(bytes);
    _rememberSelfWrite(path, hash);
    try {
      await _writer.write(file, bytes);
    } catch (_) {
      _forgetSelfWrite(path);
      rethrow;
    }
  }

  @override
  Future<void> writeText(VaultPath path, TextDocument doc) async {
    if (doc.malformed) {
      throw const PermissionDeniedException(
        'Refusing to overwrite a file that is not valid UTF-8',
      );
    }
    await writeBytes(path, doc.encode());
  }

  @override
  Future<void> createFolder(VaultPath path) async {
    final file = _file(path);
    if (FileSystemEntity.isFileSync(file.path)) {
      throw FileConflictException(path);
    }
    final dir = _dir(path);
    await dir.create(recursive: true);
    _selfCreated[path] = clock.now().add(const Duration(seconds: 2));
  }

  @override
  Future<void> move(VaultPath from, VaultPath to) async {
    final fromPath = _file(from).path;
    final srcType = FileSystemEntity.typeSync(fromPath, followLinks: false);
    if (srcType == FileSystemEntityType.notFound) {
      throw FileNotFoundException(from);
    }

    final caseOnly =
        from != to && from.caseKey == to.caseKey && caseInsensitive;
    final toPath = _file(to).path;

    if (!caseOnly) {
      final destType = FileSystemEntity.typeSync(toPath, followLinks: false);
      if (destType != FileSystemEntityType.notFound) {
        throw FileConflictException(to);
      }
    }

    if (from == to) {
      return;
    }

    if (to.parent != null && !to.parent!.isRoot) {
      await _dir(to.parent!).create(recursive: true);
    }

    if (caseOnly) {
      final hex = _random.nextInt(0xFFFFFFFF).toRadixString(16).padLeft(8, '0');
      final tmpName = '.${from.name}.tephra-case-$hex';
      final tmpPath = p.join(_file(from).parent.path, tmpName);

      if (srcType == FileSystemEntityType.directory) {
        await Directory(fromPath).rename(tmpPath);
        try {
          await Directory(tmpPath).rename(toPath);
        } catch (_) {
          try {
            await Directory(tmpPath).rename(fromPath);
          } catch (_) {}
          rethrow;
        }
      } else {
        await File(fromPath).rename(tmpPath);
        try {
          await File(tmpPath).rename(toPath);
        } catch (_) {
          try {
            await File(tmpPath).rename(fromPath);
          } catch (_) {}
          rethrow;
        }
      }
    } else {
      if (srcType == FileSystemEntityType.directory) {
        await Directory(fromPath).rename(toPath);
      } else {
        await File(fromPath).rename(toPath);
      }
    }

    final expire = clock.now().add(const Duration(seconds: 2));
    _selfDeleted[from] = expire;
    _selfCreated[to] = expire;
  }

  @override
  Future<void> delete(
    VaultPath path, {
    TrashMode mode = TrashMode.vaultTrash,
  }) async {
    final targetPath = _file(path).path;
    final type = FileSystemEntity.typeSync(targetPath, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      return;
    }

    final isFolder = type == FileSystemEntityType.directory;
    _selfDeleted[path] = clock.now().add(const Duration(seconds: 2));

    switch (mode) {
      case TrashMode.permanent:
        if (isFolder) {
          await Directory(targetPath).delete(recursive: true);
        } else {
          await File(targetPath).delete();
        }
        return;

      case TrashMode.system:
        if (systemTrash != null) {
          final ok = await systemTrash!.moveToTrash(
            targetPath,
            isFolder: isFolder,
          );
          if (ok) return;
        }
        _log.warning('system trash unavailable, using vault trash');
        continue vaultTrashLabel;

      vaultTrashLabel:
      case TrashMode.vaultTrash:
        final trashRel = '.trash/${path.value}';
        var destPath = VaultPath(trashRel);
        var destFile = _file(destPath);

        if (FileSystemEntity.typeSync(destFile.path, followLinks: false) !=
            FileSystemEntityType.notFound) {
          var index = 1;
          while (true) {
            final String newName;
            if (isFolder) {
              newName = '${path.name} $index';
            } else {
              final stem = path.stem;
              final ext = path.extension;
              newName = ext.isEmpty ? '$stem $index' : '$stem $index.$ext';
            }
            final parent = destPath.parent!;
            destPath = parent.join(newName);
            destFile = _file(destPath);
            if (FileSystemEntity.typeSync(destFile.path, followLinks: false) ==
                FileSystemEntityType.notFound) {
              break;
            }
            index++;
          }
        }

        await destFile.parent.create(recursive: true);
        if (isFolder) {
          await Directory(targetPath).rename(destFile.path);
        } else {
          await File(targetPath).rename(destFile.path);
        }
        return;
    }
  }

  /// Removes temporary files older than [olderThan] left by crashed operations.
  Future<int> cleanStaleTemps({
    Duration olderThan = const Duration(hours: 24),
  }) async {
    final dir = Directory(rootDir);
    if (!dir.existsSync()) return 0;

    final regex = RegExp(r'^\..*\.tephra-(tmp|bak|case)-[0-9a-f]{8}$');
    final cutoff = clock.now().subtract(olderThan);
    var count = 0;

    Future<void> walk(Directory d) async {
      try {
        await for (final entity in d.list(followLinks: false)) {
          final name = p.basename(entity.path);
          if (name == '.git' || name == 'node_modules') continue;
          if (entity is Directory) {
            await walk(entity);
          } else if (entity is File) {
            if (regex.hasMatch(name)) {
              final stat = entity.statSync();
              if (stat.modified.isBefore(cutoff)) {
                try {
                  await entity.delete();
                  count++;
                } catch (_) {}
              }
            }
          }
        }
      } catch (_) {}
    }

    await walk(dir);
    return count;
  }

  @override
  Stream<VaultChange> watch() => _watchController.stream;

  @override
  Future<void> dispose() async {
    if (!_watchController.isClosed) {
      await _watchController.close();
    }
  }
}
