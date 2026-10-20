// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:typed_data';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:tephra_sync/tephra_sync.dart';
import 'package:test/test.dart';

import '../support/fake_drive_server.dart';
import '../support/sync_provider_contract.dart';

class StubAccessTokenSource implements AccessTokenSource {
  @override
  Future<String> accessToken({bool forceRefresh = false}) async =>
      'stub_token_123';

  @override
  Future<void> signOut() async {}
}

void main() {
  late FakeDriveServer server;
  late StubAccessTokenSource tokenSource;

  setUp(() async {
    server = FakeDriveServer();
    await server.start();
    tokenSource = StubAccessTokenSource();
  });

  tearDown(() async {
    await server.close();
  });

  // 1. Run the standard SyncProvider compliance contract against fake Drive
  runSyncProviderContract('DriveSyncProvider (fake server)', () async {
    return DriveSyncProvider(
      vaultId: 'contract-vault-id',
      vaultName: 'Contract Vault',
      tokenSource: tokenSource,
      rootUrl: server.rootUrl,
      createIfMissing: true,
    );
  });

  group('DriveSyncProvider Drive-specific behaviors', () {
    test(
      'creates required Tephra root, vault folder and sub-folders on connect',
      () async {
        final provider = DriveSyncProvider(
          vaultId: 'v12345',
          vaultName: 'My Notes: Special / Vault',
          tokenSource: tokenSource,
          rootUrl: server.rootUrl,
          createIfMissing: true,
        );

        await provider.connect();

        // Check Tephra root folder
        final rootFolder = server.files.values.firstWhere(
          (f) => f.name == 'Tephra' && f.appProperties['tephraKind'] == 'root',
        );
        expect(rootFolder, isNotNull);

        // Check sanitized vault folder
        final vaultFolder = server.files.values.firstWhere(
          (f) =>
              f.appProperties['tephraKind'] == 'vault' &&
              f.appProperties['tephraVaultId'] == 'v12345',
        );
        expect(vaultFolder.name, equals('My Notes_ Special _ Vault'));
        expect(vaultFolder.parents, contains(rootFolder.id));

        // Check 6 standard sub-folders
        final subNames = server.files.values
            .where((f) => f.parents.contains(vaultFolder.id))
            .map((f) => f.name)
            .toSet();

        expect(
          subNames,
          containsAll([
            'blobs',
            'journals',
            'snapshots',
            'backups',
            'devices',
            'locks',
          ]),
        );
      },
    );

    test('re-creates file on put if cached file ID returns 404', () async {
      final provider = DriveSyncProvider(
        vaultId: 'v404',
        vaultName: 'Test404',
        tokenSource: tokenSource,
        rootUrl: server.rootUrl,
        createIfMissing: true,
      );
      await provider.connect();

      const key = 'snapshots/dev1/001.snap';
      await provider.put(key, [1, 2, 3]);
      expect(await provider.get(key), equals([1, 2, 3]));

      // Remotely hard-remove file from server
      server.files.removeWhere((id, f) => f.name == '001.snap');

      // Next put detects 404, invalidates cache and creates new file cleanly
      await provider.put(key, [4, 5, 6, 7]);
      expect(await provider.get(key), equals([4, 5, 6, 7]));
    });

    test(
      'handles multiple duplicate files per specification (newest modified)',
      () async {
        final provider = DriveSyncProvider(
          vaultId: 'v_dup',
          vaultName: 'TestDup',
          tokenSource: tokenSource,
          rootUrl: server.rootUrl,
          createIfMissing: true,
        );
        await provider.connect();

        const key = 'journals/dev1/entry.json.enc';
        await provider.put(key, [1]);

        final folderId = server.files.values
            .firstWhere((f) => f.name == 'dev1')
            .id;

        // Inject older duplicate file directly into server
        server.files['duplicate_older'] = FakeDriveFile(
          id: 'duplicate_older',
          name: 'entry.json.enc',
          mimeType: 'application/octet-stream',
          parents: [folderId],
          appProperties: {'tephraKey': key},
          modifiedTime: DateTime.utc(2020, 1, 1),
          content: Uint8List.fromList([99]),
        );

        // Clear local memory cache to trigger Drive query with duplicates
        final newProvider = DriveSyncProvider(
          vaultId: 'v_dup',
          vaultName: 'TestDup',
          tokenSource: tokenSource,
          rootUrl: server.rootUrl,
        );
        await newProvider.connect();

        // Should choose newest modifiedTime ([1] rather than [99])
        final content = await newProvider.get(key);
        expect(content, equals([1]));
      },
    );

    test(
      'delete marks file as trashed rather than permanently deleting',
      () async {
        final provider = DriveSyncProvider(
          vaultId: 'v_trash',
          vaultName: 'TestTrash',
          tokenSource: tokenSource,
          rootUrl: server.rootUrl,
          createIfMissing: true,
        );
        await provider.connect();

        const key = 'devices/dev_abc.json';
        await provider.put(key, [1, 2, 3]);

        final file = server.files.values.firstWhere(
          (f) => f.name == 'dev_abc.json',
        );
        expect(file.trashed, isFalse);

        await provider.delete(key);

        expect(file.trashed, isTrue);
        expect(server.files.containsKey(file.id), isTrue);
        expect(
          () => provider.get(key),
          throwsA(isA<RemoteNotFoundException>()),
        );
      },
    );

    test('paginates across 2,500 files during list()', () async {
      final provider = DriveSyncProvider(
        vaultId: 'v_pagination',
        vaultName: 'TestPagination',
        tokenSource: tokenSource,
        rootUrl: server.rootUrl,
        createIfMissing: true,
      );
      await provider.connect();

      // Seed 2,500 fake blobs directly into server
      final blobsFolderId = server.files.values
          .firstWhere((f) => f.name == 'blobs')
          .id;

      for (int i = 0; i < 2500; i++) {
        final id = 'fake_blob_$i';
        final hex = i.toRadixString(16).padLeft(64, '0');
        server.files[id] = FakeDriveFile(
          id: id,
          name: hex,
          mimeType: 'application/octet-stream',
          parents: [blobsFolderId],
          appProperties: {'tephraKey': 'blobs/$hex'},
          content: Uint8List(10),
        );
      }

      final listed = await provider.list('blobs/');
      expect(listed.length, equals(2500));
      expect(listed.first.key, startsWith('blobs/00000000'));
    });

    test('changesSince reports puts and deletes', () async {
      final provider = DriveSyncProvider(
        vaultId: 'v_changes',
        vaultName: 'TestChanges',
        tokenSource: tokenSource,
        rootUrl: server.rootUrl,
        createIfMissing: true,
      );
      await provider.connect();

      final initial = await provider.changesSince(null);
      expect(initial.cursor, isNotEmpty);
      expect(initial.changedKeys, isEmpty);

      await provider.put('journals/dev1/001.json.enc', [1]);
      await provider.put('journals/dev1/002.json.enc', [2]);

      final changes1 = await provider.changesSince(initial.cursor);
      expect(
        changes1.changedKeys,
        containsAll([
          'journals/dev1/001.json.enc',
          'journals/dev1/002.json.enc',
        ]),
      );
      expect(changes1.removedKeys, isEmpty);

      // Delete one file
      await provider.delete('journals/dev1/001.json.enc');

      final changes2 = await provider.changesSince(changes1.cursor);
      expect(changes2.removedKeys, contains('journals/dev1/001.json.enc'));
    });

    test('listRemoteVaults discovers valid vaults on Drive', () async {
      final provider = DriveSyncProvider(
        vaultId: 'vault_discovery_1',
        vaultName: 'Discovery Vault',
        tokenSource: tokenSource,
        rootUrl: server.rootUrl,
        createIfMissing: true,
      );
      await provider.connect();

      // Put vault.json header
      final header = VaultHeader(
        vaultId: 'vault_discovery_1',
        vaultName: 'Discovery Vault',
        encryption: 'none',
        createdAt: DateTime.utc(2026, 10, 20),
        updatedAt: DateTime.utc(2026, 10, 20),
        createdBy: {'deviceId': 'dev1', 'deviceName': 'Pixel 9'},
      );
      await provider.put('vault.json', utf8.encode(header.toPrettyJson()));

      final finder = DriveVaultFinder(
        driveApi: drive.DriveApi(http.Client(), rootUrl: server.rootUrl),
      );

      final vaults = await finder.listRemoteVaults();
      expect(vaults.length, equals(1));
      expect(vaults.first.vaultId, equals('vault_discovery_1'));
      expect(vaults.first.vaultName, equals('Discovery Vault'));
      expect(vaults.first.encrypted, isFalse);
      expect(vaults.first.createdByDeviceName, equals('Pixel 9'));
    });
  });
}
