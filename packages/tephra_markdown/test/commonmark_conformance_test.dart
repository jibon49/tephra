// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:io';

import 'package:tephra_markdown/tephra_markdown.dart';
import 'package:test/test.dart';

import 'helpers/commonmark_html.dart';

final class _SpecExample {
  _SpecExample({
    required this.markdown,
    required this.html,
    required this.example,
    required this.startLine,
    required this.endLine,
    required this.section,
  });

  factory _SpecExample.fromJson(Map<String, Object?> json) {
    return _SpecExample(
      markdown: json['markdown']! as String,
      html: json['html']! as String,
      example: json['example']! as int,
      startLine: json['start_line']! as int,
      endLine: json['end_line']! as int,
      section: json['section']! as String,
    );
  }

  final String markdown;
  final String html;
  final int example;
  final int startLine;
  final int endLine;
  final String section;
}

void main() {
  var specFile = File('test/fixtures/spec.json');
  if (!specFile.existsSync()) {
    specFile = File('packages/tephra_markdown/test/fixtures/spec.json');
  }
  if (!specFile.existsSync()) {
    throw StateError('spec.json not found: ${specFile.path}');
  }

  final jsonList = jsonDecode(specFile.readAsStringSync()) as List<Object?>;
  final examples = jsonList
      .map((e) => _SpecExample.fromJson(e as Map<String, Object?>))
      .toList();

  var failuresFile = File('test/fixtures/commonmark_known_failures.txt');
  if (!failuresFile.parent.existsSync()) {
    failuresFile = File(
      'packages/tephra_markdown/test/fixtures/commonmark_known_failures.txt',
    );
  }

  const requiredSections = [
    'ATX headings',
    'Setext headings',
    'Fenced code blocks',
    'Thematic breaks',
    'Block quotes',
    'Code spans',
    'Backslash escapes',
  ];

  // Evaluate all examples
  final actualFailures = <int, _SpecExample>{};
  final sectionTotal = <String, int>{};
  final sectionPassed = <String, int>{};

  for (final ex in examples) {
    sectionTotal[ex.section] = (sectionTotal[ex.section] ?? 0) + 1;

    final parsed = MarkdownParser.parseWith(
      ex.markdown,
      const ParserOptions(obsidian: false, gfm: false),
    );
    final rendered = renderHtml(parsed.root, ex.markdown);

    if (rendered == ex.html) {
      sectionPassed[ex.section] = (sectionPassed[ex.section] ?? 0) + 1;
    } else {
      actualFailures[ex.example] = ex;
    }
  }

  // Print section report table
  final totalExamples = examples.length;
  final totalPassed = totalExamples - actualFailures.length;
  final passRate = totalPassed / totalExamples;

  // ignore: avoid_print, conformance progress summary required for PROGRESS.md
  print('\n=== CommonMark 0.31.2 Conformance Summary ===');
  // ignore: avoid_print, conformance summary
  print(
    'Total: $totalPassed / $totalExamples (${(passRate * 100).toStringAsFixed(1)}%)\n',
  );
  // ignore: avoid_print, conformance summary
  print('| Section | Passed | Total | Rate |');
  // ignore: avoid_print, conformance summary
  print('|---|---|---|---|');
  for (final entry in sectionTotal.entries) {
    final s = entry.key;
    final tot = entry.value;
    final pas = sectionPassed[s] ?? 0;
    final rate = (pas / tot * 100).toStringAsFixed(1);
    // ignore: avoid_print, conformance summary
    print('| $s | $pas | $tot | $rate% |');
  }
  // ignore: avoid_print, conformance summary
  print('=============================================\n');

  // If known failures file does not exist, initialize it
  if (!failuresFile.existsSync()) {
    final sortedKeys = actualFailures.keys.toList()..sort();
    final buffer = StringBuffer();
    for (final k in sortedKeys) {
      final ex = actualFailures[k]!;
      buffer.writeln('${ex.example} ${ex.section}');
    }
    failuresFile.writeAsStringSync(buffer.toString());
  }

  final knownFailureLines = failuresFile
      .readAsLinesSync()
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  final knownFailureNumbers = <int>{};
  final knownFailuresByNumber = <int, String>{};

  for (final line in knownFailureLines) {
    final parts = line.split(' ');
    final num = int.parse(parts.first);
    final sec = parts.sublist(1).join(' ');
    knownFailureNumbers.add(num);
    knownFailuresByNumber[num] = sec;
  }

  group('CommonMark Conformance Ratchet', () {
    test('1. no new failures: every failing example is listed in the file', () {
      final newFailures = <String>[];
      for (final entry in actualFailures.entries) {
        if (!knownFailureNumbers.contains(entry.key)) {
          newFailures.add('Example ${entry.key} (${entry.value.section})');
        }
      }
      expect(
        newFailures,
        isEmpty,
        reason: 'New failures appeared: ${newFailures.join(', ')}',
      );
    });

    test('2. known failures list only shrinks: every example listed in the file still fails', () {
      for (final num in knownFailureNumbers) {
        if (!actualFailures.containsKey(num)) {
          fail(
            'remove example $num from commonmark_known_failures.txt (it now passes!)',
          );
        }
      }
    });

    test('3. required sections are 100 % pass rate', () {
      for (final sec in requiredSections) {
        final tot = sectionTotal[sec] ?? 0;
        final pas = sectionPassed[sec] ?? 0;
        expect(
          pas,
          equals(tot),
          reason: 'Required section "$sec" has failures: $pas/$tot',
        );

        // Also assert known_failures contains no line of these sections
        for (final entry in knownFailuresByNumber.entries) {
          expect(
            entry.value,
            isNot(equals(sec)),
            reason:
                'commonmark_known_failures.txt must not contain examples from "$sec"',
          );
        }
      }
    });

    test('4. overall pass rate >= 85 %', () {
      expect(
        passRate,
        greaterThanOrEqualTo(0.85),
        reason:
            'Pass rate ${(passRate * 100).toStringAsFixed(1)}% is below 85%',
      );
    });

    test('5. known failures file is sorted by example number and has no duplicates', () {
      final numbers = <int>[];
      for (final line in knownFailureLines) {
        final num = int.parse(line.split(' ').first);
        numbers.add(num);
      }

      final sorted = List<int>.from(numbers)..sort();
      expect(numbers, equals(sorted), reason: 'File must be sorted');
      expect(
        numbers.toSet().length,
        equals(numbers.length),
        reason: 'File must not have duplicate example numbers',
      );
    });
  });
}
