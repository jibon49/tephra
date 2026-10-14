// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';
import 'package:test/test.dart';

void main() {
  group('ChangeDebouncer', () {
    late ManualClock clock;
    late ChangeDebouncer debouncer;
    final pathA = VaultPath('a.md');
    final pathB = VaultPath('b.md');
    final pathC = VaultPath('c.md');

    setUp(() {
      clock = ManualClock(DateTime.utc(2026, 1, 1, 12, 0, 0));
      debouncer = ChangeDebouncer(
        clock: clock,
        quiet: const Duration(milliseconds: 150),
        maxWait: const Duration(milliseconds: 500),
      );
    });

    group('merge table per path (9 rows)', () {
      test('1. added + modified -> added', () {
        debouncer.add(pathA, RawChangeKind.added);
        debouncer.add(pathA, RawChangeKind.modified);
        clock.advance(const Duration(milliseconds: 150));
        final flushed = debouncer.flushIfDue();
        expect(flushed, [MergedChange(pathA, RawChangeKind.added)]);
      });

      test('2. added + removed -> dropped (empty list once due)', () {
        debouncer.add(pathA, RawChangeKind.added);
        debouncer.add(pathA, RawChangeKind.removed);
        clock.advance(const Duration(milliseconds: 150));
        final flushed = debouncer.flushIfDue();
        expect(flushed, isEmpty);
      });

      test('3. modified + modified -> modified', () {
        debouncer.add(pathA, RawChangeKind.modified);
        debouncer.add(pathA, RawChangeKind.modified);
        clock.advance(const Duration(milliseconds: 150));
        final flushed = debouncer.flushIfDue();
        expect(flushed, [MergedChange(pathA, RawChangeKind.modified)]);
      });

      test('4. modified + removed -> removed', () {
        debouncer.add(pathA, RawChangeKind.modified);
        debouncer.add(pathA, RawChangeKind.removed);
        clock.advance(const Duration(milliseconds: 150));
        final flushed = debouncer.flushIfDue();
        expect(flushed, [MergedChange(pathA, RawChangeKind.removed)]);
      });

      test('5. removed + added -> modified', () {
        debouncer.add(pathA, RawChangeKind.removed);
        debouncer.add(pathA, RawChangeKind.added);
        clock.advance(const Duration(milliseconds: 150));
        final flushed = debouncer.flushIfDue();
        expect(flushed, [MergedChange(pathA, RawChangeKind.modified)]);
      });

      test('6. removed + modified -> modified', () {
        debouncer.add(pathA, RawChangeKind.removed);
        debouncer.add(pathA, RawChangeKind.modified);
        clock.advance(const Duration(milliseconds: 150));
        final flushed = debouncer.flushIfDue();
        expect(flushed, [MergedChange(pathA, RawChangeKind.modified)]);
      });

      test('7. modified + added -> modified', () {
        debouncer.add(pathA, RawChangeKind.modified);
        debouncer.add(pathA, RawChangeKind.added);
        clock.advance(const Duration(milliseconds: 150));
        final flushed = debouncer.flushIfDue();
        expect(flushed, [MergedChange(pathA, RawChangeKind.modified)]);
      });

      test('8. removed + removed -> removed', () {
        debouncer.add(pathA, RawChangeKind.removed);
        debouncer.add(pathA, RawChangeKind.removed);
        clock.advance(const Duration(milliseconds: 150));
        final flushed = debouncer.flushIfDue();
        expect(flushed, [MergedChange(pathA, RawChangeKind.removed)]);
      });

      test('9. added + added -> added', () {
        debouncer.add(pathA, RawChangeKind.added);
        debouncer.add(pathA, RawChangeKind.added);
        clock.advance(const Duration(milliseconds: 150));
        final flushed = debouncer.flushIfDue();
        expect(flushed, [MergedChange(pathA, RawChangeKind.added)]);
      });
    });

    test('flushIfDue returns null at +149 ms and merged list at +150 ms', () {
      debouncer.add(pathA, RawChangeKind.added);

      clock.advance(const Duration(milliseconds: 149));
      expect(debouncer.flushIfDue(), isNull);

      clock.advance(const Duration(milliseconds: 1));
      final flushed = debouncer.flushIfDue();
      expect(flushed, isNotNull);
      expect(flushed, [MergedChange(pathA, RawChangeKind.added)]);

      // After flush, debouncer is empty and flush returns null
      expect(debouncer.flushIfDue(), isNull);
    });

    test(
      'continuous events every 100 ms for 600 ms flush at +500 ms (maxWait)',
      () {
        // t = 0 ms: first event
        debouncer.add(pathA, RawChangeKind.modified);

        // t = 100 ms
        clock.advance(const Duration(milliseconds: 100));
        debouncer.add(pathA, RawChangeKind.modified);
        expect(debouncer.flushIfDue(), isNull);

        // t = 200 ms
        clock.advance(const Duration(milliseconds: 100));
        debouncer.add(pathA, RawChangeKind.modified);
        expect(debouncer.flushIfDue(), isNull);

        // t = 300 ms
        clock.advance(const Duration(milliseconds: 100));
        debouncer.add(pathA, RawChangeKind.modified);
        expect(debouncer.flushIfDue(), isNull);

        // t = 400 ms
        clock.advance(const Duration(milliseconds: 100));
        debouncer.add(pathA, RawChangeKind.modified);
        expect(debouncer.flushIfDue(), isNull);

        // t = 499 ms
        clock.advance(const Duration(milliseconds: 99));
        expect(debouncer.flushIfDue(), isNull);

        // t = 500 ms: maxWait elapsed
        clock.advance(const Duration(milliseconds: 1));
        final flushed = debouncer.flushIfDue();
        expect(flushed, isNotNull);
        expect(flushed, [MergedChange(pathA, RawChangeKind.modified)]);
      },
    );

    test('order is first-seen', () {
      debouncer.add(pathB, RawChangeKind.added);
      debouncer.add(pathA, RawChangeKind.added);
      debouncer.add(pathC, RawChangeKind.added);

      // Update pathB again later
      clock.advance(const Duration(milliseconds: 50));
      debouncer.add(pathB, RawChangeKind.modified);

      clock.advance(const Duration(milliseconds: 150));
      final flushed = debouncer.flushIfDue();
      expect(flushed, [
        MergedChange(pathB, RawChangeKind.added),
        MergedChange(pathA, RawChangeKind.added),
        MergedChange(pathC, RawChangeKind.added),
      ]);
    });

    test(
      'added+removed leaves nothing (flush returns empty list, not null)',
      () {
        debouncer.add(pathA, RawChangeKind.added);
        debouncer.add(pathA, RawChangeKind.removed);

        clock.advance(const Duration(milliseconds: 150));
        final flushed = debouncer.flushIfDue();
        expect(flushed, isNotNull);
        expect(flushed, isEmpty);
      },
    );

    test('clear resets state', () {
      debouncer.add(pathA, RawChangeKind.added);
      expect(debouncer.nextDueAt, isNotNull);
      debouncer.clear();
      expect(debouncer.nextDueAt, isNull);
      expect(debouncer.flushIfDue(), isNull);
    });
  });
}
