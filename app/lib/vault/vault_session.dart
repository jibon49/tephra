// © 2026 Tephra. All rights reserved.

import 'package:flutter/foundation.dart';
import 'package:tephra/settings/vault_settings.dart';
import 'package:tephra_vault/tephra_vault.dart';

/// Active open session representing an opened vault.
@immutable
final class VaultSession {
  const VaultSession({
    required this.vaultId,
    required this.rootDir,
    required this.name,
    required this.fs,
    required this.settings,
    this.isAppPrivate = false,
  });

  /// Unique identifier of this vault (from `.tephra/vault.json`).
  final String vaultId;

  /// Absolute root directory on disk (or memory path).
  final String rootDir;

  /// Human-readable vault name (e.g. folder basename).
  final String name;

  /// Active file system implementation for this vault.
  final VaultFileSystem fs;

  /// Snapshot of vault settings at open time (live values come from vaultSettingsProvider).
  final VaultSettings settings;

  /// True if Android vault is located in app-private storage instead of shared storage.
  final bool isAppPrivate;

  VaultSession copyWith({
    String? vaultId,
    String? rootDir,
    String? name,
    VaultFileSystem? fs,
    VaultSettings? settings,
    bool? isAppPrivate,
  }) {
    return VaultSession(
      vaultId: vaultId ?? this.vaultId,
      rootDir: rootDir ?? this.rootDir,
      name: name ?? this.name,
      fs: fs ?? this.fs,
      settings: settings ?? this.settings,
      isAppPrivate: isAppPrivate ?? this.isAppPrivate,
    );
  }
}
