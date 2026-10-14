// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../l10n/app_localizations.dart';
import '../settings/providers.dart';
import '../vault/providers.dart';
import '../workspace/providers.dart';
import 'providers.dart';
import 'reveal_in_system_explorer.dart';

extension on VaultFileSystem {
  Future<bool> exists(VaultPath path) async => (await stat(path)) != null;
}

/// Provides vault file operations for the file explorer.
final class ExplorerService {
  ExplorerService(this.ref);

  final Ref ref;

  /// Creates an untitled note in [folder], selects and opens it, and starts inline rename.
  Future<VaultPath> createNote(VaultPath folder) async {
    final noteCreator = ref.read(noteCreatorProvider);
    final notePath = await noteCreator.createUntitled(folder: folder);
    if (!folder.isRoot) {
      ref.read(explorerExpandedProvider.notifier).expand(folder);
    }
    ref.read(explorerSelectedProvider.notifier).select(notePath);
    ref.read(workspaceProvider.notifier).openPath(notePath);
    ref.read(explorerRenamingProvider.notifier).start(notePath);
    return notePath;
  }

  /// Creates a new folder with the first free `Untitled folder` name under [parent],
  /// selects it, and starts inline rename.
  Future<VaultPath> createFolder(VaultPath parent) async {
    final fs = ref.read(vaultFsProvider);
    var index = 0;
    VaultPath candidate;
    while (true) {
      final name = index == 0 ? 'Untitled folder' : 'Untitled folder $index';
      candidate = parent.isRoot ? VaultPath(name) : parent.join(name);
      if (!await fs.exists(candidate)) {
        break;
      }
      index++;
    }

    await fs.createFolder(candidate);
    if (!parent.isRoot) {
      ref.read(explorerExpandedProvider.notifier).expand(parent);
    }
    ref.read(explorerSelectedProvider.notifier).select(candidate);
    ref.read(explorerRenamingProvider.notifier).start(candidate);
    ref.read(vaultRevisionProvider.notifier).bump();
    return candidate;
  }

  /// Renames [from] to [newName].
  Future<VaultPath> rename(
    VaultPath from,
    String newName, {
    BuildContext? context,
  }) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) {
      throw const InvalidPathException('empty');
    }

    final fs = ref.read(vaultFsProvider);
    final stat = await fs.stat(from);
    if (stat == null) {
      throw FileNotFoundException(from);
    }
    final isFolder = stat.isFolder;

    final String finalName;
    if (isFolder) {
      finalName = trimmed;
    } else {
      final ext = from.extension;
      if (ext.isNotEmpty &&
          trimmed.toLowerCase().endsWith('.${ext.toLowerCase()}')) {
        finalName = trimmed;
      } else if (ext.isNotEmpty) {
        finalName = '$trimmed.$ext';
      } else {
        finalName = trimmed;
      }
    }

    final nameErr = VaultPath.checkName(finalName);
    if (nameErr != null) {
      throw InvalidPathException(nameErr);
    }
    final to = from.withName(finalName);
    if (to == from) return from;

    if (await fs.exists(to) && to.caseKey != from.caseKey) {
      throw FileConflictException(to);
    }

    final store = ref.read(noteDocumentStoreProvider);
    await store.flushPath(from);
    await fs.move(from, to);
    store.retargetPath(from, to);
    ref.read(workspaceProvider.notifier).retargetPath(from, to);
    ref.read(explorerExpandedProvider.notifier).retarget(from, to);
    ref.read(explorerSelectedProvider.notifier).select(to);
    ref.read(vaultRevisionProvider.notifier).bump();
    _showNotice(from.name);
    return to;
  }

  /// Moves [from] into [targetFolder].
  Future<VaultPath> move(
    VaultPath from,
    VaultPath targetFolder, {
    BuildContext? context,
  }) async {
    if (targetFolder == from.parent ||
        targetFolder == from ||
        targetFolder.isWithin(from)) {
      throw StateError('Cannot move $from to $targetFolder');
    }

    final to = targetFolder.isRoot
        ? VaultPath(from.name)
        : targetFolder.join(from.name);
    final fs = ref.read(vaultFsProvider);
    if (await fs.exists(to)) {
      throw FileConflictException(to);
    }

    final store = ref.read(noteDocumentStoreProvider);
    await store.flushPath(from);
    await fs.move(from, to);
    store.retargetPath(from, to);
    ref.read(workspaceProvider.notifier).retargetPath(from, to);
    ref.read(explorerExpandedProvider.notifier).retarget(from, to);
    ref.read(explorerSelectedProvider.notifier).select(to);
    ref.read(vaultRevisionProvider.notifier).bump();
    _showNotice(from.name);
    return to;
  }

  /// Deletes [path] according to vault trash settings.
  Future<void> delete(VaultPath path) async {
    final fs = ref.read(vaultFsProvider);
    final settings = ref.read(vaultSettingsProvider);
    final mode = settings.trashModeEnum;

    await fs.delete(path, mode: mode);
    ref.read(noteDocumentStoreProvider).discardPath(path);
    ref.read(workspaceProvider.notifier).removePath(path);
    if (ref.read(explorerSelectedProvider) == path) {
      ref.read(explorerSelectedProvider.notifier).select(null);
    }
    ref.read(vaultRevisionProvider.notifier).bump();
  }

  /// Duplicates file at [path] with a free `<stem> <index>.<ext>` name.
  Future<VaultPath> duplicate(VaultPath path) async {
    final fs = ref.read(vaultFsProvider);
    final stat = await fs.stat(path);
    if (stat == null) {
      throw FileNotFoundException(path);
    }
    if (stat.isFolder) {
      throw StateError('Cannot duplicate a folder');
    }

    final ext = path.extension;
    final stem = path.stem;
    var index = 1;
    VaultPath dupPath;
    final parent = path.parent;
    while (true) {
      final name = ext.isNotEmpty ? '$stem $index.$ext' : '$stem $index';
      dupPath = (parent == null || parent.isRoot)
          ? VaultPath(name)
          : parent.join(name);
      if (!await fs.exists(dupPath)) {
        break;
      }
      index++;
    }

    final bytes = await fs.readBytes(path);
    await fs.writeBytes(dupPath, bytes);
    ref.read(vaultRevisionProvider.notifier).bump();
    ref.read(explorerSelectedProvider.notifier).select(dupPath);
    ref.read(explorerRenamingProvider.notifier).start(dupPath);
    return dupPath;
  }

  /// Reveals [path] in the Windows File Explorer.
  Future<void> reveal(VaultPath path) async {
    final session = ref.read(vaultSessionProvider);
    if (session == null) return;
    final absPath = p.join(session.rootDir, path.value);
    await revealInSystemExplorer(absPath);
  }

  void _showNotice(String name) {
    try {
      final key = ref.read(scaffoldMessengerKeyProvider);
      final context = key.currentContext;
      final message = context != null
          ? AppLocalizations.of(context).explorerLinksNotUpdatedNotice(name)
          : 'Links to “$name” were not updated. Automatic link updates arrive in a later version.';
      key.currentState?.showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
      );
    } catch (_) {
      // Ignore if binding/context not available in non-UI unit tests.
    }
  }
}
