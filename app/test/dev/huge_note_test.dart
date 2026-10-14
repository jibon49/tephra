// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/dev/huge_note.dart';
import 'package:tephra/dev/typing_benchmark.dart';

Directory _findEdgeVaultDir() {
  var dir = Directory('test_vaults/edge');
  if (dir.existsSync()) return dir;
  dir = Directory('../test_vaults/edge');
  if (dir.existsSync()) return dir;
  dir = Directory('../../test_vaults/edge');
  if (dir.existsSync()) return dir;
  throw StateError('test_vaults/edge not found');
}

void main() {
  test(
    'generateHugeNote matches test_vaults/edge/huge-5000-lines.md exactly',
    () {
      final edgeDir = _findEdgeVaultDir();
      final file = File('${edgeDir.path}/huge-5000-lines.md');
      expect(
        file.existsSync(),
        isTrue,
        reason: 'huge-5000-lines.md should exist',
      );

      final expectedText = utf8.decode(file.readAsBytesSync());
      final actualText = generateHugeNote();

      expect(actualText, equals(expectedText));
    },
  );

  test('percentile helper computes nearest-rank values', () {
    expect(percentile([1, 2, 3, 4, 5], 50), equals(3.0));

    final hundred = List.generate(100, (i) => (i + 1).toDouble());
    expect(percentile(hundred, 95), equals(95.0));
    expect(percentile(hundred, 50), equals(50.0));
    expect(percentile(hundred, 90), equals(90.0));
    expect(percentile(hundred, 99), equals(99.0));
    expect(percentile([], 95), equals(0.0));
  });
}
