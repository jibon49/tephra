// © 2026 Tephra. All rights reserved.

import 'dart:math';

import 'package:tephra/core/json_file_store.dart';
import 'package:tephra/core/uuid.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

/// Thrown when the vault's format version is higher than supported.
final class VaultTooNewException extends TephraException {
  const VaultTooNewException(this.version)
    : super('Vault format version $version is too new');

  final int version;
}

/// Identifies a vault and records when it was initialized by Tephra.
final class VaultMetadata {
  const VaultMetadata({
    required this.id,
    required this.createdAt,
    this.formatVersion = 1,
  });

  final String id;
  final DateTime createdAt;
  final int formatVersion;
}

/// Reads or initializes `.tephra/vault.json`.
Future<VaultMetadata> ensureVaultMetadata(
  VaultFileSystem fs,
  Clock clock, {
  Random? random,
}) async {
  const store = TephraJsonStore();
  final path = VaultPath('.tephra/vault.json');

  final map = await store.readMap(fs, path);

  final rawVersion = map['formatVersion'];
  final formatVersion = rawVersion is int ? rawVersion : 1;
  if (formatVersion > 1) {
    throw VaultTooNewException(formatVersion);
  }

  final rawId = map['id'];
  final rawCreatedAt = map['createdAt'];

  if (map.isEmpty || rawId is! String || rawId.isEmpty) {
    final newId = rawId is String && rawId.isNotEmpty
        ? rawId
        : generateUuidV4(random);
    final now = clock.now().toUtc();
    final createdAtStr = rawCreatedAt is String && rawCreatedAt.isNotEmpty
        ? rawCreatedAt
        : now.toIso8601String();
    final createdAt = DateTime.tryParse(createdAtStr) ?? now;

    final updated = Map<String, Object?>.from(map);
    updated['id'] = newId;
    updated['createdAt'] = createdAtStr;
    updated['formatVersion'] = formatVersion;

    await store.writeMap(fs, path, updated);
    return VaultMetadata(
      id: newId,
      createdAt: createdAt,
      formatVersion: formatVersion,
    );
  }

  final createdAt = rawCreatedAt is String
      ? DateTime.tryParse(rawCreatedAt) ?? clock.now().toUtc()
      : clock.now().toUtc();

  return VaultMetadata(
    id: rawId,
    createdAt: createdAt,
    formatVersion: formatVersion,
  );
}
