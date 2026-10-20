// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:typed_data';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:tephra_core/tephra_core.dart';

import '../auth/access_token_source.dart';
import '../auth/authed_client.dart';
import '../errors/sync_exceptions.dart';
import '../provider/quota.dart';
import '../provider/remote_changes.dart';
import '../provider/remote_object.dart';
import '../provider/sync_provider.dart';
import '../store/sync_state_store.dart';
import 'drive_folders.dart';
import 'drive_retry.dart';
import 'drive_vault_finder.dart';

/// Implementation of [SyncProvider] targeting Google Drive v3 via the `drive.file` scope.
class DriveSyncProvider implements SyncProvider {
  DriveSyncProvider({
    required this.vaultId,
    required this.vaultName,
    required AccessTokenSource tokenSource,
    http.Client? httpClient,
    this.rootUrl,
    this._store,
    DriveRetry? retry,
    this.createIfMissing = false,
  }) : _tokenSource = tokenSource,
       _client = AuthedClient(
         inner: httpClient ?? http.Client(),
         tokenSource: tokenSource,
         closeInner: httpClient == null,
       ),
       _retry = retry ?? const DriveRetry();

  final String vaultId;
  final String vaultName;
  final AccessTokenSource _tokenSource;
  final AuthedClient _client;
  final String? rootUrl;
  final SyncStateStore? _store;
  final DriveRetry _retry;
  final bool createIfMissing;

  late final drive.DriveApi _drive = rootUrl != null
      ? drive.DriveApi(_client, rootUrl: rootUrl!)
      : drive.DriveApi(_client);

  late final DriveVaultFinder _vaultFinder = DriveVaultFinder(
    driveApi: _drive,
    retry: _retry,
  );

  DriveFolders? _folders;
  String? _vaultFolderId;
  DateTime? _lastQuotaCheckTime;
  Quota? _cachedQuota;

  @override
  String get id => 'drive';

  /// Legacy alias for [id].
  String get providerId => id;

  /// Returns the current Drive folder ID for this vault.
  String? get vaultFolderId => _vaultFolderId;

  @override
  Future<void> connect() async {
    // 1. Verify access token
    await _tokenSource.accessToken();

    // 2. Locate or create vault folder
    final escapedVaultId = DriveFolders.escapeQueryValue(vaultId);
    final q =
        "appProperties has { key='tephraVaultId' and value='$escapedVaultId' } and mimeType = 'application/vnd.google-apps.folder' and trashed = false";

    final list = await _retry.run(
      () => _drive.files.list(
        q: q,
        spaces: 'drive',
        $fields: 'files(id,name,createdTime)',
      ),
    );

    final files = list.files;
    if (files != null && files.isNotEmpty) {
      files.sort((a, b) {
        final aTime = a.createdTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aTime.compareTo(bTime);
      });
      _vaultFolderId = files.first.id!;
    } else {
      if (createIfMissing) {
        _vaultFolderId = await _vaultFinder.createVaultFolders(
          vaultName,
          vaultId,
        );
      } else {
        throw RemoteVaultMissingException(
          'Remote vault folder not found for vault ID $vaultId',
        );
      }
    }

    _folders = DriveFolders(
      driveApi: _drive,
      vaultFolderId: _vaultFolderId!,
      store: _store,
      retry: _retry,
    );
  }

  DriveFolders get _effectiveFolders {
    final f = _folders;
    if (f == null) {
      throw SyncException(
        'DriveSyncProvider is not connected. Call connect() first.',
      );
    }
    return f;
  }

  @override
  Future<void> put(String key, List<int> bytes) async {
    validateRemoteKey(key);
    final folders = _effectiveFolders;

    // 1. Storage quota pre-flight check
    await _checkQuotaBeforeUpload(bytes.length);

    // 2. Blob keys are immutable: if already present, skip upload
    if (key.startsWith('blobs/')) {
      final existingBlobId = await folders.findFileId(key);
      if (existingBlobId != null) {
        return;
      }
    }

    final parentPath = _parentPathOf(key);
    final fileName = _fileNameOf(key);
    final parentFolderId = await folders.ensureFolder(parentPath);
    final existingId = await folders.findFileId(key);

    final mimeType = key == 'vault.json'
        ? 'application/json'
        : 'application/octet-stream';
    final appProps = key.length <= 100
        ? <String, String>{'tephraKey': key}
        : null;

    String fileId;
    if (existingId != null) {
      try {
        final updateMetadata = drive.File();
        if (appProps != null) {
          updateMetadata.appProperties = appProps;
        }

        final updated = await _retry.run(
          () => _drive.files.update(
            updateMetadata,
            existingId,
            uploadMedia: drive.Media(
              Stream<List<int>>.value(bytes),
              bytes.length,
            ),
            $fields: 'id',
          ),
        );
        fileId = updated.id ?? existingId;
      } on Object catch (e) {
        final isNotFound =
            e is RemoteNotFoundException ||
            (e is drive.DetailedApiRequestError && e.status == 404);
        if (isNotFound) {
          // File was deleted remotely since cache; create new
          await folders.invalidateFileId(key);
          fileId = await _createNewFile(
            fileName: fileName,
            parentFolderId: parentFolderId,
            mimeType: mimeType,
            appProps: appProps,
            bytes: bytes,
          );
        } else {
          rethrow;
        }
      }
    } else {
      fileId = await _createNewFile(
        fileName: fileName,
        parentFolderId: parentFolderId,
        mimeType: mimeType,
        appProps: appProps,
        bytes: bytes,
      );
    }

    await folders.cacheFileId(key, fileId);
  }

