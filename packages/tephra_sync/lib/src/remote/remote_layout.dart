// © 2026 Tephra. All rights reserved.

/// Sealed representation of a parsed remote object key.
sealed class RemoteKey {
  const RemoteKey();
}

/// The public unencrypted header file `vault.json`.
final class VaultHeaderKey extends RemoteKey {
  const VaultHeaderKey();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is VaultHeaderKey;

  @override
  int get hashCode => 1;

  @override
  String toString() => 'VaultHeaderKey()';
}

/// Content-addressed ciphertext blob `blobs/<sha256Hex>`.
final class BlobKey extends RemoteKey {
  const BlobKey(this.hash);

  /// Lower-case SHA-256 hex digest of stored blob bytes.
  final String hash;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is BlobKey && hash == other.hash;

  @override
  int get hashCode => hash.hashCode;

  @override
  String toString() => 'BlobKey($hash)';
}

/// Append-only device journal `journals/<deviceId>/<10-digit firstSeq>.json.enc`.
final class JournalKey extends RemoteKey {
  const JournalKey(this.deviceId, this.firstSeq);

  /// Lower-case UUID of the device that wrote this journal.
  final String deviceId;

  /// Starting sequence number of entries in this journal batch.
  final int firstSeq;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JournalKey &&
          deviceId == other.deviceId &&
          firstSeq == other.firstSeq;

  @override
  int get hashCode => Object.hash(deviceId, firstSeq);

  @override
  String toString() => 'JournalKey($deviceId, $firstSeq)';
}

/// Compacted device snapshot `snapshots/<deviceId>/<10-digit seq>.json.enc`.
final class SnapshotKey extends RemoteKey {
  const SnapshotKey(this.deviceId, this.seq);

  /// Lower-case UUID of the device that wrote this snapshot.
  final String deviceId;

  /// Sequence number up to which this snapshot covers state.
  final int seq;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SnapshotKey && deviceId == other.deviceId && seq == other.seq;

  @override
  int get hashCode => Object.hash(deviceId, seq);

  @override
  String toString() => 'SnapshotKey($deviceId, $seq)';
}

/// Backup manifest `backups/<yyyyMMddTHHmmssZ>/manifest.json.enc`.
final class BackupManifestKey extends RemoteKey {
  const BackupManifestKey(this.timestamp);

  /// UTC timestamp of the backup.
  final DateTime timestamp;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BackupManifestKey && timestamp == other.timestamp;

  @override
  int get hashCode => timestamp.hashCode;

  @override
  String toString() => 'BackupManifestKey($timestamp)';
}

/// Device info descriptor `devices/<deviceId>.json.enc`.
final class DeviceInfoKey extends RemoteKey {
  const DeviceInfoKey(this.deviceId);

  /// Lower-case UUID of the device.
  final String deviceId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceInfoKey && deviceId == other.deviceId;

  @override
  int get hashCode => deviceId.hashCode;

  @override
  String toString() => 'DeviceInfoKey($deviceId)';
}

/// Device revocation record `devices/<deviceId>.revoked.json.enc`.
final class DeviceRevocationKey extends RemoteKey {
  const DeviceRevocationKey(this.deviceId);

  /// Lower-case UUID of the revoked device.
  final String deviceId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceRevocationKey && deviceId == other.deviceId;

  @override
  int get hashCode => deviceId.hashCode;

  @override
  String toString() => 'DeviceRevocationKey($deviceId)';
}

/// Garbage collection lease file `locks/gc-<deviceId>.json.enc`.
final class GcLeaseKey extends RemoteKey {
  const GcLeaseKey(this.deviceId);

  /// Lower-case UUID of the leasing device.
  final String deviceId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GcLeaseKey && deviceId == other.deviceId;

  @override
  int get hashCode => deviceId.hashCode;

  @override
  String toString() => 'GcLeaseKey($deviceId)';
}

/// Global garbage collection state file `locks/gc-state.json.enc`.
final class GcStateKey extends RemoteKey {
  const GcStateKey();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is GcStateKey;

  @override
  int get hashCode => 2;

  @override
  String toString() => 'GcStateKey()';
}

/// Forward-compatible representation of unrecognised keys.
final class UnknownKey extends RemoteKey {
  const UnknownKey(this.key);

  /// Raw key string.
  final String key;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is UnknownKey && key == other.key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'UnknownKey($key)';
}

/// Canonical key builders, parsers, and prefix constants for remote vault layout.
///
/// **Why per-device append-only journals:** Google Drive has no reliable
/// compare-and-swap. If two devices rewrote one shared manifest, one write would
/// silently overwrite the other. In this layout every mutable object has exactly
/// one writer (its device id is in the name), blobs are immutable and named by
/// their hash, and journal file names are unique (device id + sequence number).
/// Two devices can therefore never overwrite each other's data, whatever order
/// Drive applies writes in.
abstract final class RemoteLayout {
  /// The public unencrypted vault header object name.
  static const String vaultHeader = 'vault.json';

  /// Prefix for immutable content-addressed blobs.
  static const String blobsPrefix = 'blobs/';

  /// Prefix for append-only journals across all devices.
  static const String journalsPrefix = 'journals/';

  /// Prefix for device snapshots across all devices.
  static const String snapshotsPrefix = 'snapshots/';

  /// Prefix for backup manifests.
  static const String backupsPrefix = 'backups/';

  /// Prefix for device identity and revocation files.
  static const String devicesPrefix = 'devices/';

  /// Prefix for lock and lease files.
  static const String locksPrefix = 'locks/';

