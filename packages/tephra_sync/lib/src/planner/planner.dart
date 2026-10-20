// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

import '../local/local_file_state.dart';
import '../local/sync_path_rules.dart';
import '../merge/merge_kind.dart';
import '../model/base_state.dart';
import '../remote/remote_history.dart';
import 'base_update.dart';
import 'case_conflict_resolver.dart';
import 'delete_guard.dart';
import 'plan_note.dart';
import 'planner_input.dart';
import 'rename_detector.dart';
import 'status_classifier.dart';
import 'sync_action.dart';
import 'sync_plan.dart';

/// Pure, deterministic synchronization planner.
///
/// Implements the complete decision table, rename pairing, case conflict resolution,
/// and large-deletion guard without performing any I/O or accessing the system clock.
abstract final class Planner {
  /// Computes a [SyncPlan] from the provided [input].
  static SyncPlan plan(PlannerInput input) {
    // 1. Filter local and base states by participation rules
    final local = <VaultPath, LocalFileState>{};
    for (final entry in input.local.entries) {
      if (SyncPathRules.participates(
        entry.key,
        entry.value.size,
        input.rules,
      )) {
        local[entry.key] = entry.value;
      }
    }

    final base = <VaultPath, BaseState>{};
    for (final entry in input.base.entries) {
      if (SyncPathRules.participates(
        entry.key,
        entry.value.size,
        input.rules,
      )) {
        base[entry.key] = entry.value;
      }
    }

    final actions = <SyncAction>[];
    final baseUpdates = <BaseUpdate>[];
    final notes = <PlanNote>[];

    // 2. Case conflicts and invalid Windows filenames
    final caseResult = CaseConflictResolver.resolve(input);
    actions.addAll(caseResult.actions);
    notes.addAll(caseResult.notes);

    // 3. Rename detection
    final renameResult = RenameDetector.detect(
      local: local,
      base: base,
      remote: input.remote,
      excludedPaths: caseResult.excludedPaths,
    );
    actions.addAll(renameResult.actions);
    baseUpdates.addAll(renameResult.baseUpdates);

    // 4. Collect remaining paths
    final allPaths = <VaultPath>{};
    allPaths.addAll(local.keys);
    allPaths.addAll(base.keys);
    for (final p in input.remote.allPaths) {
      final vp = VaultPath.raw(p);
      final head = input.remote.head(p);
      final size = head?.size ?? 0;
      if (SyncPathRules.participates(vp, size, input.rules)) {
        allPaths.add(vp);
      }
    }
    allPaths.removeAll(renameResult.handledPaths);

    final sortedPaths = allPaths.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    // 5. Decision table
    for (final p in sortedPaths) {
      final l = local[p];
      final b = base[p];
      final h = input.remote.head(p.value);
      final hPresent = h != null && RemoteHistory.isPresentAt(h, p.value);

      // Rule zero (before the table): L and H present and equal hashes
      if (l != null && hPresent && l.hash == h.hash) {
        if (input.remote.isForked(p.value)) {
          final leaves = input.remote.leaves(p.value);
          final otherLeaf = leaves
              .where((leaf) => leaf.entryId != h.entryId && leaf.hash == h.hash)
              .firstOrNull;
          if (otherLeaf != null) {
            final reuse = (h.blobKeys != null && h.blobKeys!.isNotEmpty)
                ? h.blobKeys
                : null;
            actions.add(
              Upload(
                p,
                localHash: l.hash,
                parent: h.entryId,
                mergedParent: otherLeaf.entryId,
                reuseBlobKeys: reuse,
              ),
            );
            continue;
          }
        } else if (b == null || b.version != h.entryId) {
          baseUpdates.add(
            BaseUpdate.fromEntry(p, h, size: l.size, mtime: l.mtimeMs),
          );
        }
        continue;
      }

      final lStatus = StatusClassifier.classifyLocal(p, local, base);
      final rStatus = StatusClassifier.classifyRemote(p, b, input.remote);

      final isMine = b != null && b.version.startsWith('${input.deviceId}:');
      final kind = kindOf(p);
      final mergeable = kind != MergeKind.binary;

      switch (lStatus) {
        case LocalStatus.l0:
          switch (rStatus) {
            case RemoteStatus.r0:
              // Row 1 / Row 23: nothing exists or already deleted
              break;
            case RemoteStatus.rCreate:
              // Row 2: new remote file
              actions.add(Download(p, entry: h!, expectedLocalHash: null));
              break;
            default:
              break;
          }
          break;

        case LocalStatus.lEq:
          switch (rStatus) {
            case RemoteStatus.rEq:
              // Row 3: in sync
              if (h != null && b != null && h.entryId != b.version) {
                baseUpdates.add(
                  BaseUpdate.fromEntry(p, h, size: l!.size, mtime: l.mtimeMs),
                );
              }
              break;
            case RemoteStatus.rMod:
              // Row 4: remote edit
              actions.add(Download(p, entry: h!, expectedLocalHash: l!.hash));
              break;
            case RemoteStatus.rDel:
              // Row 5: remote delete
              actions.add(
                DeleteLocal(
                  p,
                  expectedHash: l!.hash,
                  remoteEntryId: h!.entryId,
                ),
              );
              break;
            case RemoteStatus.rGone:
              // Row 6: remote history unknown, republish
              actions.add(Upload(p, localHash: l!.hash, parent: null));
              notes.add(PlanNote(p, PlanNoteKind.republished));
              break;
            case RemoteStatus.rForkPlus:
              // Row 7: concurrent edit / fork
              if (isMine) {
                final lca = input.remote.lowestCommonAncestor(
                  b.version,
                  h!.entryId,
                  p.value,
                );
                if (mergeable && lca != null) {
                  actions.add(
                    Merge(
                      p,
                      kind: kind,
                      localHash: l!.hash,
                      remote: h,
                      basePath: p,
                      baseEntryId: lca.entryId,
                      mergedParent: b.version,
                    ),
                  );
                } else {
                  actions.add(
                    ConflictCopy(
                      p,
                      localHash: l!.hash,
                      remote: h,
                      mergedParent: b.version,
                    ),
                  );
                }
              } else {
                actions.add(Download(p, entry: h!, expectedLocalHash: l!.hash));
              }
              break;
            case RemoteStatus.rForkMinus:
              // Row 8: concurrent delete
              if (isMine) {
                actions.add(
                  Upload(
                    p,
                    localHash: l!.hash,
                    parent: h!.entryId,
                    mergedParent: b.version,
                  ),
                );
                notes.add(
                  PlanNote(p, PlanNoteKind.keptEditedFileDeletedElsewhere),
                );
              } else {
                actions.add(
                  DeleteLocal(
                    p,
                    expectedHash: l!.hash,
                    remoteEntryId: h!.entryId,
                  ),
                );
              }
              break;
            default:
              break;
          }
          break;

        case LocalStatus.lMod:
          switch (rStatus) {
            case RemoteStatus.rEq:
              // Row 9: local edit
              actions.add(Upload(p, localHash: l!.hash, parent: h!.entryId));
              break;
            case RemoteStatus.rMod:
              // Row 10: both edited
              if (mergeable) {
                actions.add(
                  Merge(
                    p,
                    kind: kind,
                    localHash: l!.hash,
                    remote: h!,
                    basePath: p,
                    baseEntryId: null,
                  ),
                );
              } else {
                actions.add(ConflictCopy(p, localHash: l!.hash, remote: h!));
              }
              break;
            case RemoteStatus.rDel:
              // Row 11: edit wins over delete
              actions.add(Upload(p, localHash: l!.hash, parent: h!.entryId));
              notes.add(
                PlanNote(p, PlanNoteKind.keptEditedFileDeletedElsewhere),
              );
              break;
            case RemoteStatus.rGone:
              // Row 12: keep data
              actions.add(Upload(p, localHash: l!.hash, parent: null));
              notes.add(PlanNote(p, PlanNoteKind.republished));
              break;
            case RemoteStatus.rForkPlus:
              // Row 13: concurrent fork with local edit
              final lca = input.remote.lowestCommonAncestor(
                b!.version,
                h!.entryId,
                p.value,
              );
              if (mergeable && lca != null) {
                actions.add(
                  Merge(
                    p,
                    kind: kind,
                    localHash: l!.hash,
                    remote: h,
                    basePath: p,
                    baseEntryId: lca.entryId,
                    mergedParent: b.version,
                  ),
                );
              } else {
                actions.add(
                  ConflictCopy(
                    p,
                    localHash: l!.hash,
                    remote: h,
                    mergedParent: b.version,
                  ),
                );
              }
              break;
            case RemoteStatus.rForkMinus:
              // Row 14: edit wins over delete
              actions.add(
                Upload(
                  p,
                  localHash: l!.hash,
                  parent: h!.entryId,
                  mergedParent: b!.version,
                ),
              );
              notes.add(
                PlanNote(p, PlanNoteKind.keptEditedFileDeletedElsewhere),
              );
              break;
            default:
              break;
          }
          break;

        case LocalStatus.lCreate:
          switch (rStatus) {
            case RemoteStatus.r0:
              // Row 15: new local file
              actions.add(Upload(p, localHash: l!.hash, parent: h?.entryId));
              break;
            case RemoteStatus.rCreate:
              // Row 16: two different files created with same name
              actions.add(ConflictCopy(p, localHash: l!.hash, remote: h!));
              break;
            default:
              break;
          }
          break;

        case LocalStatus.lDelete:
          switch (rStatus) {
            case RemoteStatus.rEq:
              // Row 17: local delete
              actions.add(
                DeleteRemote(
                  p,
                  parent: h!.entryId,
                  hash: b!.hash,
                  blobKeys: b.blobKeys,
                ),
              );
              break;
            case RemoteStatus.rMod:
              // Row 18: remote edit wins over local delete
              actions.add(Download(p, entry: h!, expectedLocalHash: null));
              notes.add(
                PlanNote(p, PlanNoteKind.restoredDeletedFileChangedElsewhere),
              );
              break;
            case RemoteStatus.rDel:
              // Row 19: deleted on both sides
              baseUpdates.add(BaseUpdate.remove(p));
              break;
            case RemoteStatus.rGone:
              // Row 20: gone everywhere
              baseUpdates.add(BaseUpdate.remove(p));
              break;
            case RemoteStatus.rForkPlus:
              // Row 21: remote content wins over local delete
              actions.add(Download(p, entry: h!, expectedLocalHash: null));
              notes.add(
                PlanNote(p, PlanNoteKind.restoredDeletedFileChangedElsewhere),
              );
              break;
            case RemoteStatus.rForkMinus:
              // Row 22: deleted on both sides
              baseUpdates.add(BaseUpdate.remove(p));
              break;
            default:
              break;
          }
          break;
      }
    }

    // 6. Large-delete guard
    final guardResult = DeleteGuard.apply(
      actions: actions,
      baseCount: base.length,
      decisions: input.deleteDecisions,
      remote: input.remote,
      local: local,
    );

    // 7. Deterministic sorting: actions by (phase, path.value)
    final sortedActions = guardResult.actions.toList()
      ..sort((a, b) {
        final phaseComp = a.phase.compareTo(b.phase);
        if (phaseComp != 0) return phaseComp;
        return a.path.value.compareTo(b.path.value);
      });

    final sortedBaseUpdates = baseUpdates.toList()
      ..sort((a, b) => a.path.value.compareTo(b.path.value));

    final sortedNotes = notes.toList()
      ..sort((a, b) => a.path.value.compareTo(b.path.value));

    return SyncPlan(
      actions: sortedActions,
      baseUpdates: sortedBaseUpdates,
      heldDeletes: guardResult.heldDeletes,
      notes: sortedNotes,
    );
  }
}
