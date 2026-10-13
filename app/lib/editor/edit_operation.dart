// © 2026 Tephra. All rights reserved.

final class EditOperation {
  const EditOperation(this.start, this.end, this.replacement);

  final int start;
  final int end;
  final String replacement;

  int get deletedLength => end - start;
  int get delta => replacement.length - deletedLength;

  bool isValidFor(String text) =>
      0 <= start && start <= end && end <= text.length;

  String applyTo(String text) => text.replaceRange(start, end, replacement);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EditOperation &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          end == other.end &&
          replacement == other.replacement;

  @override
  int get hashCode => Object.hash(start, end, replacement);

  @override
  String toString() => 'EditOperation($start, $end, "$replacement")';
}
