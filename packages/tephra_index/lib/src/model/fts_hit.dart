// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

/// A full-text search match with bm25 ranking score.
final class FtsHit {
  const FtsHit({required this.path, required this.rank});

  final VaultPath path;
  final double rank;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FtsHit && path == other.path && rank == other.rank;

  @override
  int get hashCode => Object.hash(path, rank);

  @override
  String toString() => 'FtsHit(path: ${path.value}, rank: $rank)';
}