  Future<String> _createNewFile({
    required String fileName,
    required String parentFolderId,
    required String mimeType,
    required Map<String, String>? appProps,
    required List<int> bytes,
  }) async {
    final metadata = drive.File(
      name: fileName,
      mimeType: mimeType,
      parents: [parentFolderId],
      appProperties: appProps,
    );

    final created = await _retry.run(
      () => _drive.files.create(
        metadata,
        uploadMedia: drive.Media(Stream<List<int>>.value(bytes), bytes.length),
        $fields: 'id',
      ),
    );
    return created.id!;
  }

  @override
  Future<Uint8List> get(String key) async {
    validateRemoteKey(key);
    final folders = _effectiveFolders;

    var fileId = await folders.findFileId(key);
    if (fileId == null) {
      throw RemoteNotFoundException('Object not found: $key');
    }

    try {
      return await _downloadFile(fileId);
    } on Object catch (e) {
      final isNotFound =
          e is RemoteNotFoundException ||
          (e is drive.DetailedApiRequestError && e.status == 404);
      if (isNotFound) {
        // Cache entry might be stale; invalidate and try once more
        await folders.invalidateFileId(key);
        fileId = await folders.findFileId(key);
        if (fileId == null) {
          throw RemoteNotFoundException('Object not found: $key');
        }
        return await _downloadFile(fileId);
      }
      rethrow;
    }
  }

  Future<Uint8List> _downloadFile(String fileId) async {
    final media = await _retry.run(
      () => _drive.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ),
    ) as drive.Media;

