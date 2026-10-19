// © 2026 Tephra. All rights reserved.

import 'dart:math' as math;

import 'package:tephra_core/tephra_core.dart';

import '../local/local_file_state.dart';
import '../remote/remote_history.dart';
import 'delete_decision.dart';
import 'sync_action.dart';

/// Result of applying the [DeleteGuard] to a list of planned actions.
final class DeleteGuardResult {
  const DeleteGuardResult({required this.actions, required this.heldDeletes});

  /// Actions after filtering held deletes or converting keep decisions.
  final List<SyncAction> actions;

  /// Paths held awaiting user confirmation.
  final List<VaultPath> heldDeletes;
}

/// Protects against catastrophic data loss caused by mass local or remote deletions.
abstract final class DeleteGuard {
  /// Evaluates planned delete actions against deletion thresholds and user decisions.
  static DeleteGuardResult apply({
    required List<SyncAction> actions,
    required int baseCount,
    required Map<VaultPath, DeleteDecision> decisions,
    required RemoteHistory remote,
    required Map<VaultPath, LocalFileState> local,
  }) {
    // 1. Separate deletes from non-deletes
    final nonDeletes = <SyncAction>[];
    final deletes = <SyncAction>[];

    for (final a in actions) {
      if (a is DeleteLocal || a is DeleteRemote) {
        deletes.add(a);
      } else {
        nonDeletes.add(a);
      }
    }

    // 2. Count unapproved deletes
    final unapproved = <SyncAction>[];
    final approved = <SyncAction>[];
    final converted = <SyncAction>[];

    for (final a in deletes) {
      final decision = decisions[a.path];
      if (decision == DeleteDecision.approve) {
        approved.add(a);
      } else if (decision == DeleteDecision.keep) {
        if (a is DeleteRemote) {
          final h = remote.head(a.path.value);
          if (h != null) {
            converted.add(Download(a.path, entry: h, expectedLocalHash: null));
          }
        } else if (a is DeleteLocal) {
          final h = remote.head(a.path.value);
          final loc = local[a.path];
          if (loc != null) {
            converted.add(
              Upload(a.path, localHash: loc.hash, parent: h?.entryId),
            );
          }
        }
      } else {
        unapproved.add(a);
      }
    }

    // 3. Threshold check: count deletes not already approved in deleteDecisions
    final count = deletes
        .where((a) => decisions[a.path] != DeleteDecision.approve)
        .length;
    final denominator = math.max(1, baseCount);
    final isTriggered =
        count > 50 || (count >= 3 && count > 0.20 * denominator);

    final finalActions = <SyncAction>[...nonDeletes, ...approved, ...converted];
    final held = <VaultPath>[];

    if (isTriggered) {
      for (final a in unapproved) {
        held.add(a.path);
      }
    } else {
      finalActions.addAll(unapproved);
    }

    held.sort((a, b) => a.value.compareTo(b.value));

    return DeleteGuardResult(actions: finalActions, heldDeletes: held);
  }
}
