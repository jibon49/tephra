// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

import '../local/sync_path_rules.dart';
import '../local/windows_names.dart';
import '../merge/conflict_naming.dart';
import '../model/hlc.dart';
import 'plan_note.dart';
import 'planner_input.dart';
import 'sync_action.dart';

/// Output from resolving case conflicts and invalid Windows filenames.
final class CaseConflictResult {
  const CaseConflictResult({
    required this.actions,
    required this.notes,
    required this.excludedPaths,
  });

  /// Actions to execute for resolving collisions / invalid names.
  final List<SyncAction> actions;

  /// Explanatory notes emitted for each resolution.
  final List<PlanNote> notes;

  /// Paths excluded from further planning in this cycle.
  final Set<VaultPath> excludedPaths;
}

/// Resolves case collisions on case-insensitive filesystems and invalid filenames on Windows.
abstract final class CaseConflictResolver {
  /// Analyzes remote live paths for case collisions and Windows-invalid names.
  static CaseConflictResult resolve(PlannerInput input) {
    if (!input.caseInsensitive && !input.isWindows) {
      return const CaseConflictResult(
        actions: [],
        notes: [],
        excludedPaths: {},
      );
    }

    final actions = <SyncAction>[];
    final notes = <PlanNote>[];
    final excludedPaths = <VaultPath>{};

    // Filter live paths that participate
    final livePaths = <VaultPath>[];
    for (final p in input.remote.livePaths()) {
      final vp = VaultPath.raw(p);
      final head = input.remote.head(p);
      final size = head?.size ?? 0;
      if (SyncPathRules.participates(vp, size, input.rules)) {
        livePaths.add(vp);
      }
    }
    livePaths.sort((a, b) => a.value.compareTo(b.value));

    final takenPaths = <String>{...input.remote.livePaths()};

    // 1. Case conflicts (case-insensitive devices)
    if (input.caseInsensitive) {
      final groups = <String, List<VaultPath>>{};
      for (final vp in livePaths) {
        groups.putIfAbsent(vp.value.toLowerCase(), () => []).add(vp);
      }

      final sortedKeys = groups.keys.toList()..sort();
      for (final key in sortedKeys) {
        final group = groups[key]!;
        if (group.length <= 1) continue;

        // Find path with oldest entry (minimum HLC among entries touching it)
        VaultPath? keepPath;
        Hlc? oldestHlc;

        for (final p in group) {
          final entries = input.remote.entriesTouching(p.value);
          Hlc? minEntryHlc;
          for (final e in entries) {
            final parsed = Hlc.parse(e.hlc);
            if (minEntryHlc == null || parsed.compareTo(minEntryHlc) < 0) {
              minEntryHlc = parsed;
            }
          }

          if (minEntryHlc != null) {
            if (oldestHlc == null ||
                minEntryHlc.compareTo(oldestHlc) < 0 ||
                (minEntryHlc.compareTo(oldestHlc) == 0 &&
                    p.value.compareTo(keepPath!.value) < 0)) {
              oldestHlc = minEntryHlc;
              keepPath = p;
            }
          }
        }

        keepPath ??= group.first;

        for (final x in group) {
          if (x == keepPath) continue;

          final hx = input.remote.head(x.value)!;
          final targetStr = caseConflictName(
            x,
            (candidate) => takenPaths.contains(candidate.value),
          );
          takenPaths.add(targetStr);
          final target = VaultPath(targetStr);

          actions.add(
            RenameRemote(
              x,
              to: target,
              parent: hx.entryId,
              targetParent: input.remote.head(target.value)?.entryId,
              hash: hx.hash ?? '',
              blobKeys: hx.blobKeys ?? const [],
            ),
          );

          if (input.base.containsKey(x)) {
            actions.add(
              RenameLocal(
                x,
                to: target,
                expectedHash: input.base[x]!.hash,
                remoteEntryId: hx.entryId,
              ),
            );
          }

          notes.add(
            PlanNote(
              x,
              PlanNoteKind.renamedDueToCaseConflict,
              detail: targetStr,
            ),
          );
          excludedPaths.add(x);
        }
      }
    }

    // 2. Windows invalid names (on Windows devices)
    if (input.isWindows) {
      for (final x in livePaths) {
        if (excludedPaths.contains(x)) continue;

        final segments = x.value.split('/');
        final hasInvalid = segments.any((seg) => !WindowsNames.isValid(seg));
        if (!hasInvalid) continue;

        final sanitizedSegments = segments.map(WindowsNames.sanitize).toList();
        final sanitizedBase = sanitizedSegments.join('/');

        var target = VaultPath(sanitizedBase);
        var counter = 1;
        while (takenPaths.contains(target.value)) {
          counter++;
          final stem = target.stem;
          final ext = target.extension;
          final parent = target.parent;
          final newName = ext.isEmpty
              ? '$stem $counter'
              : '$stem $counter.$ext';
          target = parent == null || parent.isRoot
              ? VaultPath(newName)
              : parent.join(newName);
        }

        takenPaths.add(target.value);
        final hx = input.remote.head(x.value)!;

        actions.add(
          RenameRemote(
            x,
            to: target,
            parent: hx.entryId,
            targetParent: input.remote.head(target.value)?.entryId,
            hash: hx.hash ?? '',
            blobKeys: hx.blobKeys ?? const [],
          ),
        );

        notes.add(
          PlanNote(x, PlanNoteKind.sanitizedWindowsName, detail: target.value),
        );
        excludedPaths.add(x);
      }
    }

    return CaseConflictResult(
      actions: actions,
      notes: notes,
      excludedPaths: excludedPaths,
    );
  }
}
