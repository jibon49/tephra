// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

import 'model_helpers.dart';

/// Event emitted after each committed index transaction.
final class IndexEvent {
  const IndexEvent({required this.changedPaths, required this.fullRebuild});

  /// Paths of notes or files that were added, updated, or removed.
  final Set<VaultPath> changedPaths;

  /// True if the event was triggered by a full database rebuild.
  final bool fullRebuild;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IndexEvent &&
          fullRebuild == other.fullRebuild &&
          setEquals(changedPaths, other.changedPaths);

  @override
  int get hashCode => Object.hash(fullRebuild, Object.hashAll(changedPaths));

  @override
  String toString() =>
      'IndexEvent(fullRebuild: $fullRebuild, changed: ${changedPaths.length})';
}
