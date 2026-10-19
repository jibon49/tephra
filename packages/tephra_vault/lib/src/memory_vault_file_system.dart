// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:tephra_core/tephra_core.dart';

import 'text_document.dart';
import 'trash_mode.dart';
import 'vault_change.dart';
import 'vault_entry.dart';
import 'vault_file_system.dart';
import 'vault_ignore.dart';

sealed class _MemoryNode {
  DateTime get modified;
  DateTime? get created;
}

final class _MemoryFileNode extends _MemoryNode {
  _MemoryFileNode(this.bytes, this.modified, [this.created]);
  Uint8List bytes;
  @override
  DateTime modified;
  @override
  DateTime? created;
}

final class _MemoryFolderNode extends _MemoryNode {
  _MemoryFolderNode(this.modified, [this.created]);
  @override
  DateTime modified;
  @override
  DateTime? created;
}

final class MemoryVaultFileSystem implements VaultFileSystem {
  MemoryVaultFileSystem({
    this.clock = const SystemClock(),
    this.ignore = const VaultIgnore(),
    this.caseInsensitive = false,
  });

  final Clock clock;
  final VaultIgnore ignore;
  final bool caseInsensitive;

  final Map<VaultPath, _MemoryNode> _nodes = {};
  final _watchController = StreamController<VaultChange>.broadcast(sync: true);

  int writeCount = 0;
  final List<String> writeLog = [];

  @override
  String get rootDisplayPath => 'memory://';

  VaultPath? _resolveKey(VaultPath path) {
    if (_nodes.containsKey(path)) return path;
    if (!caseInsensitive) return null;
    final target = path.caseKey;
    for (final key in _nodes.keys) {
      if (key.caseKey == target) return key;
    }
    return null;
  }

  void putText(String path, String text) {
    putBytes(path, utf8.encode(text));
  }

  void putBytes(String path, List<int> bytes) {
    final vp = VaultPath(path);
    _ensureParents(vp);
    final now = clock.now();
    final existing = _resolveKey(vp);
    final key = existing ?? vp;
    _nodes[key] = _MemoryFileNode(
      bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
      now,
      now,
    );
  }

  String? textOf(String path) {
    final vp = VaultPath(path);
    final resolved = _resolveKey(vp);
    if (resolved == null) return null;
    final node = _nodes[resolved];
    if (node is _MemoryFileNode) {
      return utf8.decode(node.bytes);
    }
    return null;
  }

  void emit(VaultChange c) {
    if (!ignore.isIgnored(c.path)) {
      _watchController.add(c);
    }
  }

  void _ensureParents(VaultPath path) {
    var p = path.parent;
    while (p != null && !p.isRoot) {
      final resolved = _resolveKey(p);
      if (resolved == null) {
        _nodes[p] = _MemoryFolderNode(clock.now(), clock.now());
      } else {
        if (_nodes[resolved] is _MemoryFileNode) {
          throw FileConflictException(p);
        }
      }
      p = p.parent;
    }
  }

  @override
  Future<List<VaultEntry>> list({
    VaultPath folder = VaultPath.root,
    bool recursive = true,
  }) async {
    final resolvedFolder = folder.isRoot ? VaultPath.root : _resolveKey(folder);
    if (!folder.isRoot && resolvedFolder == null) {
      return [];
    }

    final folderIgnored = !folder.isRoot && ignore.isIgnored(folder);
    final results = <VaultEntry>[];

    for (final entry in _nodes.entries) {
      final path = entry.key;
      final node = entry.value;

      if (path.isRoot) continue;
      if (!folderIgnored && ignore.isIgnored(path)) continue;

      final bool matches;
      if (folder.isRoot) {
        matches = recursive ? true : path.parent == VaultPath.root;
      } else {
        final f = resolvedFolder!;
        if (recursive) {
          matches = path.isWithin(f);
        } else {
          matches = path.parent == f;
        }
      }

      if (matches) {
        results.add(
          VaultEntry(
            path: path,
            isFolder: node is _MemoryFolderNode,
            size: node is _MemoryFileNode ? node.bytes.length : 0,
            modified: node.modified,
            created: node.created,
          ),
        );
      }
    }

    results.sort((a, b) => a.path.value.compareTo(b.path.value));
    return results;
  }

