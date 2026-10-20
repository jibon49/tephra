// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:io';

import '../crypto/object_cipher.dart';
import '../crypto/object_purpose.dart';

/// The trigger category under which a backup was captured.
enum BackupKind {
  /// Regular interval timer (hourly, daily, or weekly).
  scheduled,

  /// Triggered explicitly by the user via button or command.
  manual,

  /// Snapshot taken immediately prior to a full or partial restore.
  preRestore;

  /// Parses a kind from its JSON string representation.
  static BackupKind fromString(String val) {
    return switch (val) {
      'scheduled' => BackupKind.scheduled,
      'manual' => BackupKind.manual,
      'preRestore' => BackupKind.preRestore,
      _ => BackupKind.manual,
    };
  }

  /// Serializes kind to standard JSON string.
  String toJson() => name;
}

/// Metadata describing a single file captured inside a [BackupManifest].
final class BackupManifestFile implements Comparable<BackupManifestFile> {
  /// Creates a [BackupManifestFile].
  const BackupManifestFile({
    required this.path,
    required this.hash,
    required this.size,
    required this.mtime,
    required this.blobKeys,
  });

  /// Parses a file record from JSON.
  factory BackupManifestFile.fromJson(Map<String, dynamic> json) {
    return BackupManifestFile(
      path: json['path'] as String,
      hash: json['hash'] as String,
      size: (json['size'] as num).toInt(),
      mtime: (json['mtime'] as num).toInt(),
      blobKeys: (json['blobKeys'] as List).cast<String>(),
    );
  }

  /// Vault-relative forward-slash normalized path.
  final String path;

  /// Plaintext content SHA-256 hex digest.
  final String hash;

  /// File length in bytes.
  final int size;

  /// Last modification timestamp in milliseconds UTC.
  final int mtime;

  /// Ordered list of remote blob storage keys comprising the content.
  final List<String> blobKeys;

  /// Converts this file record to a JSON map.
  Map<String, dynamic> toJson() => {
    'path': path,
    'hash': hash,
    'size': size,
    'mtime': mtime,
    'blobKeys': blobKeys,
  };

  @override
  int compareTo(BackupManifestFile other) => path.compareTo(other.path);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BackupManifestFile &&
          runtimeType == other.runtimeType &&
          path == other.path &&
          hash == other.hash &&
          size == other.size &&
          mtime == other.mtime &&
          _listEquals(blobKeys, other.blobKeys);

  @override
  int get hashCode =>
      Object.hash(path, hash, size, mtime, Object.hashAll(blobKeys));

  @override
  String toString() => 'BackupManifestFile(path: $path, size: $size)';
}

/// Point-in-time snapshot manifest describing all files in the vault.
final class BackupManifest {
  /// Creates a [BackupManifest].
  BackupManifest({
    this.version = 1,
    required this.vaultId,
    required this.createdAt,
    required this.deviceId,
    required this.deviceName,
    required this.kind,
    required this.fileCount,
    required this.totalBytes,
    required List<BackupManifestFile> files,
  }) : files = List.unmodifiable(List<BackupManifestFile>.from(files)..sort());

  /// Parses a manifest from a JSON object.
  factory BackupManifest.fromJson(Map<String, dynamic> json) {
    final rawFiles = (json['files'] as List? ?? const [])
        .map((f) => BackupManifestFile.fromJson(f as Map<String, dynamic>))
        .toList();

    return BackupManifest(
      version: (json['v'] as num?)?.toInt() ?? 1,
      vaultId: json['vaultId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      deviceId: json['deviceId'] as String,
      deviceName: (json['deviceName'] as String?) ?? 'Unknown Device',
      kind: BackupKind.fromString(json['kind'] as String? ?? 'scheduled'),
      fileCount: (json['fileCount'] as num).toInt(),
      totalBytes: (json['totalBytes'] as num).toInt(),
      files: rawFiles,
    );
  }

  /// Schema version.
  final int version;

  /// Identifier of the vault.
  final String vaultId;

  /// UTC creation timestamp.
  final DateTime createdAt;

  /// Originating device identifier.
  final String deviceId;

  /// Human-readable device name.
  final String deviceName;

  /// Trigger kind.
  final BackupKind kind;

  /// Total files included.
  final int fileCount;

  /// Total size in bytes of all included files.
  final int totalBytes;

  /// Files included in this backup, sorted deterministically by path.
  final List<BackupManifestFile> files;

  /// Timestamp stamp representation (`yyyyMMddTHHmmssZ`).
  String get stamp => formatStamp(createdAt);

  /// Converts this manifest to its JSON object representation.
  Map<String, dynamic> toJson() => {
    'v': version,
    'vaultId': vaultId,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'deviceId': deviceId,
    'deviceName': deviceName,
    'kind': kind.toJson(),
    'fileCount': fileCount,
    'totalBytes': totalBytes,
    'files': files.map((f) => f.toJson()).toList(),
  };

  /// Encodes and seals this manifest into gzip-compressed, encrypted bytes.
  Future<List<int>> seal(ObjectCipher cipher) async {
    final jsonStr = jsonEncode(toJson());
    final compressed = gzip.encode(utf8.encode(jsonStr));
    return cipher.seal(compressed, ObjectPurpose.manifest);
  }

  /// Opens, decrypts, decompresses, and parses a [BackupManifest] from remote bytes.
  static Future<BackupManifest> open(
    List<int> bytes,
    ObjectCipher cipher,
  ) async {
    final opened = await cipher.open(bytes, ObjectPurpose.manifest);
    final decompressed = gzip.decode(opened);
    final map = jsonDecode(utf8.decode(decompressed)) as Map<String, dynamic>;
    return BackupManifest.fromJson(map);
  }

  /// Formats [utc] into a standard stamp string (`yyyyMMddTHHmmssZ`).
  static String formatStamp(DateTime utc) {
    final d = utc.toUtc();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final h = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    final s = d.second.toString().padLeft(2, '0');
    return '$y$m${day}T$h$min${s}Z';
  }

  /// Parses a standard stamp string (`yyyyMMddTHHmmssZ`) into a UTC [DateTime].
  static DateTime parseStamp(String stamp) {
    final match = RegExp(r'^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z$')
        .firstMatch(stamp);
    if (match == null) {
      throw FormatException('Invalid backup stamp format: "$stamp"');
    }
    final y = int.parse(match.group(1)!);
    final m = int.parse(match.group(2)!);
    final d = int.parse(match.group(3)!);
    final h = int.parse(match.group(4)!);
    final min = int.parse(match.group(5)!);
    final s = int.parse(match.group(6)!);
    return DateTime.utc(y, m, d, h, min, s);
  }
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