  /// The global GC candidate state key.
  static const String gcState = 'locks/gc-state.json.enc';

  /// Returns the key for a content-addressed ciphertext blob.
  static String blob(String sha256Hex) {
    return 'blobs/${sha256Hex.toLowerCase()}';
  }

  /// Returns the key for an append-only journal batch.
  static String journal(String deviceId, int firstSeq) {
    final seqStr = firstSeq.toString().padLeft(10, '0');
    return 'journals/${deviceId.toLowerCase()}/$seqStr.json.enc';
  }

  /// Returns prefix for all journals written by [deviceId].
  static String deviceJournalsPrefix(String deviceId) {
    return 'journals/${deviceId.toLowerCase()}/';
  }

  /// Returns the key for a compacted device snapshot.
  static String snapshot(String deviceId, int seq) {
    final seqStr = seq.toString().padLeft(10, '0');
    return 'snapshots/${deviceId.toLowerCase()}/$seqStr.json.enc';
  }

  /// Returns prefix for all snapshots written by [deviceId].
  static String deviceSnapshotsPrefix(String deviceId) {
    return 'snapshots/${deviceId.toLowerCase()}/';
  }

  /// Returns the key for a backup manifest timestamped at [utc].
  static String backupManifest(DateTime utc) {
    final ts = _formatTimestamp(utc);
    return 'backups/$ts/manifest.json.enc';
  }

  /// Returns the key for a device info descriptor.
  static String deviceInfo(String deviceId) {
    return 'devices/${deviceId.toLowerCase()}.json.enc';
  }

  /// Returns the key for a device revocation record.
  static String deviceRevocation(String deviceId) {
    return 'devices/${deviceId.toLowerCase()}.revoked.json.enc';
  }

  /// Returns the key for a GC lease owned by [deviceId].
  static String gcLease(String deviceId) {
    return 'locks/gc-${deviceId.toLowerCase()}.json.enc';
  }

  /// Parses an arbitrary remote [key] into a structured [RemoteKey].
  static RemoteKey parse(String key) {
    if (key == vaultHeader) {
      return const VaultHeaderKey();
    }
    if (key == gcState) {
      return const GcStateKey();
    }

    // blobs/<64 hex>
    if (key.startsWith('blobs/')) {
      final sub = key.substring('blobs/'.length);
      if (sub.length == 64 && RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(sub)) {
        return BlobKey(sub.toLowerCase());
      }
      return UnknownKey(key);
    }

    // journals/<deviceId>/<10-digit firstSeq>.json.enc
    if (key.startsWith('journals/')) {
      final match = RegExp(
        r'^journals/([0-9a-fA-F\-]{36})/(\d{10})\.json\.enc$',
      ).firstMatch(key);
      if (match != null) {
        final devId = match.group(1)!.toLowerCase();
        final seq = int.tryParse(match.group(2)!);
        if (seq != null) {
          return JournalKey(devId, seq);
        }
      }
      return UnknownKey(key);
    }

    // snapshots/<deviceId>/<10-digit seq>.json.enc
    if (key.startsWith('snapshots/')) {
      final match = RegExp(
        r'^snapshots/([0-9a-fA-F\-]{36})/(\d{10})\.json\.enc$',
      ).firstMatch(key);
      if (match != null) {
        final devId = match.group(1)!.toLowerCase();
        final seq = int.tryParse(match.group(2)!);
        if (seq != null) {
          return SnapshotKey(devId, seq);
        }
      }
      return UnknownKey(key);
    }

    // backups/<yyyyMMddTHHmmssZ>/manifest.json.enc
    if (key.startsWith('backups/')) {
      final match = RegExp(
        r'^backups/(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z/manifest\.json\.enc$',
      ).firstMatch(key);
      if (match != null) {
        final y = int.parse(match.group(1)!);
        final m = int.parse(match.group(2)!);
        final d = int.parse(match.group(3)!);
        final h = int.parse(match.group(4)!);
        final min = int.parse(match.group(5)!);
        final s = int.parse(match.group(6)!);
        final dt = DateTime.utc(y, m, d, h, min, s);
        return BackupManifestKey(dt);
      }
      return UnknownKey(key);
    }

    // devices/<deviceId>.revoked.json.enc or devices/<deviceId>.json.enc
    if (key.startsWith('devices/')) {
      final matchRev = RegExp(
        r'^devices/([0-9a-fA-F\-]{36})\.revoked\.json\.enc$',
      ).firstMatch(key);
      if (matchRev != null) {
        return DeviceRevocationKey(matchRev.group(1)!.toLowerCase());
      }
      final matchDev = RegExp(r'^devices/([0-9a-fA-F\-]{36})\.json\.enc$')
          .firstMatch(key);
      if (matchDev != null) {
        return DeviceInfoKey(matchDev.group(1)!.toLowerCase());
      }
      return UnknownKey(key);
    }

    // locks/gc-<deviceId>.json.enc
    if (key.startsWith('locks/')) {
      final matchLease = RegExp(r'^locks/gc-([0-9a-fA-F\-]{36})\.json\.enc$')
          .firstMatch(key);
      if (matchLease != null) {
        return GcLeaseKey(matchLease.group(1)!.toLowerCase());
      }
      return UnknownKey(key);
    }

    return UnknownKey(key);
  }

  static String _formatTimestamp(DateTime utc) {
    final d = utc.toUtc();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final h = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    final s = d.second.toString().padLeft(2, '0');
    return '$y$m${day}T$h$min${s}Z';
  }
}