  @override
  Future<VaultEntry?> stat(VaultPath path) async {
    if (path.isRoot) {
      return VaultEntry(
        path: VaultPath.root,
        isFolder: true,
        size: 0,
        modified: clock.now(),
      );
    }
    final resolved = _resolveKey(path);
    if (resolved == null) return null;
    final node = _nodes[resolved]!;
    return VaultEntry(
      path: resolved,
      isFolder: node is _MemoryFolderNode,
      size: node is _MemoryFileNode ? node.bytes.length : 0,
      modified: node.modified,
      created: node.created,
    );
  }

  @override
  Future<List<int>> readBytes(VaultPath path) async {
    final resolved = _resolveKey(path);
    if (resolved == null) {
      throw FileNotFoundException(path);
    }
    final node = _nodes[resolved]!;
    if (node is _MemoryFileNode) {
      return node.bytes;
    }
    throw FileNotFoundException(path);
  }

  @override
  Future<TextDocument> readText(VaultPath path) async {
    final bytes = await readBytes(path);
    return TextDocument.decode(bytes);
  }

  @override
  Future<void> writeBytes(VaultPath path, List<int> bytes) async {
    final resolved = _resolveKey(path);
    if (resolved != null && _nodes[resolved] is _MemoryFolderNode) {
      throw FileConflictException(path);
    }

    _ensureParents(path);
    final now = clock.now();
    final key = resolved ?? path;
    final created = _nodes[key]?.created ?? now;
    _nodes[key] = _MemoryFileNode(
      bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
      now,
      created,
    );
    writeCount++;
    writeLog.add(path.value);
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
    final resolved = _resolveKey(path);
    if (resolved != null && _nodes[resolved] is _MemoryFileNode) {
      throw FileConflictException(path);
    }
    _ensureParents(path);
    if (resolved == null) {
      final now = clock.now();
      _nodes[path] = _MemoryFolderNode(now, now);
    }
  }

  @override
  Future<void> move(VaultPath from, VaultPath to) async {
    final fromResolved = _resolveKey(from);
    if (fromResolved == null) {
      throw FileNotFoundException(from);
    }

    final caseOnly =
        from != to && from.caseKey == to.caseKey && caseInsensitive;
    final toResolved = _resolveKey(to);

    if (!caseOnly && toResolved != null) {
      throw FileConflictException(to);
    }

    if (from == to) return;

    final node = _nodes.remove(fromResolved)!;
    _ensureParents(to);
    _nodes[to] = node;

    if (node is _MemoryFolderNode) {
      final oldPrefix = '${fromResolved.value}/';
      final toPrefix = '${to.value}/';
      final children = _nodes.keys
          .where((k) => k.value.startsWith(oldPrefix))
          .toList();
      for (final child in children) {
        final childNode = _nodes.remove(child)!;
        final rel = child.value.substring(oldPrefix.length);
        final newChild = VaultPath('$toPrefix$rel');
        _nodes[newChild] = childNode;
      }
    }
  }

  @override
  Future<void> delete(
    VaultPath path, {
    TrashMode mode = TrashMode.vaultTrash,
  }) async {
    final resolved = _resolveKey(path);
    if (resolved == null) return;

    final node = _nodes[resolved]!;
    final isFolder = node is _MemoryFolderNode;

    switch (mode) {
      case TrashMode.permanent:
        _nodes.remove(resolved);
        if (isFolder) {
          final prefix = '${resolved.value}/';
          _nodes.removeWhere((k, _) => k.value.startsWith(prefix));
        }
        return;

      case TrashMode.system:
      case TrashMode.vaultTrash:
        final trashRel = '.trash/${path.value}';
        var destPath = VaultPath.raw(trashRel);

        if (_resolveKey(destPath) != null) {
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
            destPath = parent.isRoot
                ? VaultPath.raw(newName)
                : VaultPath.raw('${parent.value}/$newName');
            if (_resolveKey(destPath) == null) break;
            index++;
          }
        }

        await move(resolved, destPath);
        return;
    }
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
