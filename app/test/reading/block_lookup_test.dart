// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/reading/block_lookup.dart';
import 'package:tephra_markdown/tephra_markdown.dart';

void main() {
  test('empty list returns -1', () {
    expect(blockIndexForOffset([], 0), equals(-1));
    expect(blockIndexForOffset([], 100), equals(-1));
  });

  test('offsets before, inside, and after blocks', () {
    final blocks = <MdNode>[
      MdParagraph(10, 20),
      MdHeading(30, 40, level: 1),
      MdParagraph(50, 70),
    ];

    // Offset before first block
    expect(blockIndexForOffset(blocks, 0), equals(0));
    expect(blockIndexForOffset(blocks, 9), equals(0));

    // Offsets at or inside first block
    expect(blockIndexForOffset(blocks, 10), equals(0));
    expect(blockIndexForOffset(blocks, 15), equals(0));
    expect(blockIndexForOffset(blocks, 20), equals(0));
    expect(
      blockIndexForOffset(blocks, 25),
      equals(0),
    ); // between 1st and 2nd -> 1st

    // Offsets at or inside second block
    expect(blockIndexForOffset(blocks, 30), equals(1));
    expect(blockIndexForOffset(blocks, 35), equals(1));
    expect(blockIndexForOffset(blocks, 49), equals(1));

    // Offsets at or inside third block and beyond
    expect(blockIndexForOffset(blocks, 50), equals(2));
    expect(blockIndexForOffset(blocks, 60), equals(2));
    expect(blockIndexForOffset(blocks, 70), equals(2));
    expect(blockIndexForOffset(blocks, 100), equals(2));
  });
}
