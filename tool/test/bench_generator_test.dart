// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../src/bench_generator.dart';

void main() {
  test('same seed gives identical output', () {
    final temp1 = Directory.systemTemp.createTempSync('tephra_bench_1_');
    final temp2 = Directory.systemTemp.createTempSync('tephra_bench_2_');
    addTearDown(() {
      if (temp1.existsSync()) temp1.deleteSync(recursive: true);
      if (temp2.existsSync()) temp2.deleteSync(recursive: true);
    });

    final r1 = generateBenchVault(
      BenchOptions(count: 200, seed: 1, outDir: temp1.path),
    );
    final r2 = generateBenchVault(
      BenchOptions(count: 200, seed: 1, outDir: temp2.path),
    );

    expect(r1.notes, r2.notes);
    expect(r1.links, r2.links);
    expect(r1.attachments, r2.attachments);
    expect(r1.bytes, r2.bytes);

    final files1 =
        temp1
            .listSync(recursive: true)
            .whereType<File>()
            .map((f) => p.relative(f.path, from: temp1.path))
            .toList()
          ..sort();
    final files2 =
        temp2
            .listSync(recursive: true)
            .whereType<File>()
            .map((f) => p.relative(f.path, from: temp2.path))
            .toList()
          ..sort();

    expect(files1, equals(files2));
    for (final rel in files1) {
      final b1 = File(p.join(temp1.path, rel)).readAsBytesSync();
      final b2 = File(p.join(temp2.path, rel)).readAsBytesSync();
      expect(b1, equals(b2), reason: 'Mismatch in $rel');
    }
  });

  test('different seed gives different output', () {
    final temp1 = Directory.systemTemp.createTempSync('tephra_bench_diff1_');
    final temp2 = Directory.systemTemp.createTempSync('tephra_bench_diff2_');
    addTearDown(() {
      if (temp1.existsSync()) temp1.deleteSync(recursive: true);
      if (temp2.existsSync()) temp2.deleteSync(recursive: true);
    });

    generateBenchVault(BenchOptions(count: 200, seed: 1, outDir: temp1.path));
    generateBenchVault(BenchOptions(count: 200, seed: 2, outDir: temp2.path));

    final files1 = temp1
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => p.relative(f.path, from: temp1.path))
        .toSet();
    final files2 = temp2
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => p.relative(f.path, from: temp2.path))
        .toSet();

    var identical = true;
    if (files1.length != files2.length || !files1.containsAll(files2)) {
      identical = false;
    } else {
      for (final rel in files1) {
        final b1 = File(p.join(temp1.path, rel)).readAsBytesSync();
        final b2 = File(p.join(temp2.path, rel)).readAsBytesSync();
        if (b1.length != b2.length) {
          identical = false;
          break;
        }
        for (var i = 0; i < b1.length; i++) {
          if (b1[i] != b2[i]) {
            identical = false;
            break;
          }
        }
        if (!identical) break;
      }
    }
    expect(identical, isFalse);
  });

  test('report counts', () {
    final temp = Directory.systemTemp.createTempSync('tephra_bench_rep_');
    addTearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    final report = generateBenchVault(
      BenchOptions(count: 200, seed: 1, outDir: temp.path),
    );

    expect(report.notes, 200);
    expect(report.attachments, 200);
    expect(report.unresolvedLinks, greaterThan(0));
    final linkRatio = report.links / report.notes;
    expect(linkRatio, greaterThanOrEqualTo(3.5));
    expect(linkRatio, lessThanOrEqualTo(6.5));
  });

  test('about half the notes have frontmatter', () {
    final temp = Directory.systemTemp.createTempSync('tephra_bench_fm_');
    addTearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    generateBenchVault(BenchOptions(count: 200, seed: 1, outDir: temp.path));

    final mdFiles = temp
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.md'))
        .toList();
    expect(mdFiles.length, 200);

    var frontmatterCount = 0;
    for (final f in mdFiles) {
      final text = utf8.decode(f.readAsBytesSync());
      if (text.startsWith('---\n')) {
        frontmatterCount++;
      }
    }

    final ratio = frontmatterCount / 200;
    expect(ratio, greaterThanOrEqualTo(0.40));
    expect(ratio, lessThanOrEqualTo(0.60));
  });

  test('max folder depth is 4 below the root', () {
    final temp = Directory.systemTemp.createTempSync('tephra_bench_depth_');
    addTearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    generateBenchVault(BenchOptions(count: 200, seed: 1, outDir: temp.path));

    final mdFiles = temp
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.md'))
        .toList();

    for (final f in mdFiles) {
      final rel = p.relative(f.path, from: temp.path);
      final parts = p.split(rel);
      // Folder segments are all parts except the filename
      final folderSegments = parts.sublist(0, parts.length - 1);
      expect(
        folderSegments.length,
        lessThanOrEqualTo(4),
        reason: 'Path $rel exceeds max folder depth 4',
      );
    }
  });

  test('refuses to clean a folder without marker', () {
    final temp = Directory.systemTemp.createTempSync('tephra_bench_clean_');
    addTearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    // Empty folder -> allowed
    expect(checkCleanAllowed(temp.path), isTrue);

    // Folder with x.txt and no marker -> refused
    final dummyFile = File(p.join(temp.path, 'x.txt'))..writeAsStringSync('hi');
    expect(checkCleanAllowed(temp.path), isFalse);

    // Folder with .tephra-bench marker -> allowed
    File(p.join(temp.path, '.tephra-bench'))
        .writeAsStringSync('seed=1 count=1\n');
    expect(checkCleanAllowed(temp.path), isTrue);

    // Clean up dummy
    dummyFile.deleteSync();
  });
}
