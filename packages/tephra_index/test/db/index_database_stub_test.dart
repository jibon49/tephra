// © 2026 Tephra. All rights reserved.

import 'package:tephra_index/src/db/open_index_database_stub.dart';
import 'package:test/test.dart';

void main() {
  group('open_index_database_stub', () {
    test('calling openIndexDatabase throws UnsupportedError', () async {
      expect(
        () => openIndexDatabase('test.sqlite'),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('calling openMemoryIndexDatabase throws UnsupportedError', () async {
      expect(() => openMemoryIndexDatabase(), throwsA(isA<UnsupportedError>()));
    });

    test('calling openReaderIndexDatabase throws UnsupportedError', () {
      expect(
        () => openReaderIndexDatabase('test.sqlite'),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });
}
