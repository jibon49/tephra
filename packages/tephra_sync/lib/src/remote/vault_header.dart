// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import '../crypto/kdf_params.dart';
import '../crypto/key_wrap.dart';
import '../errors/sync_exceptions.dart';

/// Immutable remote vault header stored in `vault.json`.
final class VaultHeader {
  /// Creates a [VaultHeader].
  const VaultHeader({
    this.format = defaultFormat,
    this.formatVersion = currentFormatVersion,
    required this.vaultId,
    required this.vaultName,
    required this.createdAt,
    required this.createdBy,
    required this.updatedAt,
    required this.encryption,
    this.kdf,
    this.wrappedKeys,
    this.chunking = defaultChunking,
    this.extraFields = const {},
  });

  /// Parses [VaultHeader] from JSON, preserving unrecognized fields in [extraFields].
  ///
  /// Throws [RemoteFormatException] if [format] is not 'tephra-remote',
  /// [formatVersion] is greater than 1, or required fields are missing.
  factory VaultHeader.fromJson(Map<String, Object?> json) {
    final formatRaw = json['format'];
    if (formatRaw != defaultFormat) {
      throw RemoteFormatException('Unsupported vault format: $formatRaw');
    }
    const format = defaultFormat;

    final version = (json['formatVersion'] as num?)?.toInt();
    if (version == null) {
      throw const RemoteFormatException('Missing formatVersion in vault.json');
    }
    if (version > currentFormatVersion) {
      throw RemoteFormatException(
        'Unsupported formatVersion: $version (expected <= $currentFormatVersion)',
      );
    }

    final vaultId = json['vaultId'] as String?;
    final vaultName = json['vaultName'] as String?;
    final createdAtStr = json['createdAt'] as String?;
    final createdByRaw = json['createdBy'];
    final updatedAtStr = json['updatedAt'] as String?;
    final encryption = json['encryption'] as String?;

    if (vaultId == null ||
        vaultName == null ||
        createdAtStr == null ||
        createdByRaw is! Map ||
        updatedAtStr == null ||
        encryption == null) {
      throw const RemoteFormatException('Missing required field in vault.json');
    }

    final createdBy = (createdByRaw as Map<Object?, Object?>)
        .cast<String, Object?>();

    KdfParams? kdf;
    Map<String, WrappedKey>? wrappedKeys;

    if (encryption != 'none') {
      final kdfRaw = json['kdf'];
      if (kdfRaw is! Map) {
        throw const RemoteFormatException(
          'Missing kdf configuration for encrypted vault',
        );
      }
      kdf = KdfParams.fromJson(kdfRaw.cast<String, Object?>());

      final wrappedRaw = json['wrappedKeys'];
      if (wrappedRaw is! Map) {
        throw const RemoteFormatException(
          'Missing wrappedKeys for encrypted vault',
        );
      }
      final wrappedMap = wrappedRaw.cast<String, Object?>();
      wrappedKeys = {
        for (final entry in wrappedMap.entries)
          entry.key: WrappedKey.fromJson(
            (entry.value as Map).cast<String, Object?>(),
          ),
      };
    }

    final chunking = json['chunking'] is Map
        ? (json['chunking'] as Map<Object?, Object?>).cast<String, Object?>()
        : defaultChunking;

    // Collect unknown extra fields
    const knownKeys = {
      'format',
      'formatVersion',
      'vaultId',
      'vaultName',
      'createdAt',
      'createdBy',
      'updatedAt',
      'encryption',
      'kdf',
      'wrappedKeys',
      'chunking',
    };
    final extra = <String, Object?>{};
    for (final e in json.entries) {
      if (!knownKeys.contains(e.key)) {
        extra[e.key] = e.value;
      }
    }

    return VaultHeader(
      format: format,
      formatVersion: version,
      vaultId: vaultId,
      vaultName: vaultName,
      createdAt: DateTime.parse(createdAtStr),
      createdBy: createdBy,
      updatedAt: DateTime.parse(updatedAtStr),
      encryption: encryption,
      kdf: kdf,
      wrappedKeys: wrappedKeys,
      chunking: chunking,
      extraFields: extra,
    );
  }

