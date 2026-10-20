// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../auth/access_token_source.dart';
import '../auth/authed_client.dart';
import '../remote/vault_header.dart';
import 'drive_folders.dart';
import 'drive_retry.dart';

final _log = Logger('sync.drive');

/// Summary information about an existing remote vault on Google Drive.
class RemoteVaultInfo {
  const RemoteVaultInfo({
    required this.vaultId,
    required this.vaultName,
    required this.createdAt,
    required this.createdByDeviceName,
    required this.encrypted,
    required this.folderId,
  });

  final String vaultId;
  final String vaultName;
  final DateTime createdAt;
  final String createdByDeviceName;
  final bool encrypted;
  final String folderId;

  @override
  String toString() =>
      'RemoteVaultInfo(vaultId: $vaultId, vaultName: $vaultName, encrypted: $encrypted)';
}

/// Discovers existing Tephra vaults on Google Drive and initializes new remote vault hierarchies.
class DriveVaultFinder {
  DriveVaultFinder({required drive.DriveApi driveApi, DriveRetry? retry})
    : _drive = driveApi,
      _retry = retry ?? const DriveRetry();

  /// Constructs a [DriveVaultFinder] using an authenticated [tokenSource].
  factory DriveVaultFinder.fromTokenSource(
    AccessTokenSource tokenSource, {
    http.Client? httpClient,
    DriveRetry? retry,
  }) {
    final client = AuthedClient(
      inner: httpClient ?? http.Client(),
      tokenSource: tokenSource,
      closeInner: httpClient == null,
    );
    return DriveVaultFinder(driveApi: drive.DriveApi(client), retry: retry);
  }

  final drive.DriveApi _drive;
  final DriveRetry _retry;

  /// Lists all accessible Tephra vaults in Google Drive.
  Future<List<RemoteVaultInfo>> listRemoteVaults() async {
    const q =
        "appProperties has { key='tephraKind' and value='vault' } and mimeType = 'application/vnd.google-apps.folder' and trashed = false";

    final list = await _retry.run(
      () => _drive.files.list(
        q: q,
        spaces: 'drive',
        $fields: 'files(id,name,appProperties,createdTime)',
      ),
    );

    final results = <RemoteVaultInfo>[];
    final vaultFolders = list.files ?? [];

    for (final folder in vaultFolders) {
      final folderId = folder.id;
      if (folderId == null) continue;

      try {
        final vaultJsonList = await _retry.run(
          () => _drive.files.list(
            q: "'$folderId' in parents and name = 'vault.json' and trashed = false",
            spaces: 'drive',
            $fields: 'files(id,name)',
          ),
        );

        final files = vaultJsonList.files;
        if (files == null || files.isEmpty) continue;

        final vaultJsonFile = files.first;
        final media = await _retry.run(
          () => _drive.files.get(
            vaultJsonFile.id!,
            downloadOptions: drive.DownloadOptions.fullMedia,
          ),
        ) as drive.Media;

        final bytes = await media.stream.fold<List<int>>(
          <int>[],
          (prev, chunk) => prev..addAll(chunk),
        );
        final jsonStr = utf8.decode(bytes);
        final jsonMap = jsonDecode(jsonStr) as Map<String, dynamic>;
        final header = VaultHeader.fromJson(jsonMap.cast<String, Object?>());

        results.add(
          RemoteVaultInfo(
            vaultId: header.vaultId,
            vaultName: header.vaultName,
            createdAt: header.createdAt,
            createdByDeviceName:
                (header.createdBy['deviceName'] as String?) ?? 'Unknown',
            encrypted: header.encryption != 'none',
            folderId: folderId,
          ),
        );
      } catch (e) {
        _log.warning('Failed to inspect vault folder $folderId: $e');
      }
    }

    return results;
  }

  /// Finds existing or creates the root `My Drive/Tephra/` folder.
  Future<String> ensureTephraRoot() async {
    const q =
        "name = 'Tephra' and mimeType = 'application/vnd.google-apps.folder' and trashed = false";

    final list = await _retry.run(
      () => _drive.files.list(
        q: q,
        spaces: 'drive',
        $fields: 'files(id,name,createdTime,appProperties)',
      ),
    );

    final files = list.files;
    if (files != null && files.isNotEmpty) {
      files.sort((a, b) {
        final aTime = a.createdTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aTime.compareTo(bTime);
      });
      return files.first.id!;
    }

    final rootFolder = drive.File(
      name: 'Tephra',
      mimeType: 'application/vnd.google-apps.folder',
      parents: ['root'],
      appProperties: {'tephraKind': 'root'},
    );

    final created = await _retry.run(
      () => _drive.files.create(rootFolder, $fields: 'id'),
    );
    return created.id!;
  }

  /// Creates the remote folder hierarchy for [vaultName] and [vaultId] and returns the vault folder ID.
  Future<String> createVaultFolders(String vaultName, String vaultId) async {
    final rootId = await ensureTephraRoot();
    final folderName = DriveFolders.sanitizeVaultFolderName(vaultName);

    final vaultFolder = drive.File(
      name: folderName,
      mimeType: 'application/vnd.google-apps.folder',
      parents: [rootId],
      appProperties: {'tephraKind': 'vault', 'tephraVaultId': vaultId},
    );

    final createdVault = await _retry.run(
      () => _drive.files.create(vaultFolder, $fields: 'id'),
    );
    final vaultFolderId = createdVault.id!;

    // Create 6 standard sub-folders
    final subFolders = [
      'blobs',
      'journals',
      'snapshots',
      'backups',
      'devices',
      'locks',
    ];

    for (final sub in subFolders) {
      final sf = drive.File(
        name: sub,
        mimeType: 'application/vnd.google-apps.folder',
        parents: [vaultFolderId],
      );
      await _retry.run(() => _drive.files.create(sf, $fields: 'id'));
    }

    return vaultFolderId;
  }
}
