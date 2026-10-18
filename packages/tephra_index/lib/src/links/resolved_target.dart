// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

/// Target of a resolved link.
final class ResolvedTarget {
  const ResolvedTarget(this.path, {required this.viaAlias});

  /// The resolved vault path of the target file.
  final VaultPath path;

  /// True if resolution was via a note alias rather than a file name or path.
  final bool viaAlias;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResolvedTarget &&
          other.path == path &&
          other.viaAlias == viaAlias;

  @override
  int get hashCode => Object.hash(path, viaAlias);

  @override
  String toString() => 'ResolvedTarget($path, viaAlias: $viaAlias)';
}
