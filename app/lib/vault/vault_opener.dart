// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:tephra/core/providers.dart';
import 'package:tephra/settings/vault_settings.dart';
import 'package:tephra/settings/vault_settings_store.dart';
import 'package:tephra/vault/obsidian_importer.dart';
import 'package:tephra/vault/providers.dart';
import 'package:tephra/vault/vault_file_system_factory.dart';
import 'package:tephra/vault/vault_metadata.dart';
import 'package:tephra/vault/vault_session.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

/// Thrown when opening a vault folder fails.
final class VaultOpenException extends TephraException {
  const VaultOpenException(this.code) : super('Vault open failed: $code');

  final String code;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VaultOpenException && code == other.code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => 'VaultOpenException($code)';
}

/// Validates, bootstraps metadata, runs initial settings import, and opens a vault session.
final class VaultOpener {
  VaultOpener(this.ref);

  final Ref ref;

  Future<VaultSession> open(String rootDir, {bool isAppPrivate = false}) async {
    final dir = Directory(rootDir);
    if (!dir.existsSync()) {
      if (File(rootDir).existsSync()) {
        throw const VaultOpenException('not-a-folder');
      }
      throw const VaultOpenException('missing');
    }

    try {
      await dir.list().first;
    } on FileSystemException {
      throw const VaultOpenException('no-access');
    } on StateError {
      // Empty directory throws StateError (No element) when calling .first; expected.
    } catch (e) {
      if (e is VaultOpenException) rethrow;
      throw const VaultOpenException('no-access');
    }

    final systemTrash = ref.read(systemTrashProvider);
    final settingsFs = createVaultFileSystem(
      rootDir,
      const VaultSettings(),
      systemTrash: systemTrash,
    );

    final clock = ref.read(clockProvider);
    final VaultMetadata meta;
    try {
      meta = await ensureVaultMetadata(settingsFs, clock);
    } on VaultTooNewException {
      await settingsFs.dispose();
      throw const VaultOpenException('too-new');
    } catch (_) {
      await settingsFs.dispose();
      rethrow;
    }

    final settingsStat = await settingsFs.stat(
      VaultPath('.tephra/settings.json'),
    );
    if (settingsStat == null) {
      await ObsidianImporter(settingsFs, clock).run();
    }

    final settings = await VaultSettingsStore(settingsFs).load();
    final VaultFileSystem fs;
    if (settings.showHidden) {
      await settingsFs.dispose();
      fs = createVaultFileSystem(rootDir, settings, systemTrash: systemTrash);
    } else {
      fs = settingsFs;
    }

    final name = p.basename(rootDir);
    final session = VaultSession(
      vaultId: meta.id,
      rootDir: rootDir,
      name: name,
      fs: fs,
      settings: settings,
      isAppPrivate: isAppPrivate,
    );

    await ref.read(vaultSessionProvider.notifier).set(session);
    ref.read(appSettingsProvider.notifier).addRecentVault(rootDir, name);
    ref
        .read(appSettingsProvider.notifier)
        .update((s) => s.copyWith(lastVaultPath: () => rootDir));

    if (fs is IoVaultFileSystem) {
      unawaited(fs.cleanStaleTemps());
    }

    final hooks = ref.read(vaultOpenedHooksProvider);
    for (final hook in hooks) {
      await hook(ref);
    }

    return session;
  }
}

final vaultOpenerProvider = Provider<VaultOpener>(VaultOpener.new);
