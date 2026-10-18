// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:path/path.dart' as p;

import 'src/bench_generator.dart';

void main(List<String> args) {
  var count = 10000;
  var seed = 42;
  String? outDirArg;
  var clean = false;
  var demo = false;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--count' && i + 1 < args.length) {
      count = int.parse(args[++i]);
    } else if (arg == '--seed' && i + 1 < args.length) {
      seed = int.parse(args[++i]);
    } else if (arg == '--out' && i + 1 < args.length) {
      outDirArg = args[++i];
    } else if (arg == '--clean') {
      clean = true;
    } else if (arg == '--demo') {
      demo = true;
    }
  }

  final repoRoot = _findRepoRoot();
  final outDir = outDirArg != null
      ? (p.isAbsolute(outDirArg)
            ? outDirArg
            : p.normalize(p.join(repoRoot, outDirArg)))
      : p.join(repoRoot, 'test_vaults', 'bench');

  if (clean) {
    if (!checkCleanAllowed(outDir)) {
      stderr.writeln('Refusing to delete $outDir: no .tephra-bench marker');
      exit(2);
    }
    final dir = Directory(outDir);
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  } else {
    final dir = Directory(outDir);
    if (dir.existsSync() && dir.listSync().isNotEmpty) {
      stderr.writeln(
        'Refusing to generate into non-empty directory $outDir without --clean',
      );
      exit(2);
    }
  }

  final hugeSource = p.join(
    repoRoot,
    'test_vaults',
    'edge',
    'huge-5000-lines.md',
  );

  final sw = Stopwatch()..start();
  final report = generateBenchVault(
    BenchOptions(
      count: count,
      seed: seed,
      outDir: outDir,
      demoPack: demo,
      hugeNoteSource: hugeSource,
    ),
  );
  sw.stop();

  // CLI tool output to stdout.
  // ignore: avoid_print
  print('$report in ${sw.elapsedMilliseconds}ms');
}

String _findRepoRoot() {
  var dir = Directory.current;
  while (true) {
    final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
    if (pubspec.existsSync()) {
      final content = pubspec.readAsStringSync();
      if (content.contains('name: tephra_workspace')) {
        return dir.path;
      }
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      break;
    }
    dir = parent;
  }
  throw StateError(
    'Could not locate workspace root (pubspec.yaml with name: tephra_workspace)',
  );
}
