// © 2026 Tephra. All rights reserved.

import 'package:tephra_sync/tephra_sync.dart';
import 'package:test/test.dart';

void main() {
  group('GcState', () {
    test('serializes and deserializes candidates cleanly with cipher', () async {
      final cipher = PlaintextObjectCipher();
      final now = DateTime.utc(2026, 10, 20, 12, 0, 0);
      final t1 = DateTime.utc(2026, 10, 19, 10, 0, 0);
      final t2 = DateTime.utc(2026, 10, 18, 15, 30, 0);

      final state = GcState(
        updatedAt: now,
        candidates: {
          'blobs/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa':
              t1,
          'blobs/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb':
              t2,
        },
      );

      final sealed = await state.seal(cipher);
      final opened = await GcState.open(sealed, cipher);

      expect(opened.version, 1);
      expect(opened.updatedAt, now);
      expect(opened.candidates.length, 2);
      expect(
        opened
            .candidates['blobs/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'],
        t1,
      );
      expect(
        opened
            .candidates['blobs/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'],
        t2,
      );
      expect(opened, equals(state));
    });

    test('ignores malformed candidate timestamps gracefully', () {
      final state = GcState.fromJson({
        'v': 1,
        'updatedAt': '2026-10-20T12:00:00.000Z',
        'candidates': {
          'blobs/valid': '2026-10-19T10:00:00.000Z',
          'blobs/invalid': 'not-a-valid-date',
        },
      });

      expect(state.candidates.length, 1);
      expect(state.candidates.containsKey('blobs/valid'), isTrue);
      expect(state.candidates.containsKey('blobs/invalid'), isFalse);
    });
  });
}
