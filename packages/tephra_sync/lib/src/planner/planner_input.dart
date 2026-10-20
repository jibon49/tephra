// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

import '../local/local_file_state.dart';
import '../model/base_state.dart';
import '../model/selective_sync_rules.dart';
import '../remote/remote_history.dart';
import 'delete_decision.dart';

/// All immutable inputs required by the pure sync [Planner].
final class PlannerInput {
  const PlannerInput({
    required this.local,
    required this.base,
    required this.remote,
    required this.deviceId,
    required this.caseInsensitive,
    required this.isWindows,
    this.deleteDecisions = const {},
    this.rules = const SelectiveSyncRules(),
  });

  /// Local file state map, keyed by vault path (already filtered by [SyncPathRules]).
  final Map<VaultPath, LocalFileState> local;

  /// Last synced base state map from synced_files, keyed by vault path.
  final Map<VaultPath, BaseState> base;

  /// Remote causal history DAG.
  final RemoteHistory remote;

  /// Unique identifier of this local device.
  final String deviceId;

  /// True if the local filesystem is case-insensitive (Windows, Android).
  final bool caseInsensitive;

  /// True if running on Windows.
  final bool isWindows;

  /// User decisions for previously held deletes (approve | keep).
  final Map<VaultPath, DeleteDecision> deleteDecisions;

  /// Rules for selective sync exclusion.
  final SelectiveSyncRules rules;
}
