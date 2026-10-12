// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';
import 'package:test/test.dart';

void main() {
  test('ManualClock moves time with advance and set', () {
    final start = DateTime(2026, 1, 1, 12, 0, 0);
    final clock = ManualClock(start);
    expect(clock.now(), equals(start));

    clock.advance(const Duration(seconds: 5));
    expect(clock.now(), equals(start.add(const Duration(seconds: 5))));

    final next = DateTime(2026, 2, 1, 0, 0, 0);
    clock.set(next);
    expect(clock.now(), equals(next));
  });

  test('SystemClock.now() matches DateTime.now() within 1 second', () {
    const clock = SystemClock();
    final before = DateTime.now();
    final current = clock.now();
    final after = DateTime.now();

    expect(
      current.isAfter(before.subtract(const Duration(seconds: 1))),
      isTrue,
    );
    expect(current.isBefore(after.add(const Duration(seconds: 1))), isTrue);
  });
}
