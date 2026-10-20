// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../blobs/blob_store.dart';
import '../remote/remote_history.dart';
import 'local_history.dart';

/// Origin of a historical version.
enum VersionOrigin {
  /// Local snapshot captured on this device.
  local,

  /// Version synced through remote journals and blobs.
  remote,
}

/// Sealed reference to a specific version payload.
sealed class VersionRef {
  const VersionRef();
}

/// Reference to a local gzipped snapshot in `.tephra/history/`.
final class LocalVersionRef extends VersionRef {
  const LocalVersionRef(this.path);

  /// Vault path to the snapshot file.
  final String path;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalVersionRef &&
          runtimeType == other.runtimeType &&
          path == other.path;

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() => 'LocalVersionRef($path)';
}

/// Reference to a remote version defined by journal mutations and content blobs.
final class RemoteVersionRef extends VersionRef {
  const RemoteVersionRef({
    required this.entryId,
    required this.blobKeys,
    this.hash,
  });

  /// Unique journal entry id (`<deviceId>:<seq>`).
  final String entryId;

  /// Ordered blob keys composing the file content.
  final List<String> blobKeys;

  /// SHA-256 hash of plaintext content.
  final String? hash;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RemoteVersionRef &&
          runtimeType == other.runtimeType &&
          entryId == other.entryId;

  @override
  int get hashCode => entryId.hashCode;

  @override
  String toString() => 'RemoteVersionRef($entryId)';
}

/// Metadata describing a historical version of a note or file.
final class VersionInfo {
  const VersionInfo({
    required this.ref,
    required this.time,
    required this.source,
    this.size,
    this.hash,
    required this.origin,
    this.isAvailable = true,
    this.additionalSources = const [],
  });

  /// Reference handle used to load the version payload.
  final VersionRef ref;

  /// Timestamp when this version was created.
  final DateTime time;

  /// Originating device name or 'Local snapshot'.
  final String source;

  /// Uncompressed file size in bytes.
  final int? size;

  /// SHA-256 hash of plaintext content.
  final String? hash;

  /// Local vs remote origin.
  final VersionOrigin origin;

  /// True if content can currently be retrieved (not garbage collected).
  final bool isAvailable;

  /// Additional devices or sources that authored/shared this identical content.
  final List<String> additionalSources;

  VersionInfo copyWith({
    VersionRef? ref,
    DateTime? time,
    String? source,
    int? size,
    String? hash,
    VersionOrigin? origin,
    bool? isAvailable,
    List<String>? additionalSources,
  }) {
    return VersionInfo(
      ref: ref ?? this.ref,
      time: time ?? this.time,
      source: source ?? this.source,
      size: size ?? this.size,
      hash: hash ?? this.hash,
      origin: origin ?? this.origin,
      isAvailable: isAvailable ?? this.isAvailable,
      additionalSources: additionalSources ?? this.additionalSources,
    );
  }

  @override
  String toString() =>
      'VersionInfo($source, time: $time, hash: $hash, size: $size, available: $isAvailable)';
}

/// Source location where a deleted file was detected.
enum RecentlyDeletedSource {
  /// Remote path whose current head is a delete within retention.
  remote,

  /// File stored in the local `.trash/` folder.
  vaultTrash,
}

/// Describes a recently deleted file available for restoration.
final class RecentlyDeletedFile {
  const RecentlyDeletedFile({
    required this.path,
    required this.deletedTime,
    required this.deletingDevice,
    required this.source,
    this.newestVersion,
  });

  /// Vault path where the file was located before deletion.
  final VaultPath path;

  /// Time when the file was deleted.
  final DateTime deletedTime;

  /// Name of device that deleted the file (or 'This device').
  final String deletingDevice;

  /// Source (remote journal or local vault trash).
  final RecentlyDeletedSource source;

  /// The newest available historical version of the file prior to deletion.
  final VersionInfo? newestVersion;

  @override
  String toString() =>
      'RecentlyDeletedFile($path, deleted: $deletedTime by $deletingDevice)';
}

/// Service that coordinates browsing, loading, and restoring version histories
/// across local snapshots and remote journals.
final class VersionHistory {
  VersionHistory({
    required this.localHistory,
    required this.remoteHistory,
    this.blobStore,
    this.deviceNames = const {},
  });

  final LocalHistory localHistory;
  final RemoteHistory remoteHistory;
  final BlobStore? blobStore;
  final Map<String, String> deviceNames;

