// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

import '../local/local_file_state.dart';
import '../merge/merge_kind.dart';
import '../model/base_state.dart';
import '../remote/remote_history.dart';
import 'base_update.dart';
import 'status_classifier.dart';
import 'sync_action.dart';

/// Output from running rename detection on local and remote states.
final class RenameDetectorResult {
  const RenameDetectorResult({
    required this.actions,
    required this.baseUpdates,
    required this.handledPaths,
  });

  final List<SyncAction> actions;
  final List<BaseUpdate> baseUpdates;
  final Set<VaultPath> handledPaths;
}

/// Detects and pairs file moves and renames before decision table classification.
abstract final class RenameDetector {
  /// Evaluates local and remote state to detect renames.
  static RenameDetectorResult detect({
    required Map<VaultPath, LocalFileState> local,
    required Map<VaultPath, BaseState> base,
    required RemoteHistory remote,
    Set<VaultPath> excludedPaths = const {},
  }) {
    final actions = <SyncAction>[];
    final baseUpdates = <BaseUpdate>[];
    final handled = <VaultPath>{...excludedPaths};

    // 1. Local moves
    // D = paths in state LD (base present, local absent)
    final dList = <VaultPath>[];
    for (final entry in base.entries) {
      final p = entry.key;
      if (!handled.contains(p) && !local.containsKey(p)) {
        dList.add(p);
      }
    }
    dList.sort((a, b) => a.value.compareTo(b.value));

    // C = paths in state LC (local present, base absent)
    final cList = <VaultPath>[];
    for (final entry in local.entries) {
      final p = entry.key;
      if (!handled.contains(p) && !base.containsKey(p)) {
        cList.add(p);
      }
    }
    cList.sort((a, b) => a.value.compareTo(b.value));

    final unpairedD = Set<VaultPath>.from(dList);

    for (final c in cList) {
      if (handled.contains(c)) continue;

      // Pair only if remote at c is R0
      final rc = StatusClassifier.classifyRemote(c, base[c], remote);
      if (rc != RemoteStatus.r0) continue;

      final lcHash = local[c]!.hash;

      // Find candidates in unpairedD with matching hash
      final candidates = unpairedD
          .where((d) => base[d]!.hash == lcHash)
          .toList();
      if (candidates.isEmpty) continue;

      // Sort candidates by preference
      candidates.sort((d1, d2) => _compareCandidates(d1, d2, c));
      final d = candidates.first;

      final rd = StatusClassifier.classifyRemote(d, base[d], remote);
      final hd = remote.head(d.value);

      if (rd == RemoteStatus.rEq) {
        final blobKeys =
            (hd != null &&
                hd.hash == base[d]!.hash &&
                hd.blobKeys != null &&
                hd.blobKeys!.isNotEmpty)
            ? hd.blobKeys!
            : base[d]!.blobKeys;
        actions.add(
          RenameRemote(
            d,
            to: c,
            parent: hd!.entryId,
            targetParent: remote.head(c.value)?.entryId,
            hash: base[d]!.hash,
            blobKeys: blobKeys,
          ),
        );
        handled.add(d);
        handled.add(c);
        unpairedD.remove(d);
      } else if (rd == RemoteStatus.rMod) {
        actions.add(Download(c, entry: hd!, expectedLocalHash: local[c]!.hash));
        actions.add(
          RenameRemote(
            d,
            to: c,
            parent: hd.entryId,
            targetParent: remote.head(c.value)?.entryId,
            hash: hd.hash ?? '',
            blobKeys: hd.blobKeys ?? const [],
          ),
        );
        handled.add(d);
        handled.add(c);
        unpairedD.remove(d);
      } else if (hd != null && hd.op == 'move' && hd.fromPath == d.value) {
        final x = hd.path;
        if (x == c.value) {
          // Both devices performed the same move
          baseUpdates.add(BaseUpdate.remove(d));
          baseUpdates.add(
            BaseUpdate.fromEntry(
              c,
              hd,
              size: local[c]!.size,
              mtime: local[c]!.mtimeMs,
            ),
          );
          handled.add(d);
          handled.add(c);
          unpairedD.remove(d);
        } else if (!local.containsKey(VaultPath.raw(x))) {
          final hx = remote.head(x);
          if (hx != null &&
              RemoteHistory.isPresentAt(hx, x) &&
              hx.hash == local[c]!.hash) {
            // Remote location wins; same content
            actions.add(
              RenameLocal(
                c,
                to: VaultPath.raw(x),
                expectedHash: local[c]!.hash,
                remoteEntryId: hx.entryId,
              ),
            );
            baseUpdates.add(BaseUpdate.remove(d));
            handled.add(d);
            handled.add(c);
            handled.add(VaultPath.raw(x));
            unpairedD.remove(d);
          }
        }
      }
    }

    // 2. Remote moves
    final sortedRemotePaths = remote.allPaths.toList()..sort();
    for (final tStr in sortedRemotePaths) {
      final target = VaultPath.raw(tStr);
      final h = remote.head(tStr);
      if (h != null && h.op == 'move' && h.path == tStr && h.fromPath != null) {
        final f = VaultPath.raw(h.fromPath!);
        if (handled.contains(f) || handled.contains(target)) continue;

        if (base.containsKey(f) &&
            !base.containsKey(target) &&
            !local.containsKey(target)) {
          final bf = base[f]!;
          final lf = local[f];

          if (lf != null) {
            final isLeq = lf.hash == bf.hash;
            final isLm = lf.hash != bf.hash;

            if (isLeq && h.hash == bf.hash) {
              actions.add(
                RenameLocal(
                  f,
                  to: target,
                  expectedHash: lf.hash,
                  remoteEntryId: h.entryId,
                ),
              );
              handled.add(f);
              handled.add(target);
            } else if (isLm) {
              actions.add(
                RenameLocal(
                  f,
                  to: target,
                  expectedHash: lf.hash,
                  remoteEntryId: h.entryId,
                ),
              );
              if (h.hash == bf.hash) {
                actions.add(
                  Upload(target, localHash: lf.hash, parent: h.entryId),
                );
              } else if (kindOf(target) != MergeKind.binary) {
                actions.add(
                  Merge(
                    target,
                    kind: kindOf(target),
                    localHash: lf.hash,
                    remote: h,
                    basePath: f,
                    baseEntryId: null,
                  ),
                );
              } else {
                actions.add(
                  ConflictCopy(target, localHash: lf.hash, remote: h),
                );
              }
              handled.add(f);
              handled.add(target);
            }
          }
        }
      }
    }

    return RenameDetectorResult(
      actions: actions,
      baseUpdates: baseUpdates,
      handledPaths: handled,
    );
  }

  static int _scoreCandidate(VaultPath d, VaultPath c) {
    if (d.name == c.name && d.parent != c.parent) {
      return 1; // same file name in another folder
    }
    if (d.parent == c.parent) {
      return 2; // same folder
    }
    return 3; // different folder and different name
  }

  static int _compareCandidates(VaultPath d1, VaultPath d2, VaultPath c) {
    final s1 = _scoreCandidate(d1, c);
    final s2 = _scoreCandidate(d2, c);
    if (s1 != s2) return s1.compareTo(s2);
    return d1.value.compareTo(d2.value);
  }
}
