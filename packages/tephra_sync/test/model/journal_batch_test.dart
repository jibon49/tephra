// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import 'package:tephra_sync/tephra_sync.dart';
import 'package:test/test.dart';

void main() {
  group('JournalBatch and JournalEntry', () {
    test('JournalBatch JSON round trip', () {
      final entries = [
        const JournalEntry(
          entryId: 'dev1:41',
          deviceId: 'dev1',
          seq: 41,
          hlc: '001760175000000.000001.dev1',
          op: 'put',
          path: 'Folder/Note.md',
          hash: 'abc123def456',
          size: 1024,
          mtime: 1760175000000,
          blobKeys: ['blobs/deadbeef01234567'],
          parent: null,
          time: 1760175000000,
        ),
        const JournalEntry(
          entryId: 'dev1:42',
          deviceId: 'dev1',
          seq: 42,
          hlc: '001760175000000.000002.dev1',
          op: 'move',
          path: 'Folder/Renamed.md',
          fromPath: 'Folder/Note.md',
          hash: 'abc123def456',
          size: 1024,
          mtime: 1760175000000,
          blobKeys: ['blobs/deadbeef01234567'],
          parent: 'dev1:41',
          targetParent: null,
          time: 1760175001000,
        ),
        const JournalEntry(
          entryId: 'dev1:43',
          deviceId: 'dev1',
          seq: 43,
          hlc: '001760175000000.000003.dev1',
          op: 'delete',
          path: 'Folder/Renamed.md',
          hash: 'abc123def456',
          size: 1024,
          mtime: 1760175000000,
          blobKeys: ['blobs/deadbeef01234567'],
          parent: 'dev1:42',
          time: 1760175002000,
        ),
      ];

      final batch = JournalBatch(
        deviceId: 'dev1',
        firstSeq: 41,
        lastSeq: 43,
        createdAt: DateTime.utc(2026, 10, 11, 9, 30),
        entries: entries,
      );

      final json = batch.toJson();
      expect(json['v'], equals(1));
      expect(json['deviceId'], equals('dev1'));
      expect(json['firstSeq'], equals(41));
      expect(json['lastSeq'], equals(43));
      expect((json['entries'] as List).length, equals(3));

      final serialized = jsonEncode(json);
      final parsed = JournalBatch.fromJson(
        jsonDecode(serialized) as Map<String, Object?>,
      );

      expect(parsed, equals(batch));
      expect(parsed.entries.length, equals(3));
      expect(parsed.entries[0].entryId, equals('dev1:41'));
      expect(parsed.entries[1].op, equals('move'));
      expect(parsed.entries[1].fromPath, equals('Folder/Note.md'));
      expect(parsed.entries[2].op, equals('delete'));
    });

    test('validates contiguous sequence numbers', () {
      final nonContiguous = [
        const JournalEntry(
          entryId: 'dev1:1',
          deviceId: 'dev1',
          seq: 1,
          hlc: '001760175000000.000001.dev1',
          op: 'put',
          path: 'Note.md',
          time: 1000,
        ),
        const JournalEntry(
          entryId: 'dev1:3', // Missing seq 2!
          deviceId: 'dev1',
          seq: 3,
          hlc: '001760175000000.000002.dev1',
          op: 'put',
          path: 'Note2.md',
          time: 2000,
        ),
      ];

      expect(
        () => JournalBatch(
          deviceId: 'dev1',
          firstSeq: 1,
          lastSeq: 3,
          createdAt: DateTime.utc(2026, 10, 11),
          entries: nonContiguous,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validates max 1,000 entries per batch', () {
      final tooMany = List.generate(1001, (i) {
        final seq = i + 1;
        return JournalEntry(
          entryId: 'dev1:$seq',
          deviceId: 'dev1',
          seq: seq,
          hlc: '001760175000000.${seq.toString().padLeft(6, '0')}.dev1',
          op: 'put',
          path: 'Note$seq.md',
          time: 1000 + i,
        );
      });

      expect(
        () => JournalBatch(
          deviceId: 'dev1',
          firstSeq: 1,
          lastSeq: 1001,
          createdAt: DateTime.utc(2026, 10, 11),
          entries: tooMany,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('cannot exceed 1000'),
          ),
        ),
      );
    });
  });
}