  /// Retrieves all versions touching [path], merging local snapshots and remote
  /// journal entries, sorted newest first and de-duplicated by hash.
  Future<List<VersionInfo>> versions(
    VaultPath path, {
    Set<String>? availableBlobKeys,
  }) async {
    final candidates = <VersionInfo>[];

    // 1. Local snapshots
    final snapshotRefs = await localHistory.list(path);
    for (final ref in snapshotRefs) {
      final time = LocalHistory.parseTimestamp(ref) ?? DateTime.now().toUtc();
      final bytes = await localHistory.read(ref);
      if (bytes != null) {
        candidates.add(
          VersionInfo(
            ref: LocalVersionRef(ref),
            time: time,
            source: 'Local snapshot',
            size: bytes.length,
            hash: contentHash(bytes),
            origin: VersionOrigin.local,
            isAvailable: true,
          ),
        );
      }
    }

    // 2. Remote entries
    final remoteEntries = remoteHistory.versions(path.value);
    for (final entry in remoteEntries) {
      // Only include operations that carry file content
      if (entry.op != 'put' &&
          !(entry.op == 'move' && entry.path == path.value)) {
        continue;
      }

      final time = DateTime.fromMillisecondsSinceEpoch(entry.time, isUtc: true);
      final devName = deviceNames[entry.deviceId] ?? entry.deviceId;

      var available = true;
      if (availableBlobKeys != null &&
          entry.blobKeys != null &&
          entry.blobKeys!.isNotEmpty) {
        available = entry.blobKeys!.every(availableBlobKeys.contains);
      }

      candidates.add(
        VersionInfo(
          ref: RemoteVersionRef(
            entryId: entry.entryId,
            blobKeys: entry.blobKeys ?? const [],
            hash: entry.hash,
          ),
          time: time,
          source: devName,
          size: entry.size,
          hash: entry.hash,
          origin: VersionOrigin.remote,
          isAvailable: available,
        ),
      );
    }

    // 3. Sort newest first
    candidates.sort((a, b) => b.time.compareTo(a.time));

    // 4. De-duplicate by hash (keep newest occurrence, record other sources)
    final result = <VersionInfo>[];
    final seenHashes = <String, VersionInfo>{};

    for (final candidate in candidates) {
      final h = candidate.hash;
      if (h == null) {
        result.add(candidate);
        continue;
      }

      if (seenHashes.containsKey(h)) {
        final existing = seenHashes[h]!;
        final sources = List<String>.from(existing.additionalSources);
        if (!sources.contains(candidate.source) &&
            candidate.source != existing.source) {
          sources.add(candidate.source);
        }
        final idx = result.indexOf(existing);
        if (idx != -1) {
          final updated = existing.copyWith(additionalSources: sources);
          result[idx] = updated;
          seenHashes[h] = updated;
        }
      } else {
        result.add(candidate);
        seenHashes[h] = candidate;
      }
    }

    return result;
  }

  /// Reads the uncompressed bytes for [version].
  Future<List<int>?> readVersion(VersionInfo version) async {
    if (version.origin == VersionOrigin.local) {
      final ref = version.ref as LocalVersionRef;
      return localHistory.read(ref.path);
    } else {
      final ref = version.ref as RemoteVersionRef;
      if (blobStore == null) return null;
      if (ref.blobKeys.isEmpty) return const <int>[];
      try {
        return await blobStore!.getFile(
          ref.blobKeys,
          expectedPlainHash: ref.hash ?? version.hash ?? '',
        );
      } catch (_) {
        return null;
      }
    }
  }

  /// Restores [version] for [path].
  ///
  /// Snapshots current file with [SnapshotReason.beforeRestore] first.
  /// Writes the restored content as a new normal vault edit (synced like any edit, never destructive).
  Future<void> restoreVersion({
    required VersionInfo version,
    required VaultPath path,
    required VaultFileSystem fs,
  }) async {
    final bytes = await readVersion(version);
    if (bytes == null) {
      throw StateError('Version content is unavailable for ${path.value}');
    }

    // Snapshot current file if present
    final currentStat = await fs.stat(path);
    if (currentStat != null) {
      final currentBytes = await fs.readBytes(path);
      await localHistory.snapshot(
        path,
        currentBytes,
        reason: SnapshotReason.beforeRestore,
      );
    }

    // Write as new edit
    await fs.writeBytes(path, bytes);
  }

