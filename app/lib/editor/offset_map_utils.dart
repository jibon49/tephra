// © 2026 Tephra. All rights reserved.

import 'dart:math';

import 'package:flutter/services.dart';

import 'edit_operation.dart';

/// Maps an integer [offset] through a single replacement edit `[start, end)` with [replacementLength].
int mapOffsetThroughEdit(
  int offset,
  int start,
  int end,
  int replacementLength,
) {
  if (offset <= start) return offset;
  if (offset >= end) return offset + (replacementLength - (end - start));
  return start + min(offset - start, replacementLength);
}

/// Maps an entire [TextSelection] through an ordered list of [EditOperation]s applied back-to-front.
TextSelection mapSelectionThroughEdits(
  TextSelection selection,
  List<EditOperation> ops,
) {
  var base = selection.baseOffset;
  var extent = selection.extentOffset;

  for (final op in ops) {
    base = mapOffsetThroughEdit(base, op.start, op.end, op.replacement.length);
    extent = mapOffsetThroughEdit(
      extent,
      op.start,
      op.end,
      op.replacement.length,
    );
  }

  return TextSelection(baseOffset: base, extentOffset: extent);
}

/// Computes the longest common prefix length between [a] and [b].
int commonPrefixLength(String a, String b) {
  final limit = min(a.length, b.length);
  var i = 0;
  while (i < limit && a.codeUnitAt(i) == b.codeUnitAt(i)) {
    i++;
  }
  return i;
}

/// Computes the longest common suffix length between [a] and [b], bounded by [maxSuffix].
int commonSuffixLength(String a, String b, int maxSuffix) {
  var i = 0;
  final aLen = a.length;
  final bLen = b.length;
  while (i < maxSuffix &&
      a.codeUnitAt(aLen - 1 - i) == b.codeUnitAt(bLen - 1 - i)) {
    i++;
  }
  return i;
}
