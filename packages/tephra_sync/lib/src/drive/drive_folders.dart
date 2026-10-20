// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:googleapis/drive/v3.dart' as drive;

import '../store/sync_state_store.dart';
import 'drive_retry.dart';

/// Resolves, creates, and caches Google Drive folder IDs and file IDs.
class DriveFolders {
  DriveFolders({
    required drive.DriveApi driveApi,
    required this._vaultFolderId,
    this._store,
    DriveRetry? retry,
  }) : _drive = driveApi,
       _retry = retry ?? const DriveRetry();

  final drive.DriveApi _drive;
  final String _vaultFolderId;
  final SyncStateStore? _store;
  final DriveRetry _retry;

  final Map<String, String> _folderCache = {};
  final Map<String, String> _memoryFileCache = {};

  /// Normalizes vault names for Google Drive folder names by replacing illegal chars with `_`.
  static String sanitizeVaultFolderName(String name) =>
      name.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');

  /// Escapes string literals for Drive API `q` search queries.
  static String escapeQueryValue(String value) =>
      value.replaceAll(r'\', r'\\').replaceAll("'", r"\'");

  /// Clears in-memory caches.
  void clearMemoryCache() {
    _folderCache.clear();
    _memoryFileCache.clear();
  }

  /// Removes cached file ID for [key] from memory and database store.
  Future<void> invalidateFileId(String key) async {
    _memoryFileCache.remove(key);
    await _store?.removeFileId(key);
  }

  /// Caches [fileId] for [key] in memory and persistent database store.
  Future<void> cacheFileId(String key, String fileId) async {
    _memoryFileCache[key] = fileId;
    await _store?.putFileId(key, fileId);
  }

  /// Resolves or creates a folder path relative to the vault root (e.g. `journals/dev1`).
  Future<String> ensureFolder(String relativePath) async {
    final normalized = _normalizePath(relativePath);
    if (normalized.isEmpty) return _vaultFolderId;

    if (_folderCache.containsKey(normalized)) {
      return _folderCache[normalized]!;
    }

    final segments = normalized.split('/');
    var currentParentId = _vaultFolderId;
    var accumulatedPath = '';

    for (final segment in segments) {
      accumulatedPath = accumulatedPath.isEmpty
          ? segment
          : '$accumulatedPath/$segment';

      if (_folderCache.containsKey(accumulatedPath)) {
        currentParentId = _folderCache[accumulatedPath]!;
        continue;
      }

      currentParentId = await _findOrCreateFolderSegment(
        currentParentId,
        segment,
      );
      _folderCache[accumulatedPath] = currentParentId;
    }

    return currentParentId;
  }

  Future<String> _findOrCreateFolderSegment(
    String parentId,
    String segmentName,
  ) async {
    final escaped = escapeQueryValue(segmentName);
    final q =
        "'$parentId' in parents and name = '$escaped' and mimeType = 'application/vnd.google-apps.folder' and trashed = false";

    final list = await _retry.run(
      () => _drive.files.list(
        q: q,
        spaces: 'drive',
        $fields: 'files(id,name,createdTime)',
      ),
    );

    final files = list.files;
    if (files != null && files.isNotEmpty) {
      // Pick the oldest createdTime if duplicates exist
      files.sort((a, b) {
        final aTime = a.createdTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aTime.compareTo(bTime);
      });
      return files.first.id!;
    }

    // Create folder
    final newFolder = drive.File(
      name: segmentName,
      mimeType: 'application/vnd.google-apps.folder',
      parents: [parentId],
    );

    final created = await _retry.run(
      () => _drive.files.create(newFolder, $fields: 'id'),
    );
    return created.id!;
  }

  /// Finds existing file ID for [key], or null if absent.
  ///
  /// Checks memory cache first, then persistent store, then queries Drive.
  Future<String?> findFileId(String key) async {
    // 1. Memory cache
    if (_memoryFileCache.containsKey(key)) {
      return _memoryFileCache[key];
    }

    // 2. Persistent store cache
    if (_store != null) {
      final cached = await _store.fileId(key);
      if (cached != null && cached.isNotEmpty) {
        _memoryFileCache[key] = cached;
        return cached;
      }
    }

    // 3. Query Drive folder
    final parentPath = _parentPathOf(key);
    final fileName = _fileNameOf(key);
    final parentFolderId = await ensureFolder(parentPath);

    final escaped = escapeQueryValue(fileName);
    final q =
        "'$parentFolderId' in parents and name = '$escaped' and trashed = false";

    final list = await _retry.run(
      () => _drive.files.list(
        q: q,
        spaces: 'drive',
        $fields: 'files(id,name,size,createdTime,modifiedTime)',
      ),
    );

    final files = list.files;
    if (files == null || files.isEmpty) {
      return null;
    }

    drive.File chosenFile;
    if (files.length == 1) {
      chosenFile = files.first;
    } else {
      if (key.startsWith('blobs/')) {
        // Blobs are content-addressed and immutable; pick any
        chosenFile = files.first;
      } else {
        // Pick newest modifiedTime
        files.sort((a, b) {
          final aTime =
              a.modifiedTime ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime =
              b.modifiedTime ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });
        chosenFile = files.first;
      }
    }

    final id = chosenFile.id!;
    await cacheFileId(key, id);
    return id;
  }

  static String _normalizePath(String path) {
    var p = path.replaceAll('\\', '/').trim();
    while (p.startsWith('/')) {
      p = p.substring(1);
    }
    while (p.endsWith('/')) {
      p = p.substring(0, p.length - 1);
    }
    return p;
  }

  static String _parentPathOf(String key) {
    final idx = key.lastIndexOf('/');
    if (idx == -1) return '';
    return key.substring(0, idx);
  }

  static String _fileNameOf(String key) {
    final idx = key.lastIndexOf('/');
    if (idx == -1) return key;
    return key.substring(idx + 1);
  }
}
