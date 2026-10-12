// © 2026 Tephra. All rights reserved.

final class _Segment {
  _Segment({
    required this.srcStart,
    required this.srcEnd,
    required this.virtStart,
  });

  final int srcStart;
  final int srcEnd;
  final int virtStart;

  int get length => srcEnd - srcStart;
  int get virtEnd => virtStart + length;
}

/// Maps character offsets within a virtual inline string back to absolute
/// UTF-16 source offsets.
final class OffsetMap {
  OffsetMap();

  final List<_Segment> _segments = [];

  /// Appends text of source range `[srcStart, srcEnd)`.
  /// Consecutive segments are automatically joined by a virtual `\n`.
  void addSegment(int srcStart, int srcEnd) {
    if (srcEnd < srcStart) {
      throw ArgumentError('srcEnd ($srcEnd) must be >= srcStart ($srcStart)');
    }
    final int virtStart;
    if (_segments.isEmpty) {
      virtStart = 0;
    } else {
      final prev = _segments.last;
      virtStart = prev.virtEnd + 1;
    }
    _segments.add(
      _Segment(srcStart: srcStart, srcEnd: srcEnd, virtStart: virtStart),
    );
  }

  /// Concatenates all segments joined by `\n` using the [source] string.
  String buildText(String source) {
    if (_segments.isEmpty) return '';
    final sb = StringBuffer();
    for (var i = 0; i < _segments.length; i++) {
      if (i > 0) sb.write('\n');
      final s = _segments[i];
      sb.write(source.substring(s.srcStart, s.srcEnd));
    }
    return sb.toString();
  }

  /// Maps a virtual index to its start-style source offset.
  /// The virtual `\n` between segments maps to the previous segment's `srcEnd`.
  int toSource(int virtualIndex) {
    if (_segments.isEmpty) return 0;
    if (virtualIndex <= 0) return _segments.first.srcStart;

    var low = 0;
    var high = _segments.length - 1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      final seg = _segments[mid];
      if (virtualIndex < seg.virtStart) {
        high = mid - 1;
      } else if (virtualIndex < seg.virtEnd) {
        return seg.srcStart + (virtualIndex - seg.virtStart);
      } else if (virtualIndex == seg.virtEnd) {
        return seg.srcEnd;
      } else {
        low = mid + 1;
      }
    }
    return _segments.last.srcEnd;
  }

  /// Maps an exclusive virtual end index to its source offset.
  int toSourceEnd(int virtualIndexExclusive) {
    return virtualIndexExclusive == 0
        ? toSource(0)
        : toSource(virtualIndexExclusive - 1) + 1;
  }
}
