// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import 'package:tephra_core/tephra_core.dart';
import 'package:test/test.dart';

void main() {
  test('contentHash returns 64-char lowercase hex sha256', () {
    final abcHash = contentHash(utf8.encode('abc'));
    expect(
      abcHash,
      equals(
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      ),
    );
    expect(abcHash.length, equals(64));
    expect(abcHash, equals(abcHash.toLowerCase()));

    final emptyHash = contentHash(<int>[]);
    expect(
      emptyHash,
      equals(
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      ),
    );
    expect(emptyHash.length, equals(64));
    expect(emptyHash, equals(emptyHash.toLowerCase()));
  });
}
