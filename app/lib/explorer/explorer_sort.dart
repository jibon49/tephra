// © 2026 Tephra. All rights reserved.

import 'package:tephra_vault/tephra_vault.dart';

import '../settings/vault_settings.dart';
import 'visible_file_types.dart';

/// Sorts [entries] according to [sort].
///
/// Folders always appear before files in every mode.
List<VaultEntry> sortEntries(List<VaultEntry> entries, ExplorerSort sort) {
  final list = List<VaultEntry>.from(entries);
  list.sort((a, b) {
    // Folders always first
    if (a.isFolder != b.isFolder) {
      return a.isFolder ? -1 : 1;
    }

    int compareNamesAsc() {
      final nameA = displayName(a).toLowerCase();
      final nameB = displayName(b).toLowerCase();
      final cmp = nameA.compareTo(nameB);
      if (cmp != 0) return cmp;
      return a.path.value.compareTo(b.path.value);
    }

    switch (sort) {
      case ExplorerSort.nameAsc:
        return compareNamesAsc();
      case ExplorerSort.nameDesc:
        final nameA = displayName(a).toLowerCase();
        final nameB = displayName(b).toLowerCase();
        final cmp = nameB.compareTo(nameA);
        if (cmp != 0) return cmp;
        return b.path.value.compareTo(a.path.value);
      case ExplorerSort.modifiedNew:
        final cmp = b.modified.compareTo(a.modified);
        if (cmp != 0) return cmp;
        return compareNamesAsc();
      case ExplorerSort.modifiedOld:
        final cmp = a.modified.compareTo(b.modified);
        if (cmp != 0) return cmp;
        return compareNamesAsc();
      case ExplorerSort.createdNew:
        final dateA = a.created ?? a.modified;
        final dateB = b.created ?? b.modified;
        final cmp = dateB.compareTo(dateA);
        if (cmp != 0) return cmp;
        return compareNamesAsc();
      case ExplorerSort.createdOld:
        final dateA = a.created ?? a.modified;
        final dateB = b.created ?? b.modified;
        final cmp = dateA.compareTo(dateB);
        if (cmp != 0) return cmp;
        return compareNamesAsc();
    }
  });
  return list;
}
