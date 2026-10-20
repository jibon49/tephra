// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

import 'base_update.dart';
import 'plan_note.dart';
import 'sync_action.dart';

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// The deterministic output of a sync planning cycle.
final class SyncPlan {
  const SyncPlan({
    required this.actions,
    required this.baseUpdates,
    required this.heldDeletes,
    required this.notes,
  });

  /// Ordered synchronization actions to execute.
  final List<SyncAction> actions;

  /// Bookkeeping base updates to apply to synced_files.
  final List<BaseUpdate> baseUpdates;

  /// Paths of deletes held by the large-delete guard awaiting user confirmation.
  final List<VaultPath> heldDeletes;

  /// Informational notes generated during planning.
  final List<PlanNote> notes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncPlan &&
          _listEquals(actions, other.actions) &&
          _listEquals(baseUpdates, other.baseUpdates) &&
          _listEquals(heldDeletes, other.heldDeletes) &&
          _listEquals(notes, other.notes);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(actions),
    Object.hashAll(baseUpdates),
    Object.hashAll(heldDeletes),
    Object.hashAll(notes),
  );

  @override
  String toString() =>
      'SyncPlan(actions: ${actions.length}, baseUpdates: ${baseUpdates.length}, '
      'heldDeletes: ${heldDeletes.length}, notes: ${notes.length})';
}
