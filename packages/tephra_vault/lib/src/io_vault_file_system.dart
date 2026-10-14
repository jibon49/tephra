// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:tephra_core/tephra_core.dart';
import 'package:watcher/watcher.dart';

import 'atomic_file_writer.dart';
import 'change_debouncer.dart';
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
    Duration maxWait = const Duration(milliseconds: 500),
  }) : rootDir = _normalizeRoot(rootDir),
       caseInsensitive = caseInsensitive ?? Platform.isWindows,
       _writer =
           writer ??
           AtomicFileWriter(isWindows: caseInsensitive ?? Platform.isWindows),
       _debouncer = ChangeDebouncer(
         clock: clock,
         quiet: debounce,
         maxWait: maxWait,
       ) {
    _watchController = StreamController<VaultChange>.broadcast(
      onListen: _startWatching,
      onCancel: _stopWatching,
    );
  }

  final String rootDir;
  final VaultIgnore ignore;
  final SystemTrash? systemTrash;
  final WatcherMode watcherMode;
  final Clock clock;
  final bool caseInsensitive;
  final Duration debounce;

  final AtomicFileWriter _writer;
  final _log = Logger('tephra.io_vault_file_system');
  late final StreamController<VaultChange> _watchController;
  final ChangeDebouncer _debouncer;
  StreamSubscription<WatchEvent>? _watcherSub;
  Timer? _reconnectTimer;
  Timer? _debounceTimer;
  int _consecutiveFailures = 0;
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
    if (srcType == FileSystemEntityType.file) {
      try {
        final toFile = _file(to);
        if (toFile.existsSync()) {
          _selfWrites[to] = (contentHash(toFile.readAsBytesSync()), expire);
        }
      } catch (_) {}
    }
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

  Completer<void>? _readyCompleter;

  /// Completes when the underlying OS watcher is ready to detect changes.
  Future<void> get ready => _readyCompleter?.future ?? Future<void>.value();

  void _startWatching() {
    _consecutiveFailures = 0;
    _subscribeToOsWatcher();
  }

  void _stopWatching() {
    _watcherSub?.cancel();
    _watcherSub = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _debouncer.clear();
    if (_readyCompleter != null && !_readyCompleter!.isCompleted) {
      _readyCompleter!.complete();
    }
    _readyCompleter = null;
  }

  DirectoryWatcher _createWatcher() {
    if (watcherMode == WatcherMode.polling) {
      return PollingDirectoryWatcher(
        rootDir,
        pollingDelay: const Duration(seconds: 1),
      );
    }
    return DirectoryWatcher(rootDir);
  }

  void _subscribeToOsWatcher() {
    _watcherSub?.cancel();
    _watcherSub = null;
    final completer = Completer<void>();
    _readyCompleter = completer;
    try {
      final watcher = _createWatcher();
      watcher.ready.then(
        (_) {
          if (!completer.isCompleted) completer.complete();
        },
        onError: (Object _) {
          if (!completer.isCompleted) completer.complete();
        },
      );
      _watcherSub = watcher.events.listen(
        _onWatchEvent,
        onError: (Object error, StackTrace stackTrace) {
          _log.warning('Watcher error on $rootDir: $error', error, stackTrace);
          _watcherSub?.cancel();
          _watcherSub = null;
          _consecutiveFailures++;
          if (_consecutiveFailures < 2) {
            _reconnectTimer?.cancel();
            _reconnectTimer = Timer(const Duration(seconds: 1), () {
              if (_watchController.hasListener) {
                _subscribeToOsWatcher();
              }
            });
          } else {
            _log.severe(
              'Watcher failed consecutively 2 times on $rootDir; keeping stream open without events.',
            );
          }
        },
      );
    } catch (e, st) {
      _log.warning('Failed to initialize watcher on $rootDir: $e', e, st);
      _consecutiveFailures++;
      if (_consecutiveFailures < 2) {
        _reconnectTimer?.cancel();
        _reconnectTimer = Timer(const Duration(seconds: 1), () {
          if (_watchController.hasListener) {
            _subscribeToOsWatcher();
          }
        });
      } else {
        _log.severe('Watcher initialization failed twice on $rootDir');
      }
    }
  }

  void _onWatchEvent(WatchEvent event) {
    _consecutiveFailures = 0;
    final rel = p.relative(event.path, from: rootDir);
    final path = VaultPath.tryParse(rel);
    if (path == null || ignore.isIgnored(path)) {
      return;
    }

    final RawChangeKind kind;
    switch (event.type) {
      case ChangeType.ADD:
        kind = RawChangeKind.added;
      case ChangeType.MODIFY:
        kind = RawChangeKind.modified;
      case ChangeType.REMOVE:
        kind = RawChangeKind.removed;
      default:
        kind = RawChangeKind.modified;
    }
    _debouncer.add(path, kind);
    _scheduleDebounceTimer();
  }

  void _scheduleDebounceTimer() {
    final due = _debouncer.nextDueAt;
    if (due == null) {
      _debounceTimer?.cancel();
      _debounceTimer = null;
      return;
    }
    final now = clock.now();
    final delay = due.isAfter(now) ? due.difference(now) : Duration.zero;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, _onDebounceTimer);
  }

  Future<void> _onDebounceTimer() async {
    final merged = _debouncer.flushIfDue();
    if (merged == null) {
      _scheduleDebounceTimer();
      return;
    }

    final now = clock.now();
    _selfWrites.removeWhere((_, value) => !now.isBefore(value.$2));
    _selfCreated.removeWhere((_, until) => !now.isBefore(until));
    _selfDeleted.removeWhere((_, until) => !now.isBefore(until));

    for (final change in merged) {
      await _processMergedChange(change);
    }

    if (_debouncer.isNotEmpty) {
      _scheduleDebounceTimer();
    }
  }

  Future<void> _processMergedChange(MergedChange change) async {
    final path = change.path;
    final now = clock.now();

    if (change.kind == RawChangeKind.removed) {
      if (_isAncestorOrSelfIn(path, _selfDeleted, now)) {
        return;
      }
      if (!_watchController.isClosed) {
        _watchController.add(FileDeleted(path));
      }
      return;
    }

    final file = _file(path);
    if (!file.existsSync()) {
      if (_isAncestorOrSelfIn(path, _selfDeleted, now)) {
        return;
      }
      if (!_watchController.isClosed) {
        _watchController.add(FileDeleted(path));
      }
      return;
    }

    if (FileSystemEntity.isDirectorySync(file.path)) {
      return;
    }

    final selfWrite = _selfWrites[path];
    var isSelfWriteWithDifferentContent = false;
    if (selfWrite != null && now.isBefore(selfWrite.$2)) {
      try {
        final bytes = file.readAsBytesSync();
        final currentHash = contentHash(bytes);
        if (currentHash == selfWrite.$1) {
          return;
        }
        isSelfWriteWithDifferentContent = true;
        _selfWrites.remove(path);
      } catch (_) {}
    }

    if (change.kind == RawChangeKind.added &&
        !isSelfWriteWithDifferentContent) {
      if (_isAncestorOrSelfIn(path, _selfCreated, now)) {
        return;
      }
      if (!_watchController.isClosed) {
        _watchController.add(FileCreated(path));
      }
    } else {
      if (!_watchController.isClosed) {
        _watchController.add(FileModified(path));
      }
    }
  }

  bool _isAncestorOrSelfIn(
    VaultPath path,
    Map<VaultPath, DateTime> map,
    DateTime now,
  ) {
    final until = map[path];
    if (until != null && now.isBefore(until)) return true;
    var current = path.parent;
    while (current != null) {
      final parentUntil = map[current];
      if (parentUntil != null && now.isBefore(parentUntil)) return true;
      current = current.parent;
    }
    return false;
  }

  @override
  Future<void> dispose() async {
    _stopWatching();
    if (!_watchController.isClosed) {
      await _watchController.close();
    }
  }
}
