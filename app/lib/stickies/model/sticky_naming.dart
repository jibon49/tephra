// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

/// Computes a non-colliding path for a newly created sticky note in [folder].
///
/// Follows format 'Sticky YYYY-MM-DD HHmmss.md' using 24-hour local time;
/// appends ' 1', ' 2', ... before '.md' if the candidate path already exists.
VaultPath newStickyPath(
  VaultPath folder,
  DateTime localNow,
  bool Function(VaultPath) exists,
) {
  final y = localNow.year.toString().padLeft(4, '0');
  final m = localNow.month.toString().padLeft(2, '0');
  final d = localNow.day.toString().padLeft(2, '0');
  final h = localNow.hour.toString().padLeft(2, '0');
  final min = localNow.minute.toString().padLeft(2, '0');
  final sec = localNow.second.toString().padLeft(2, '0');

  final baseName = 'Sticky $y-$m-$d $h$min$sec';
  final firstCandidate = folder.isRoot
      ? VaultPath('$baseName.md')
      : folder.join('$baseName.md');

  if (!exists(firstCandidate)) {
    return firstCandidate;
  }

  var counter = 1;
  while (true) {
    final candidate = folder.isRoot
        ? VaultPath('$baseName $counter.md')
        : folder.join('$baseName $counter.md');
    if (!exists(candidate)) {
      return candidate;
    }
    counter++;
  }
}
