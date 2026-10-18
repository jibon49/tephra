// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/core/perf/perf_probe.dart';

void main() {
  group('PerfProbe', () {
    test('with enabled == false record stores nothing and prints nothing', () {
      expect(PerfProbe.enabled, isFalse);
      PerfProbe.reset();
      PerfProbe.record('test.metric', 42.0, 'ms');
      expect(PerfProbe.results, isEmpty);
    });

    test('log bridge static parser parses valid perf messages', () {
      final res1 = PerfProbe.parseLogMessage('perf switcher 12');
      expect(res1, isNotNull);
      expect(res1!.$1, 'switcher');
      expect(res1.$2, 12.0);
      expect(res1.$3, 'ms');

      final res2 = PerfProbe.parseLogMessage('perf autocomplete 5.2 ms');
      expect(res2, isNotNull);
      expect(res2!.$1, 'autocomplete');
      expect(res2.$2, 5.2);
      expect(res2.$3, 'ms');
    });

    test('log bridge static parser returns null on invalid messages', () {
      expect(PerfProbe.parseLogMessage('perf x'), isNull);
      expect(PerfProbe.parseLogMessage('not a perf message'), isNull);
      expect(PerfProbe.parseLogMessage('perf'), isNull);
    });
  });
}
