// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

import '../merge/merge_kind.dart';
import '../model/journal_entry.dart';

bool _listEquals(List<String>? a, List<String>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Abstract base class for all synchronization actions planned by the engine.
sealed class SyncAction {
  const SyncAction(this.path);

  /// Vault-relative path targeted by this action.
  final VaultPath path;

  /// Execution phase index for deterministic ordering:
  /// 1. RenameLocal, 2. DeleteLocal, 3. Download, 4. Merge,
  /// 5. ConflictCopy, 6. Upload, 7. RenameRemote, 8. DeleteRemote.
  int get phase;
}

/// Publishes local file content at [path] as a remote journal 'put' entry.
final class Upload extends SyncAction {
  const Upload(
    super.path, {
    required this.localHash,
    this.parent,
    this.mergedParent,
    this.reuseBlobKeys,
  });

  final String localHash;
  final String? parent;
  final String? mergedParent;
  final List<String>? reuseBlobKeys;

  @override
  int get phase => 6;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Upload &&
          path == other.path &&
          localHash == other.localHash &&
          parent == other.parent &&
          mergedParent == other.mergedParent &&
          _listEquals(reuseBlobKeys, other.reuseBlobKeys);

  @override
  int get hashCode => Object.hash(
    path,
    localHash,
    parent,
    mergedParent,
    reuseBlobKeys == null ? null : Object.hashAll(reuseBlobKeys!),
  );

  @override
  String toString() =>
      'Upload(${path.value}, hash: $localHash, parent: $parent, merged: $mergedParent)';
}

/// Downloads and replaces/creates local file with remote content from [entry].
final class Download extends SyncAction {
  const Download(super.path, {required this.entry, this.expectedLocalHash});

  final JournalEntry entry;
  final String? expectedLocalHash;

  @override
  int get phase => 3;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Download &&
          path == other.path &&
          entry == other.entry &&
          expectedLocalHash == other.expectedLocalHash;

  @override
  int get hashCode => Object.hash(path, entry, expectedLocalHash);

  @override
  String toString() =>
      'Download(${path.value}, entry: ${entry.id}, expected: $expectedLocalHash)';
}

/// Performs a three-way merge, writes the result locally and uploads it.
final class Merge extends SyncAction {
  const Merge(
    super.path, {
    required this.kind,
    required this.localHash,
    required this.remote,
    required this.basePath,
    this.baseEntryId,
    this.mergedParent,
  });

  final MergeKind kind;
  final String localHash;
  final JournalEntry remote;
  final VaultPath basePath;
  final String? baseEntryId;
  final String? mergedParent;

  @override
  int get phase => 4;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Merge &&
          path == other.path &&
          kind == other.kind &&
          localHash == other.localHash &&
          remote == other.remote &&
          basePath == other.basePath &&
          baseEntryId == other.baseEntryId &&
          mergedParent == other.mergedParent;

  @override
  int get hashCode => Object.hash(
    path,
    kind,
    localHash,
    remote,
    basePath,
    baseEntryId,
    mergedParent,
  );

  @override
  String toString() =>
      'Merge(${path.value}, kind: $kind, remote: ${remote.id}, baseEntry: $baseEntryId)';
}

/// Preserves both versions: local content is saved to a conflict copy,
/// and remote content is written to [path].
final class ConflictCopy extends SyncAction {
  const ConflictCopy(
    super.path, {
    required this.localHash,
    required this.remote,
    this.mergedParent,
  });

  final String localHash;
  final JournalEntry remote;
  final String? mergedParent;

  @override
  int get phase => 5;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConflictCopy &&
          path == other.path &&
          localHash == other.localHash &&
          remote == other.remote &&
          mergedParent == other.mergedParent;

  @override
  int get hashCode => Object.hash(path, localHash, remote, mergedParent);

  @override
  String toString() =>
      'ConflictCopy(${path.value}, remote: ${remote.id}, merged: $mergedParent)';
}

/// Moves local file at [path] to vault trash.
final class DeleteLocal extends SyncAction {
  const DeleteLocal(
    super.path, {
    required this.expectedHash,
    required this.remoteEntryId,
  });

  final String expectedHash;
  final String remoteEntryId;

  @override
  int get phase => 2;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeleteLocal &&
          path == other.path &&
          expectedHash == other.expectedHash &&
          remoteEntryId == other.remoteEntryId;

  @override
  int get hashCode => Object.hash(path, expectedHash, remoteEntryId);

  @override
  String toString() =>
      'DeleteLocal(${path.value}, expected: $expectedHash, remote: $remoteEntryId)';
}

/// Publishes a remote deletion journal entry for [path].
final class DeleteRemote extends SyncAction {
  const DeleteRemote(
    super.path, {
    required this.parent,
    required this.hash,
    required this.blobKeys,
  });

  final String parent;
  final String hash;
  final List<String> blobKeys;

  @override
  int get phase => 8;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeleteRemote &&
          path == other.path &&
          parent == other.parent &&
          hash == other.hash &&
          _listEquals(blobKeys, other.blobKeys);

  @override
  int get hashCode => Object.hash(path, parent, hash, Object.hashAll(blobKeys));

  @override
  String toString() =>
      'DeleteRemote(${path.value}, parent: $parent, hash: $hash)';
}

/// Renames a local file from [path] to [to].
final class RenameLocal extends SyncAction {
  const RenameLocal(
    super.path, {
    required this.to,
    required this.expectedHash,
    required this.remoteEntryId,
  });

  final VaultPath to;
  final String expectedHash;
  final String remoteEntryId;

  @override
  int get phase => 1;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RenameLocal &&
          path == other.path &&
          to == other.to &&
          expectedHash == other.expectedHash &&
          remoteEntryId == other.remoteEntryId;

  @override
  int get hashCode => Object.hash(path, to, expectedHash, remoteEntryId);

  @override
  String toString() =>
      'RenameLocal(${path.value} -> ${to.value}, remote: $remoteEntryId)';
}

/// Publishes a remote move journal entry from [path] to [to].
final class RenameRemote extends SyncAction {
  const RenameRemote(
    super.path, {
    required this.to,
    required this.parent,
    this.targetParent,
    required this.hash,
    required this.blobKeys,
  });

  final VaultPath to;
  final String parent;
  final String? targetParent;
  final String hash;
  final List<String> blobKeys;

  @override
  int get phase => 7;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RenameRemote &&
          path == other.path &&
          to == other.to &&
          parent == other.parent &&
          targetParent == other.targetParent &&
          hash == other.hash &&
          _listEquals(blobKeys, other.blobKeys);

  @override
  int get hashCode => Object.hash(
    path,
    to,
    parent,
    targetParent,
    hash,
    Object.hashAll(blobKeys),
  );

  @override
  String toString() =>
      'RenameRemote(${path.value} -> ${to.value}, parent: $parent, targetParent: $targetParent)';
}
