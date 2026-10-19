// © 2026 Tephra. All rights reserved.

import 'package:tephra_sync/tephra_sync.dart';
import 'package:test/test.dart';

void main() {
  group('RemoteLayout builders and parsers', () {
    const testDeviceId = '12345678-1234-4234-8234-123456789abc';

    test('vault.json round trip', () {
      final key = RemoteLayout.vaultHeader;
      expect(key, equals('vault.json'));
      final parsed = RemoteLayout.parse(key);
      expect(parsed, isA<VaultHeaderKey>());
      expect(parsed, equals(const VaultHeaderKey()));
    });

    test('blobs/<sha256Hex> round trip and case-insensitivity', () {
      const hex =
          '9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08';
      final key = RemoteLayout.blob(hex.toUpperCase());
      expect(key, equals('blobs/$hex'));

      final parsed = RemoteLayout.parse(key);
      expect(parsed, isA<BlobKey>());
      expect((parsed as BlobKey).hash, equals(hex));
    });

    test(
      'journal builder zero pads firstSeq to 10 digits and parser round trips',
      () {
        final key = RemoteLayout.journal(testDeviceId, 42);
        expect(key, equals('journals/$testDeviceId/0000000042.json.enc'));

        final parsed = RemoteLayout.parse(key);
        expect(parsed, isA<JournalKey>());
        final jKey = parsed as JournalKey;
        expect(jKey.deviceId, equals(testDeviceId));
        expect(jKey.firstSeq, equals(42));
      },
    );

    test(
      'snapshot builder zero pads seq to 10 digits and parser round trips',
      () {
        final key = RemoteLayout.snapshot(testDeviceId, 1050);
        expect(key, equals('snapshots/$testDeviceId/0000001050.json.enc'));

        final parsed = RemoteLayout.parse(key);
        expect(parsed, isA<SnapshotKey>());
        final sKey = parsed as SnapshotKey;
        expect(sKey.deviceId, equals(testDeviceId));
        expect(sKey.seq, equals(1050));
      },
    );

    test('backupManifest builder formats timestamp and parser extracts UTC DateTime', () {
      final dt = DateTime.utc(2026, 10, 19, 14, 30, 45);
      final key = RemoteLayout.backupManifest(dt);
      expect(key, equals('backups/20261019T143045Z/manifest.json.enc'));

      final parsed = RemoteLayout.parse(key);
      expect(parsed, isA<BackupManifestKey>());
      expect((parsed as BackupManifestKey).timestamp, equals(dt));
    });

    test('deviceInfo builder and parser round trip', () {
      final key = RemoteLayout.deviceInfo(testDeviceId);
      expect(key, equals('devices/$testDeviceId.json.enc'));

      final parsed = RemoteLayout.parse(key);
      expect(parsed, isA<DeviceInfoKey>());
      expect((parsed as DeviceInfoKey).deviceId, equals(testDeviceId));
    });

    test('deviceRevocation builder and parser round trip', () {
      final key = RemoteLayout.deviceRevocation(testDeviceId);
      expect(key, equals('devices/$testDeviceId.revoked.json.enc'));

      final parsed = RemoteLayout.parse(key);
      expect(parsed, isA<DeviceRevocationKey>());
      expect((parsed as DeviceRevocationKey).deviceId, equals(testDeviceId));
    });

    test('gcLease builder and parser round trip', () {
      final key = RemoteLayout.gcLease(testDeviceId);
      expect(key, equals('locks/gc-$testDeviceId.json.enc'));

      final parsed = RemoteLayout.parse(key);
      expect(parsed, isA<GcLeaseKey>());
      expect((parsed as GcLeaseKey).deviceId, equals(testDeviceId));
    });

    test('gcState round trip', () {
      final key = RemoteLayout.gcState;
      expect(key, equals('locks/gc-state.json.enc'));

      final parsed = RemoteLayout.parse(key);
      expect(parsed, isA<GcStateKey>());
    });

    test('unknown keys parse to UnknownKey', () {
      const keys = [
        'unknown.txt',
        'blobs/short',
        'blobs/invalidchars_not_hex_length_64_characters_long_1234567890abcdef',
        'journals/bad-uuid/0000000001.json.enc',
        'snapshots/123/1.json.enc',
        'backups/invalid-date/manifest.json.enc',
        'devices/bad_name.json',
        'locks/unrelated.lock',
      ];
      for (final k in keys) {
        final parsed = RemoteLayout.parse(k);
        expect(parsed, isA<UnknownKey>());
        expect((parsed as UnknownKey).key, equals(k));
      }
    });

    test('prefix helpers produce correct prefix strings', () {
      expect(RemoteLayout.blobsPrefix, equals('blobs/'));
      expect(RemoteLayout.journalsPrefix, equals('journals/'));
      expect(
        RemoteLayout.deviceJournalsPrefix('DEV1'),
        equals('journals/dev1/'),
      );
      expect(RemoteLayout.snapshotsPrefix, equals('snapshots/'));
      expect(
        RemoteLayout.deviceSnapshotsPrefix('DEV1'),
        equals('snapshots/dev1/'),
      );
      expect(RemoteLayout.devicesPrefix, equals('devices/'));
      expect(RemoteLayout.backupsPrefix, equals('backups/'));
      expect(RemoteLayout.locksPrefix, equals('locks/'));
    });
  });
}
