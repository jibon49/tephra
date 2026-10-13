// © 2026 Tephra. All rights reserved.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/core/uuid.dart';

void main() {
  final uuidRegex = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  test('generateUuidV4 matches RFC 4122 v4 format', () {
    final id = generateUuidV4();
    expect(uuidRegex.hasMatch(id), isTrue);
  });

  test('1,000 generated values are unique', () {
    final set = <String>{};
    for (var i = 0; i < 1000; i++) {
      final id = generateUuidV4();
      expect(uuidRegex.hasMatch(id), isTrue);
      set.add(id);
    }
    expect(set.length, equals(1000));
  });

  test('seeded Random(1) produces stable value across two calls', () {
    final id1 = generateUuidV4(Random(1));
    final id2 = generateUuidV4(Random(1));
    expect(id1, equals(id2));
    expect(uuidRegex.hasMatch(id1), isTrue);
  });
}