    final bytesBuilder = BytesBuilder(copy: false);
    await for (final chunk in media.stream) {
      bytesBuilder.add(chunk);
    }
    return bytesBuilder.takeBytes();
  }

  @override
  Future<void> delete(String key) async {
    validateRemoteKey(key);
    final folders = _effectiveFolders;

    final fileId = await folders.findFileId(key);
    if (fileId == null) {
      return;
    }

    try {
      // Per specification: move to Drive trash, never hard-delete
      final update = drive.File(trashed: true);
      await _retry.run(
        () => _drive.files.update(update, fileId, $fields: 'id,trashed'),
      );
    } on Object catch (e) {
      final isNotFound =
          e is RemoteNotFoundException ||
          (e is drive.DetailedApiRequestError && e.status == 404);
      if (!isNotFound) {
        rethrow;
      }
    } finally {
      await folders.invalidateFileId(key);
    }
  }

  @override
  Future<List<RemoteObject>> list(String prefix) async {
    final folders = _effectiveFolders;
    final results = <String, RemoteObject>{};

    // Determine target start folder
    final targetFolderPath = _parentPathOf(prefix);
    String startFolderId;
    try {
      startFolderId = await folders.ensureFolder(targetFolderPath);
    } catch (_) {
      startFolderId = _vaultFolderId!;
    }

    await _collectKeysRecursively(
      folderId: startFolderId,
      currentPathPrefix: targetFolderPath,
      keyFilterPrefix: prefix,
      results: results,
    );

    final list = results.values.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return list;
  }

  Future<void> _collectKeysRecursively({
    required String folderId,
    required String currentPathPrefix,
    required String keyFilterPrefix,
    required Map<String, RemoteObject> results,
  }) async {
    String? pageToken;
    do {
      final q = "'$folderId' in parents and trashed = false";
      final list = await _retry.run(
        () => _drive.files.list(
          q: q,
          spaces: 'drive',
          pageSize: 1000,
          pageToken: pageToken,
          $fields: 'nextPageToken,files(id,name,size,mimeType,appProperties,createdTime,modifiedTime)',
        ),
      );

      final files = list.files ?? [];
      for (final f in files) {
        final name = f.name;
        if (name == null || name.isEmpty) continue;

        if (f.mimeType == 'application/vnd.google-apps.folder') {
          final subPath = currentPathPrefix.isEmpty
              ? name
              : '$currentPathPrefix/$name';
          await _collectKeysRecursively(
            folderId: f.id!,
            currentPathPrefix: subPath,
            keyFilterPrefix: keyFilterPrefix,
            results: results,
          );
        } else {
          final tephraKey = f.appProperties?['tephraKey'];
          final reconstructedKey = tephraKey != null && tephraKey.isNotEmpty
              ? tephraKey
              : (currentPathPrefix.isEmpty ? name : '$currentPathPrefix/$name');

          if (reconstructedKey.startsWith(keyFilterPrefix)) {
            final size = int.tryParse(f.size ?? '0') ?? 0;
            final modified =
                f.modifiedTime?.toUtc() ??
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
            final created = f.createdTime?.toUtc();

            results[reconstructedKey] = RemoteObject(
              key: reconstructedKey,
              size: size,
              modified: modified,
              created: created,
            );

            if (f.id != null) {
              await _effectiveFolders.cacheFileId(reconstructedKey, f.id!);
            }
          }
        }
      }

      pageToken = list.nextPageToken;
    } while (pageToken != null && pageToken.isNotEmpty);
  }

  @override
  Future<RemoteChanges> changesSince(String? cursor) async {
    _effectiveFolders;

    if (cursor == null || cursor.isEmpty) {
      final tokenRes = await _retry.run(
        () => _drive.changes.getStartPageToken(),
      );
      return RemoteChanges(
        changedKeys: const [],
        removedKeys: const [],
        cursor: tokenRes.startPageToken ?? '',
      );
    }

    final keys = <String>{};
    final removedKeys = <String>{};
    String? pageToken = cursor;
    String? newStartPageToken;

    try {
      while (pageToken != null && pageToken.isNotEmpty) {
        final drive.ChangeList list = await _retry.run<drive.ChangeList>(
          () => _drive.changes.list(
            pageToken!,
            pageSize: 1000,
            includeRemoved: true,
            spaces: 'drive',
            $fields: 'nextPageToken,newStartPageToken,changes(fileId,removed,file(id,name,parents,trashed,appProperties))',
          ),
        );

        for (final drive.Change change in list.changes ?? <drive.Change>[]) {
          final drive.File? file = change.file;
          final bool isRemoved =
              change.removed == true || file?.trashed == true;
          final String? tephraKey = file?.appProperties?['tephraKey'];

          if (tephraKey != null && tephraKey.isNotEmpty) {
            if (isRemoved) {
              removedKeys.add(tephraKey);
              keys.remove(tephraKey);
            } else {
              keys.add(tephraKey);
              removedKeys.remove(tephraKey);
            }
          }
        }

        if (list.newStartPageToken != null &&
            list.newStartPageToken!.isNotEmpty) {
          newStartPageToken = list.newStartPageToken;
          break;
        }

        pageToken = list.nextPageToken;
      }
    } on drive.DetailedApiRequestError catch (e) {
      if (e.status == 400 || e.status == 404) {
        // Token invalidated or out of date: return cursorWasReset
        final freshToken = await _retry.run(
          () => _drive.changes.getStartPageToken(),
        );
        return RemoteChanges(
          changedKeys: const [],
          removedKeys: const [],
          cursor: freshToken.startPageToken ?? '',
          cursorWasReset: true,
        );
      }
      rethrow;
    }

    return RemoteChanges(
      changedKeys: keys.toList()..sort(),
      removedKeys: removedKeys.toList()..sort(),
      cursor: newStartPageToken ?? cursor,
    );
  }

  @override
  Future<Quota?> quota() async {
    final about = await _retry.run(
      () => _drive.about.get($fields: 'storageQuota'),
    );

    final usage = int.tryParse(about.storageQuota?.usage ?? '0') ?? 0;
    final limit = int.tryParse(about.storageQuota?.limit ?? '');
    final q = Quota(usedBytes: usage, limitBytes: limit);

    _cachedQuota = q;
    _lastQuotaCheckTime = DateTime.now().toUtc();
    return q;
  }

  Future<void> _checkQuotaBeforeUpload(int bytesToUpload) async {
    final now = DateTime.now().toUtc();
    if (_cachedQuota == null ||
        _lastQuotaCheckTime == null ||
        now.difference(_lastQuotaCheckTime!).inMinutes >= 10) {
      await quota();
    }

    final q = _cachedQuota;
    if (q != null && q.freeBytes != null) {
      const minBuffer = 50 * 1024 * 1024; // 50 MiB buffer
      if (q.freeBytes! < minBuffer + bytesToUpload) {
        throw RemoteQuotaExceededException(
          'Google Drive storage quota nearly full (${q.freeBytes} bytes available)',
        );
      }
    }
  }

  /// Closes the HTTP client.
  Future<void> close() async {
    _client.close();
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
