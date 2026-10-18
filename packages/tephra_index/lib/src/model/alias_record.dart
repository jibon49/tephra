// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

/// An alias declared for a note.
final class AliasRecord {
  const AliasRecord({required this.path, required this.alias});

  final VaultPath path;
  final String alias;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AliasRecord && path == other.path && alias == other.alias;

  @override
  int get hashCode => Object.hash(path, alias);

  @override
  String toString() => 'AliasRecord(path: ${path.value}, alias: $alias)';
}
