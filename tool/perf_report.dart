// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:io';

final class PerfRow {
  const PerfRow({
    required this.metric,
    required this.budgetStr,
    required this.valueStr,
    required this.result,
  });

  final String metric;
  final String budgetStr;
  final String valueStr;
  final String result; // 'PASS', 'FAIL', 'info'
}

final class PerfReportSummary {
  const PerfReportSummary({required this.rows, required this.missedBudgets});

  final List<PerfRow> rows;
  final int missedBudgets;

  bool get passed => missedBudgets == 0;

  String toMarkdown() {
    final buffer = StringBuffer();
    buffer.writeln('| metric | budget | value | result |');
    buffer.writeln('|---|---|---|---|');
    for (final r in rows) {
      buffer.writeln(
        '| ${r.metric} | ${r.budgetStr} | ${r.valueStr} | ${r.result} |',
      );
    }
    buffer.writeln();
    if (passed) {
      buffer.writeln('RESULT: all budgets met');
    } else {
      buffer.writeln('RESULT: $missedBudgets budget(s) missed');
    }
    return buffer.toString().trimRight();
  }
}

Map<String, double> getBudgets(String platform) {
  final isAndroid = platform.toLowerCase() == 'android';
  return {
    'editable': isAndroid ? 2500.0 : 1500.0,
    'index.full': isAndroid ? 60000.0 : 20000.0,
    'ui.index.frame.p95': 16.0,
    'ui.index.frame.max': 100.0,
    'typing.source.p95': 16.0,
    'typing.lp.p95': 16.0,
    'search.first.p95': 200.0,
    'search.total.rare.p95': 200.0,
    'switcher.p95': 50.0,
    'memory.rss': isAndroid ? 350.0 : 500.0,
    'apk.arm64': 40000000.0,
    'apk.armv7': 40000000.0,
    'apk.x64': 40000000.0,
  };
}

/// Parses console lines searching for `PERF <name> <value> <unit>`.
Map<String, List<double>> parsePerfLines(Iterable<String> lines) {
  final result = <String, List<double>>{};
  final regExp = RegExp(r'PERF\s+([^\s]+)\s+([0-9.-]+)');

  for (final line in lines) {
    final match = regExp.firstMatch(line);
    if (match != null) {
      final name = match.group(1)!;
      final valStr = match.group(2)!;
      final val = double.tryParse(valStr);
      if (val != null) {
        result.putIfAbsent(name, () => []).add(val);
      }
    }
  }
  return result;
}

double computeMedian(List<double> values) {
  if (values.isEmpty) {
    throw ArgumentError('values must not be empty');
  }
  final sorted = List<double>.of(values)..sort();
  final n = sorted.length;
  if (n % 2 == 1) {
    return sorted[n ~/ 2];
  } else {
    return (sorted[(n ~/ 2) - 1] + sorted[n ~/ 2]) / 2.0;
  }
}

PerfReportSummary generateReport(
  Map<String, double> metrics, {
  String platform = 'windows',
}) {
  final budgets = getBudgets(platform);
  final rows = <PerfRow>[];
  var missed = 0;

  // Process metrics with budgets first in canonical order, then other logged metrics
  final processedKeys = <String>{};
  for (final entry in budgets.entries) {
    final key = entry.key;
    if (metrics.containsKey(key)) {
      processedKeys.add(key);
      final val = metrics[key]!;
      final budget = entry.value;
      final bool pass = val < budget; // Strictly less than budget
      if (!pass) missed++;
      rows.add(
        PerfRow(
          metric: key,
          budgetStr: _formatNum(budget),
          valueStr: _formatNum(val),
          result: pass ? 'PASS' : 'FAIL',
        ),
      );
    }
  }

  // Any remaining metrics without budgets
  for (final entry in metrics.entries) {
    if (!processedKeys.contains(entry.key)) {
      rows.add(
        PerfRow(
          metric: entry.key,
          budgetStr: '-',
          valueStr: _formatNum(entry.value),
          result: 'info',
        ),
      );
    }
  }

  return PerfReportSummary(rows: rows, missedBudgets: missed);
}

String _formatNum(double d) {
  if (d == d.roundToDouble()) {
    return d.toInt().toString();
  }
  final s = d.toStringAsFixed(3);
  return s.replaceFirst(RegExp(r'\.?0+$'), '');
}

List<String> _readLines(File file) {
  final bytes = file.readAsBytesSync();
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
    final buffer = StringBuffer();
    for (var i = 2; i < bytes.length - 1; i += 2) {
      final codeUnit = bytes[i] | (bytes[i + 1] << 8);
      buffer.writeCharCode(codeUnit);
    }
    return const LineSplitter().convert(buffer.toString());
  }
  try {
    return utf8.decode(bytes).split(RegExp(r'\r?\n'));
  } catch (_) {
    return latin1.decode(bytes).split(RegExp(r'\r?\n'));
  }
}

void main(List<String> args) {
  var platform = 'windows';
  final files = <String>[];

  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a == '--platform' && i + 1 < args.length) {
      platform = args[++i];
    } else {
      files.add(a);
    }
  }

  if (files.isEmpty) {
    // Read from stdin if no files specified
    final lines = <String>[];
    String? line;
    while ((line = stdin.readLineSync()) != null) {
      lines.add(line!);
    }
    final parsed = parsePerfLines(lines);
    final medians = {
      for (final e in parsed.entries) e.key: computeMedian(e.value),
    };
    final report = generateReport(medians, platform: platform);
    // ignore: avoid_print
    print(report.toMarkdown());
    exit(report.passed ? 0 : 1);
  }

  final lines = <String>[];
  for (final f in files) {
    final file = File(f);
    if (file.existsSync()) {
      lines.addAll(_readLines(file));
    } else {
      stderr.writeln('Warning: File not found: $f');
    }
  }

  final parsed = parsePerfLines(lines);
  final medians = {
    for (final e in parsed.entries) e.key: computeMedian(e.value),
  };
  final report = generateReport(medians, platform: platform);
  // ignore: avoid_print
  print(report.toMarkdown());
  exit(report.passed ? 0 : 1);
}
