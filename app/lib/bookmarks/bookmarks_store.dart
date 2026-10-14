// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../core/json_file_store.dart';
import 'bookmark.dart';

/// Store managing `.tephra/bookmarks.json` in the active vault.
class BookmarksStore {
  BookmarksStore(this.fs, {TephraJsonStore? jsonStore})
    : _jsonStore = jsonStore ?? const TephraJsonStore();

  final VaultFileSystem fs;
  final TephraJsonStore _jsonStore;
  static final _bookmarksPath = VaultPath('.tephra/bookmarks.json');
  static final _logger = Logger('bookmarks_store');

  BookmarksDocument _doc = const BookmarksDocument(items: []);

  BookmarksDocument get document => _doc;
  List<Bookmark> get items => _doc.items;

  /// Loads `.tephra/bookmarks.json`. Missing or corrupt file results in empty items.
  Future<void> load() async {
    try {
      final map = await _jsonStore.readMap(fs, _bookmarksPath);
      if (map.isEmpty) {
        _doc = const BookmarksDocument(items: []);
      } else {
        _doc = BookmarksDocument.fromJson(map);
      }
    } catch (e, st) {
      _logger.warning('Failed to load bookmarks, resetting to empty', e, st);
      _doc = const BookmarksDocument(items: []);
    }
  }

  /// Writes current document atomically to `.tephra/bookmarks.json`.
  Future<void> _save() async {
    await _jsonStore.writeMap(fs, _bookmarksPath, _doc.toJson());
  }

  /// Adds [bookmark] either at root level or inside group [into].
  Future<void> add(Bookmark bookmark, {GroupBookmark? into}) async {
    if (into == null) {
      _doc = _doc.copyWith(items: [..._doc.items, bookmark]);
    } else {
      _doc = _doc.copyWith(items: _addToGroup(_doc.items, into, bookmark));
    }
    await _save();
  }

  List<Bookmark> _addToGroup(
    List<Bookmark> list,
    GroupBookmark targetGroup,
    Bookmark toAdd,
  ) {
    return list.map((item) {
      if (identical(item, targetGroup) || item == targetGroup) {
        final group = item as GroupBookmark;
        return group.copyWith(items: [...group.items, toAdd]);
      } else if (item is GroupBookmark) {
        return item.copyWith(
          items: _addToGroup(item.items, targetGroup, toAdd),
        );
      }
      return item;
    }).toList();
  }

  /// Removes [bookmark] wherever it is located in the bookmark hierarchy.
  Future<void> remove(Bookmark bookmark) async {
    _doc = _doc.copyWith(items: _removeFromList(_doc.items, bookmark));
    await _save();
  }

  List<Bookmark> _removeFromList(List<Bookmark> list, Bookmark toRemove) {
    final result = <Bookmark>[];
    for (final item in list) {
      if (identical(item, toRemove) || item == toRemove) {
        continue;
      }
      if (item is GroupBookmark) {
        result.add(item.copyWith(items: _removeFromList(item.items, toRemove)));
      } else {
        result.add(item);
      }
    }
    return result;
  }

  /// Renames [bookmark] to [newTitle].
  Future<void> rename(Bookmark bookmark, String? newTitle) async {
    _doc = _doc.copyWith(items: _renameInList(_doc.items, bookmark, newTitle));
    await _save();
  }

  List<Bookmark> _renameInList(
    List<Bookmark> list,
    Bookmark target,
    String? newTitle,
  ) {
    return list.map((item) {
      if (identical(item, target) || item == target) {
        return switch (item) {
          final FileBookmark b => b.copyWith(title: newTitle),
          final FolderBookmark b => b.copyWith(title: newTitle),
          final SearchBookmark b => b.copyWith(title: newTitle),
          final GroupBookmark b => b.copyWith(title: newTitle),
          final UnknownBookmark b => b.copyWith(
            raw: {
              ...b.raw,
              if (newTitle != null) 'title': newTitle else ...{'title': null},
            }..removeWhere((k, v) => k == 'title' && v == null),
          ),
        };
      } else if (item is GroupBookmark) {
        return item.copyWith(
          items: _renameInList(item.items, target, newTitle),
        );
      }
      return item;
    }).toList();
  }

