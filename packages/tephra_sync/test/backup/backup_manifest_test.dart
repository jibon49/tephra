// © 2026 Tephra. All rights reserved.

import 'package:tephra_sync/tephra_sync.dart';
import 'package:test/test.dart';

void main() {
  group('BackupManifest', () {
    test('JSON round trip and file sorting', () {
      final now = DateTime.utc(2026, 10, 20, 14, 0, 0);
      final files = [
        const BackupManifestFile(
          path: 'Z_Note.md',
          hash: 'hash-z',
          size: 200,
          mtime: 1760000000000,
          blobKeys: ['blobs/bz'],
        ),
        const BackupManifestFile(
          path: 'A_Note.md',
          hash: 'hash-a',
          size: 100,
          mtime: 1760000000000,
          blobKeys: ['blobs/ba'],
        ),
      ];

      final manifest = BackupManifest(
        vaultId: 'v-123',
        createdAt: now,
        deviceId: 'dev-1',
        deviceName: 'Desktop PC',
        kind: BackupKind.scheduled,
        fileCount: 2,
        totalBytes: 300,
        files: files,
      );

      // Files should be sorted deterministically by path
      expect(manifest.files.first.path, equals('A_Note.md'));
      expect(manifest.files.last.path, equals('Z_Note.md'));

      final json = manifest.toJson();
      expect(json['v'], equals(1));
      expect(json['vaultId'], equals('v-123'));
      expect(json['kind'], equals('scheduled'));

      final parsed = BackupManifest.fromJson(json);
      expect(parsed.vaultId, equals(manifest.vaultId));
      expect(parsed.createdAt, equals(manifest.createdAt));
      expect(parsed.deviceId, equals(manifest.deviceId));
      expect(parsed.deviceName, equals(manifest.deviceName));
      expect(parsed.kind, equals(BackupKind.scheduled));
      expect(parsed.fileCount, equals(2));
      expect(parsed.totalBytes, equals(300));
      expect(parsed.files.length, equals(2));
      expect(parsed.files.first.path, equals('A_Note.md'));
      expect(parsed.files.last.path, equals('Z_Note.md'));
    });

    test(
      'seal and open with PlaintextObjectCipher and EncryptingObjectCipher',
      () async {
        final now = DateTime.utc(2026, 10, 20, 15, 30, 45);
        final manifest = BackupManifest(
          vaultId: 'v-enc',
          createdAt: now,
          deviceId: 'dev-2',
          deviceName: 'Pixel 9',
          kind: BackupKind.manual,
          fileCount: 1,
          totalBytes: 42,
          files: [
            const BackupManifestFile(
              path: 'Daily.md',
              hash: 'h-daily',
              size: 42,
              mtime: 1760000000000,
              blobKeys: ['blobs/b1'],
            ),
          ],
        );

        // 1. Plaintext cipher
        final plainCipher = PlaintextObjectCipher();
        final sealedPlain = await manifest.seal(plainCipher);
        final openedPlain = await BackupManifest.open(sealedPlain, plainCipher);
        expect(openedPlain.vaultId, equals(manifest.vaultId));
        expect(openedPlain.kind, equals(BackupKind.manual));
        expect(openedPlain.files.first.path, equals('Daily.md'));

        // 2. Encrypting cipher
        final masterKey = MasterKey(List.generate(32, (i) => i));
        final encCipher = EncryptingObjectCipher(
          masterKey: masterKey.secretKey,
          vaultId: 'v-enc',
        );
        final sealedEnc = await manifest.seal(encCipher);
        expect(sealedEnc, isNot(equals(sealedPlain)));

        final openedEnc = await BackupManifest.open(sealedEnc, encCipher);
        expect(openedEnc.vaultId, equals(manifest.vaultId));
        expect(openedEnc.kind, equals(BackupKind.manual));
        expect(openedEnc.files.first.path, equals('Daily.md'));
      },
    );

    test('formatStamp and parseStamp round trip', () {
      final dt = DateTime.utc(2026, 10, 11, 3, 0, 0);
      final stamp = BackupManifest.formatStamp(dt);
      expect(stamp, equals('20261011T030000Z'));
      final parsed = BackupManifest.parseStamp(stamp);
      expect(parsed, equals(dt));
    });
  });
}
