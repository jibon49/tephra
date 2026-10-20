// © 2026 Tephra. All rights reserved.

/// Record of an incomplete operation stored for crash recovery.
final class PendingOp {
  /// Creates a [PendingOp].
  const PendingOp({
    required this.id,
    required this.kind,
    required this.payload,
    required this.state,
    required this.createdAt,
    required this.attempts,
    this.lastError,
  });

  /// Auto-incrementing database ID.
  final int id;

  /// Operation kind ('uploadJournal', 'heldDelete', etc.).
  final String kind;

  /// JSON payload describing the operation parameters.
  final String payload;

  /// Execution state: 'pending', 'running', 'failed'.
  final String state;

  /// Timestamp created in milliseconds UTC.
  final int createdAt;

  /// Number of retry attempts made.
  final int attempts;

  /// Last failure error message.
  final String? lastError;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingOp &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          kind == other.kind &&
          payload == other.payload &&
          state == other.state &&
          createdAt == other.createdAt &&
          attempts == other.attempts &&
          lastError == other.lastError;

  @override
  int get hashCode =>
      Object.hash(id, kind, payload, state, createdAt, attempts, lastError);

  @override
  String toString() =>
      'PendingOp(id: $id, kind: $kind, state: $state, attempts: $attempts)';
}