  /// Moves [bookmark] to [newParent] at index [targetIndex].
  Future<void> move(
    Bookmark bookmark,
    GroupBookmark? newParent,
    int targetIndex,
  ) async {
    // 1. Remove from current position
    var updated = _removeFromList(_doc.items, bookmark);

    // 2. Insert at newParent / root
    if (newParent == null) {
      final safeIndex = targetIndex.clamp(0, updated.length);
      final newItems = List<Bookmark>.of(updated)..insert(safeIndex, bookmark);
      _doc = _doc.copyWith(items: newItems);
    } else {
      updated = _insertIntoGroup(updated, newParent, bookmark, targetIndex);
      _doc = _doc.copyWith(items: updated);
    }
    await _save();
  }

  List<Bookmark> _insertIntoGroup(
    List<Bookmark> list,
    GroupBookmark targetGroup,
    Bookmark toInsert,
    int index,
  ) {
    return list.map((item) {
      if (identical(item, targetGroup) || item == targetGroup) {
        final group = item as GroupBookmark;
        final safeIndex = index.clamp(0, group.items.length);
        final newItems = List<Bookmark>.of(group.items)
          ..insert(safeIndex, toInsert);
        return group.copyWith(items: newItems);
      } else if (item is GroupBookmark) {
        return item.copyWith(
          items: _insertIntoGroup(item.items, targetGroup, toInsert, index),
        );
      }
      return item;
    }).toList();
  }

  /// Checks if [path] (with optional [subpath]) is currently bookmarked.
  bool isBookmarked(VaultPath path, [String? subpath]) {
    return _findInList(_doc.items, path, subpath);
  }

  bool _findInList(List<Bookmark> list, VaultPath path, String? subpath) {
    for (final item in list) {
      if (item is FileBookmark) {
        if (item.path == path && item.subpath == subpath) {
          return true;
        }
      } else if (item is FolderBookmark) {
        if (item.path == path && subpath == null) {
          return true;
        }
      } else if (item is GroupBookmark) {
        if (_findInList(item.items, path, subpath)) {
          return true;
        }
      }
    }
    return false;
  }

  /// Retargets bookmarks after file or folder renames.
  Future<void> retarget(
    Map<VaultPath, VaultPath> moves, {
    (VaultPath from, VaultPath to)? folderMove,
  }) async {
    VaultPath retargetPath(VaultPath current) {
      if (moves.containsKey(current)) {
        return moves[current]!;
      }
      if (folderMove != null) {
        final (from, to) = folderMove;
        if (current == from) {
          return to;
        }
        if (current.value.startsWith('${from.value}/')) {
          final rel = current.value.substring(from.value.length + 1);
          return VaultPath('${to.value}/$rel');
        }
      }
      return current;
    }

    List<Bookmark> retargetList(List<Bookmark> list) {
      return list.map((item) {
        if (item is FileBookmark) {
          final newPath = retargetPath(item.path);
          if (newPath != item.path) {
            return item.copyWith(path: newPath);
          }
        } else if (item is FolderBookmark) {
          final newPath = retargetPath(item.path);
          if (newPath != item.path) {
            return item.copyWith(path: newPath);
          }
        } else if (item is GroupBookmark) {
          return item.copyWith(items: retargetList(item.items));
        }
        return item;
      }).toList();
    }

    final newItems = retargetList(_doc.items);
    _doc = _doc.copyWith(items: newItems);
    await _save();
  }

  /// Returns the raw JSON text of `.tephra/bookmarks.json` if it exists.
  Future<String?> rawJson() async {
    try {
      final doc = await fs.readText(_bookmarksPath);
      return doc.text;
    } catch (_) {
      return null;
    }
  }

  /// Restores bookmarks state from [jsonText] and saves to filesystem.
  Future<void> restoreJson(String jsonText) async {
    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is Map) {
        _doc = BookmarksDocument.fromJson(decoded.cast<String, Object?>());
        await _save();
      }
    } catch (e, st) {
      _logger.warning('Failed to restore bookmarks JSON', e, st);
    }
  }
}
