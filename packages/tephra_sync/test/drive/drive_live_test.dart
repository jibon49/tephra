// © 2026 Tephra. All rights reserved.

@Tags(['live'])
library;

import 'dart:io';
import 'dart:math';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:tephra_sync/tephra_sync.dart';
import 'package:test/test.dart';

import '../auth/desktop_token_source_test.dart';

void main() {
  final refreshToken = Platform.environment['TEPHRA_DRIVE_TEST_REFRESH_TOKEN'];
  final clientId = Platform.environment['TEPHRA_GOOGLE_DESKTOP_CLIENT_ID'];
  final clientSecret =
      Platform.environment['TEPHRA_GOOGLE_DESKTOP_CLIENT_SECRET'];

  final hasLiveCredentials =
      refreshToken != null &&
      refreshToken.isNotEmpty &&
      clientId != null &&
      clientId.isNotEmpty &&
      clientSecret != null &&
      clientSecret.isNotEmpty;

  group('DriveSyncProvider Live Google Account', () {
    test('connects to real Google Drive, performs operations and trashes test vault folder', () async {
      if (!hasLiveCredentials) {
        markTestSkipped(
          'Live Google Drive test credentials not set in environment.',
        );
        return;
      }

      final store = MemorySecretStore();
      final flow = DesktopOAuthFlow(
        clientId: clientId,
        clientSecret: clientSecret,
        openBrowser: (_) async {},
      );

      final tokenSource = DesktopTokenSource(flow: flow, store: store);

      await store.write(SyncSecretKeys.desktopRefreshToken, refreshToken);

      final timestamp = DateTime.now().toUtc().toIso8601String().replaceAll(
        RegExp(r'[:.]'),
        '-',
      );
      final rand = Random().nextInt(9999).toString().padLeft(4, '0');
      final vaultName = 'ci-$timestamp-$rand';
      final vaultId = 'live-vault-$timestamp-$rand';

      final provider = DriveSyncProvider(
        vaultId: vaultId,
        vaultName: vaultName,
        tokenSource: tokenSource,
        createIfMissing: true,
      );

      try {
        await provider.connect();

        // 1. Put and get
        const key = 'devices/ci_device.json';
        final testBytes = [1, 2, 3, 4, 5];
        await provider.put(key, testBytes);

        final downloaded = await provider.get(key);
        expect(downloaded, equals(testBytes));

        // 2. List
        final list = await provider.list('devices/');
        expect(list.any((o) => o.key == key), isTrue);

        // 3. Quota
        final quota = await provider.quota();
        expect(quota?.usedBytes, isNonNegative);

        // 4. Delete
        await provider.delete(key);
        expect(
          () => provider.get(key),
          throwsA(isA<RemoteNotFoundException>()),
        );
      } finally {
        // Cleanup: trash vault folder
        if (provider.vaultFolderId != null) {
          try {
            final driveApi = drive.DriveApi(
              AuthedClient(inner: http.Client(), tokenSource: tokenSource),
            );
            await driveApi.files.update(
              drive.File(trashed: true),
              provider.vaultFolderId!,
            );
          } catch (_) {}
        }
        await provider.close();
      }
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
