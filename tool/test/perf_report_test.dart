// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../perf_report.dart';

void main() {
  group('perf_report unit tests', () {
    test(
      'sample log with two editable lines takes median and PASS on Windows',
      () {
        final logLines = [
          'Some uninteresting line',
          'PERF editable 1300 ms',
          'Another line without perf',
          'PERF editable 1500 ms',
        ];

        final parsed = parsePerfLines(logLines);
        expect(parsed['editable'], equals([1300.0, 1500.0]));
        final median = computeMedian(parsed['editable']!);
        expect(median, 1400.0);

        final reportWin = generateReport({
          'editable': median,
        }, platform: 'windows');
        expect(reportWin.rows.length, 1);
        expect(reportWin.rows.first.metric, 'editable');
        expect(reportWin.rows.first.result, 'PASS');
        expect(reportWin.passed, isTrue);

        final reportAndroid = generateReport({
          'editable': median,
        }, platform: 'android');
        expect(reportAndroid.rows.first.result, 'PASS');
        expect(reportAndroid.passed, isTrue);
      },
    );

    test('editable 1500 alone on Windows fails (strictly < budget)', () {
      final logLines = ['PERF editable 1500 ms'];
      final parsed = parsePerfLines(logLines);
      final median = computeMedian(parsed['editable']!);

      final reportWin = generateReport({
        'editable': median,
      }, platform: 'windows');
      expect(reportWin.rows.first.result, 'FAIL');
      expect(reportWin.passed, isFalse);
    });

    test('unknown metrics are marked as info', () {
      final logLines = ['PERF custom.metric 42 ms'];
      final parsed = parsePerfLines(logLines);
      final median = computeMedian(parsed['custom.metric']!);

      final reportWin = generateReport({
        'custom.metric': median,
      }, platform: 'windows');
      expect(reportWin.rows.first.metric, 'custom.metric');
      expect(reportWin.rows.first.result, 'info');
      expect(reportWin.passed, isTrue);
    });

    test('lines without PERF are ignored', () {
      final logLines = [
        'Info: Starting app',
        'DEBUG: some trace',
        'PERF ui.index.frame.p95 12.5 ms',
      ];
      final parsed = parsePerfLines(logLines);
      expect(parsed.keys, equals(['ui.index.frame.p95']));
    });
  });

  group('perf_report CLI exit codes', () {
    test('index.full 25000 on Windows fails with exit code 1', () async {
      final temp = Directory.systemTemp.createTempSync('perf_rep_cli_');
      addTearDown(() {
        if (temp.existsSync()) temp.deleteSync(recursive: true);
      });

      final logFile = File(p.join(temp.path, 'perf.log'))
        ..writeAsStringSync('PERF index.full 25000 ms\n');

      final result = await Process.run('dart', [
        'run',
        'tool/perf_report.dart',
        logFile.path,
        '--platform',
        'windows',
      ]);

      expect(result.exitCode, 1);
      expect(result.stdout, contains('RESULT: 1 budget(s) missed'));
      expect(result.stdout, contains('| index.full | 20000 | 25000 | FAIL |'));
    });

    test('passing run exits with code 0', () async {
      final temp = Directory.systemTemp.createTempSync('perf_rep_cli_pass_');
      addTearDown(() {
        if (temp.existsSync()) temp.deleteSync(recursive: true);
      });

      final logFile = File(
        p.join(temp.path, 'perf.log'),
      )..writeAsStringSync('PERF editable 1200 ms\nPERF index.full 15000 ms\n');

      final result = await Process.run('dart', [
        'run',
        'tool/perf_report.dart',
        logFile.path,
        '--platform',
        'windows',
      ]);

      expect(result.exitCode, 0);
      expect(result.stdout, contains('RESULT: all budgets met'));
    });
  });
}
