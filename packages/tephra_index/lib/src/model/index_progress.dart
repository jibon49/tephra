// © 2026 Tephra. All rights reserved.

/// Phase of indexer execution.
enum IndexPhase { idle, scanning, indexing, resolving, done }

/// Progress report from the indexer worker isolate.
final class IndexProgress {
  const IndexProgress({
    required this.phase,
    required this.done,
    required this.total,
  });

  final IndexPhase phase;
  final int done;
  final int total;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IndexProgress &&
          phase == other.phase &&
          done == other.done &&
          total == other.total;

  @override
  int get hashCode => Object.hash(phase, done, total);

  @override
  String toString() =>
      'IndexProgress(phase: $phase, done: $done, total: $total)';
}
