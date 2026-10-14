// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

import 'text_document.dart';
import 'trash_mode.dart';
import 'vault_change.dart';
import 'vault_entry.dart';

/// The core abstract file-system interface for vault operations.
abstract interface class VaultFileSystem {
  /// Display path for UI representations only.
  String get rootDisplayPath;

  /// Lists entries in [folder].
  ///
  /// Returns entries sorted by `path.value` (code-unit order), excludes ignored
  /// paths, and skips (with a warning log) entries whose names are not valid [VaultPath]s.
  Future<List<VaultEntry>> list({
    VaultPath folder = VaultPath.root,
    bool recursive = true,
  });

  /// Returns metadata for [path], or `null` if it does not exist.
  Future<VaultEntry?> stat(VaultPath path);

  /// Reads raw bytes for [path].
  ///
  /// Throws [FileNotFoundException] if missing.
  Future<List<int>> readBytes(VaultPath path);

  /// Reads and decodes text for [path].
  ///
  /// Throws [FileNotFoundException] if missing.
  Future<TextDocument> readText(VaultPath path);

  /// Writes [bytes] atomically to [path], creating parent directories as needed.
  Future<void> writeBytes(VaultPath path, List<int> bytes);

  /// Writes [doc] atomically to [path], creating parent directories as needed.
  ///
  /// Throws [PermissionDeniedException] if [doc.malformed] is true.
  Future<void> writeText(VaultPath path, TextDocument doc);

  /// Creates folder at [path] and any missing parent directories.
  Future<void> createFolder(VaultPath path);

  /// Moves or renames entry from [from] to [to].
  ///
  /// Throws [FileConflictException] if [to] exists (except case-only rename of
  /// the same entry) and creates missing parent folders of [to].
  Future<void> move(VaultPath from, VaultPath to);

  /// Deletes [path] according to [mode]. Deleting a missing path is a no-op.
  Future<void> delete(VaultPath path, {TrashMode mode = TrashMode.vaultTrash});

  /// Broadcast stream of filesystem changes.
  ///
  /// Debounced (~150 ms) and excludes our own writes.
  Stream<VaultChange> watch();

  /// Releases resources associated with this filesystem.
  Future<void> dispose();
}