  /// Default format identifier ('tephra-remote').
  static const String defaultFormat = 'tephra-remote';

  /// Supported remote header format version (1).
  static const int currentFormatVersion = 1;

  /// Default FastCDC chunking parameters.
  static const Map<String, Object?> defaultChunking = {
    'alg': 'fastcdc-gear32-v1',
    'min': 262144,
    'avg': 1048576,
    'max': 4194304,
    'singleBlobMax': 4194304,
  };

  /// File format identifier ('tephra-remote').
  final String format;

  /// Format version (1).
  final int formatVersion;

  /// Globally unique UUID v4 identifier for the remote vault.
  final String vaultId;

  /// User-defined display name of the vault.
  final String vaultName;

  /// UTC timestamp when the vault was first created.
  final DateTime createdAt;

  /// Details of the device that created the vault.
  final Map<String, Object?> createdBy;

  /// UTC timestamp of last metadata or password modification.
  final DateTime updatedAt;

  /// Encryption mode: 'aes-256-gcm' or 'none'.
  final String encryption;

  /// Argon2id KDF parameters (present only when encrypted).
  final KdfParams? kdf;

  /// Wrapped master key entries ('password' and 'recovery').
  final Map<String, WrappedKey>? wrappedKeys;

  /// FastCDC chunking configuration.
  final Map<String, Object?> chunking;

  /// Additional forward-compatible unknown fields preserved across rewrites.
  final Map<String, Object?> extraFields;

  /// Returns true if this vault is encrypted with AES-256-GCM.
  bool get isEncrypted => encryption != 'none';

  /// Serializes this [VaultHeader] to a JSON map.
  Map<String, Object?> toJson() {
    final map = <String, Object?>{
      'format': format,
      'formatVersion': formatVersion,
      'vaultId': vaultId,
      'vaultName': vaultName,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'createdBy': createdBy,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'encryption': encryption,
    };

    if (isEncrypted) {
      if (kdf != null) {
        map['kdf'] = kdf!.toJson();
      }
      if (wrappedKeys != null) {
        map['wrappedKeys'] = {
          for (final e in wrappedKeys!.entries) e.key: e.value.toJson(),
        };
      }
    }

    map['chunking'] = chunking;

    // Append preserved unknown fields
    for (final e in extraFields.entries) {
      map.putIfAbsent(e.key, () => e.value);
    }

    return map;
  }

  /// Converts this [VaultHeader] to a 2-space indented pretty-printed JSON string.
  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());

  /// Returns a copy of [VaultHeader] with optional field overrides.
  VaultHeader copyWith({
    String? format,
    int? formatVersion,
    String? vaultId,
    String? vaultName,
    DateTime? createdAt,
    Map<String, Object?>? createdBy,
    DateTime? updatedAt,
    String? encryption,
    KdfParams? kdf,
    Map<String, WrappedKey>? wrappedKeys,
    Map<String, Object?>? chunking,
    Map<String, Object?>? extraFields,
  }) {
    return VaultHeader(
      format: format ?? this.format,
      formatVersion: formatVersion ?? this.formatVersion,
      vaultId: vaultId ?? this.vaultId,
      vaultName: vaultName ?? this.vaultName,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      updatedAt: updatedAt ?? this.updatedAt,
      encryption: encryption ?? this.encryption,
      kdf: kdf ?? this.kdf,
      wrappedKeys: wrappedKeys ?? this.wrappedKeys,
      chunking: chunking ?? this.chunking,
      extraFields: extraFields ?? this.extraFields,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VaultHeader &&
          runtimeType == other.runtimeType &&
          format == other.format &&
          formatVersion == other.formatVersion &&
          vaultId == other.vaultId &&
          vaultName == other.vaultName &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          encryption == other.encryption;

  @override
  int get hashCode => Object.hash(
    format,
    formatVersion,
    vaultId,
    vaultName,
    createdAt,
    updatedAt,
    encryption,
  );

  @override
  String toString() => 'VaultHeader($vaultId, "$vaultName", enc: $encryption)';
}