  /// Generates a non-colliding restore path: `<stem> (restored YYYY-MM-DD).<ext>` if [path] is taken.
  static Future<VaultPath> resolveRestorePath(
    VaultFileSystem fs,
    VaultPath path, {
    DateTime? now,
  }) async {
    final stat = await fs.stat(path);
    if (stat == null) {
      return path;
    }

    final n = (now ?? DateTime.now()).toUtc();
    final y = n.year.toString().padLeft(4, '0');
    final m = n.month.toString().padLeft(2, '0');
    final d = n.day.toString().padLeft(2, '0');
    final dateStr = '$y-$m-$d';

    final stem = path.stem;
    final ext = path.extension;
    final parent = path.parent;

    String candidateName;
    if (ext.isNotEmpty) {
      candidateName = '$stem (restored $dateStr).$ext';
    } else {
      candidateName = '$stem (restored $dateStr)';
    }

    var candidatePath = parent != null
        ? parent.join(candidateName)
        : VaultPath(candidateName);
    var candidateStat = await fs.stat(candidatePath);
    var counter = 1;

    while (candidateStat != null) {
      if (ext.isNotEmpty) {
        candidateName = '$stem (restored $dateStr $counter).$ext';
      } else {
        candidateName = '$stem (restored $dateStr $counter)';
      }
      candidatePath = parent != null
          ? parent.join(candidateName)
          : VaultPath(candidateName);
      candidateStat = await fs.stat(candidatePath);
      counter++;
    }

    return candidatePath;
  }

  /// Retrieves all recently deleted files from both (a) remote delete heads within retention
  /// (365 days) and (b) files in the vault `.trash/` folder.
  Future<List<RecentlyDeletedFile>> recentlyDeleted({
    required VaultFileSystem fs,
    DateTime? now,
  }) async {
    final nowUtc = (now ?? DateTime.now()).toUtc();
    final results = <String, RecentlyDeletedFile>{};

    // (a) Remote paths whose head is a delete within retention
    for (final pathStr in remoteHistory.allPaths) {
      final head = remoteHistory.head(pathStr);
      if (head != null && head.op == 'delete') {
        final delTime = DateTime.fromMillisecondsSinceEpoch(
          head.time,
          isUtc: true,
        );
        final age = nowUtc.difference(delTime);
        if (age <= const Duration(days: 365)) {
          final devName = deviceNames[head.deviceId] ?? head.deviceId;
          final vp = VaultPath(pathStr);
          final allVersions = await versions(vp);
          final newest = allVersions.isNotEmpty ? allVersions.first : null;

          results[pathStr] = RecentlyDeletedFile(
            path: vp,
            deletedTime: delTime,
            deletingDevice: devName,
            source: RecentlyDeletedSource.remote,
            newestVersion: newest,
          );
        }
      }
    }

    // (b) Local vault .trash/ folder
    final trashFolder = VaultPath('.trash');
    final stat = await fs.stat(trashFolder);
    if (stat != null) {
      final entries = await fs.list(folder: trashFolder, recursive: true);
      for (final e in entries) {
        if (!e.isFolder) {
          final relPath = e.path.value.substring('.trash/'.length);
          final vp = VaultPath(relPath);
          final delTime = e.modified.toUtc();

          final existing = results[relPath];
          if (existing == null || delTime.isAfter(existing.deletedTime)) {
            results[relPath] = RecentlyDeletedFile(
              path: vp,
              deletedTime: delTime,
              deletingDevice: 'This device',
              source: RecentlyDeletedSource.vaultTrash,
              newestVersion: existing?.newestVersion,
            );
          }
        }
      }
    }

    final list = results.values.toList();
    list.sort((a, b) => b.deletedTime.compareTo(a.deletedTime));
    return list;
  }

  /// Restores [deleted] file.
  ///
  /// Restores to its original path or `<stem> (restored YYYY-MM-DD).<ext>` if taken.
  /// Snapshots the target path if currently occupied prior to restoration.
  /// Returns the target [VaultPath] the file was restored to.
  Future<VaultPath> restoreDeletedFile({
    required RecentlyDeletedFile deleted,
    required VaultFileSystem fs,
    DateTime? now,
  }) async {
    final targetPath = await resolveRestorePath(fs, deleted.path, now: now);

    final existingStat = await fs.stat(targetPath);
    if (existingStat != null) {
      final existingBytes = await fs.readBytes(targetPath);
      await localHistory.snapshot(
        targetPath,
        existingBytes,
        reason: SnapshotReason.beforeRestore,
      );
    }

    if (deleted.source == RecentlyDeletedSource.vaultTrash) {
      final trashPath = VaultPath('.trash/${deleted.path.value}');
      final trashStat = await fs.stat(trashPath);
      if (trashStat != null) {
        final bytes = await fs.readBytes(trashPath);
        await fs.writeBytes(targetPath, bytes);
        await fs.delete(trashPath, mode: TrashMode.permanent);
        return targetPath;
      }
    }

    if (deleted.newestVersion != null) {
      final bytes = await readVersion(deleted.newestVersion!);
      if (bytes != null) {
        await fs.writeBytes(targetPath, bytes);
        return targetPath;
      }
    }

    throw StateError(
      'Cannot restore ${deleted.path.value}: content unavailable',
    );
  }
}
