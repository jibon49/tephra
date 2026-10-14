// © 2026 Tephra. All rights reserved.

import 'package:flutter/foundation.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

/// A flattened row in the file explorer tree.
@immutable
final class ExplorerRow {
  const ExplorerRow({
    required this.entry,
    required this.depth,
    this.expanded = false,
    this.loading = false,
  });

  final VaultEntry entry;
  final int depth;
  final bool expanded;
  final bool loading;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExplorerRow &&
          entry == other.entry &&
          depth == other.depth &&
          expanded == other.expanded &&
          loading == other.loading;

  @override
  int get hashCode => Object.hash(entry, depth, expanded, loading);

  @override
  String toString() =>
      'ExplorerRow(${entry.path.value}, depth: $depth, expanded: $expanded, loading: $loading)';
}

/// Flattens [rootEntries] and the contents of [expanded] folders into a linear row list using depth-first search.
List<ExplorerRow> flattenTree(
  List<VaultEntry> rootEntries,
  Set<VaultPath> expanded,
  Map<VaultPath, List<VaultEntry>> childrenOf, {
  int depth = 0,
}) {
  final rows = <ExplorerRow>[];

  for (final entry in rootEntries) {
    if (entry.isFolder) {
      final isExpanded = expanded.contains(entry.path);
      rows.add(
        ExplorerRow(
          entry: entry,
          depth: depth,
          expanded: isExpanded,
          loading: false,
        ),
      );

      if (isExpanded) {
        if (!childrenOf.containsKey(entry.path)) {
          // Loading placeholder row
          rows.add(
            ExplorerRow(
              entry: entry,
              depth: depth + 1,
              expanded: false,
              loading: true,
            ),
          );
        } else {
          final children = childrenOf[entry.path] ?? const [];
          rows.addAll(
            flattenTree(children, expanded, childrenOf, depth: depth + 1),
          );
        }
      }
    } else {
      rows.add(
        ExplorerRow(
          entry: entry,
          depth: depth,
          expanded: false,
          loading: false,
        ),
      );
    }
  }

  return rows;
}
