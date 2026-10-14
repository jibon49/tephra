// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:tephra_vault/tephra_vault.dart';

Future<void> main(List<String> args) async {
  var rounds = 20;
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--rounds' && i + 1 < args.length) {
      rounds = int.tryParse(args[i + 1]) ?? 20;
    }
  }

  final baseTempDir = Directory.systemTemp.createTempSync('tephra_kill_test_');
  try {
    // Attempt precompilation of kill_writer.dart for fast start
    final exePath = p.join(
      baseTempDir.path,
      Platform.isWindows ? 'kill_writer.exe' : 'kill_writer',
    );
    var exeExists = false;
    final compileRes = await Process.run('dart', [
      'compile',
      'exe',
      'tool/kill_writer.dart',
      '-o',
      exePath,
    ]);
    if (compileRes.exitCode == 0 && File(exePath).existsSync()) {
      exeExists = true;
    }

    for (var round = 1; round <= rounds; round++) {
      final rng = Random(round);
      final roundDir = Directory(p.join(baseTempDir.path, 'round_$round'))
        ..createSync();

      final Process process;
      if (exeExists) {
        process = await Process.start(exePath, [roundDir.path]);
      } else {
        process = await Process.start('dart', [
          'tool/kill_writer.dart',
          roundDir.path,
        ]);
      }

      var lastAcked = 0;
      final firstAckCompleter = Completer<void>();

      final sub = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            if (line.startsWith('ACK ')) {
              final ack = int.tryParse(line.substring(4).trim());
              if (ack != null) {
                lastAcked = ack;
                if (!firstAckCompleter.isCompleted) {
                  firstAckCompleter.complete();
                }
              }
            }
          });

      // Wait for at least the first ACK
      await firstAckCompleter.future.timeout(const Duration(seconds: 15));

      // Wait a random 50-800 ms after the first ACK
      final delayMs = 50 + rng.nextInt(751);
      await Future<void>.delayed(Duration(milliseconds: delayMs));

      // Kill the process
      if (Platform.isWindows) {
        await Process.run('taskkill', ['/F', '/PID', '${process.pid}']);
      } else {
        process.kill(ProcessSignal.sigkill);
      }

      await sub.cancel();
      // Ensure process is dead
      await process.exitCode.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          process.kill(ProcessSignal.sigkill);
          return -1;
        },
      );

      // Verify Note.md
      final noteFile = File(p.join(roundDir.path, 'Note.md'));
      if (!noteFile.existsSync()) {
        stderr.writeln('KILL round=$round FAILED: Note.md does not exist');
        exit(1);
      }

      final bytes = noteFile.readAsBytesSync();
      if (bytes.isEmpty) {
        stderr.writeln('KILL round=$round FAILED: Note.md is empty (0 bytes)');
        exit(1);
      }

      final doc = TextDocument.decode(bytes);
      if (doc.malformed) {
        stderr.writeln('KILL round=$round FAILED: Note.md is malformed UTF-8');
        exit(1);
      }

      final lines = doc.text.split('\n');
      if (lines.isEmpty || !lines[0].startsWith('VERSION ')) {
        stderr.writeln(
          'KILL round=$round FAILED: First line is not VERSION n (${lines.firstOrNull})',
        );
        exit(1);
      }

      final foundVersion = int.tryParse(lines[0].substring(8).trim());
      if (foundVersion == null) {
        stderr.writeln(
          'KILL round=$round FAILED: Could not parse version from ${lines[0]}',
        );
        exit(1);
      }

      // Find the last non-empty line
      var lastLineIndex = lines.length - 1;
      while (lastLineIndex >= 0 && lines[lastLineIndex].trim().isEmpty) {
        lastLineIndex--;
      }

      if (lastLineIndex < 0 || lines[lastLineIndex] != 'END $foundVersion') {
        stderr.writeln(
          'KILL round=$round FAILED: Last line is not END $foundVersion (${lines[lastLineIndex]})',
        );
        exit(1);
      }

      if (foundVersion < lastAcked) {
        stderr.writeln(
          'KILL round=$round FAILED: foundVersion $foundVersion < lastAcked $lastAcked',
        );
        exit(1);
      }

      if (foundVersion > lastAcked + 1) {
        stderr.writeln(
          'KILL round=$round FAILED: foundVersion $foundVersion > lastAcked + 1 ($lastAcked + 1)',
        );
        exit(1);
      }

      // Check leftover temp files and cleanStaleTemps
      final fs = IoVaultFileSystem(roundDir.path);
      final tmpFilesBefore = roundDir
          .listSync()
          .where((f) => p.basename(f.path).startsWith('.Note.md.tephra-tmp-'))
          .toList();

      final cleaned = await fs.cleanStaleTemps(olderThan: Duration.zero);
      if (cleaned != tmpFilesBefore.length) {
        stderr.writeln(
          'KILL round=$round FAILED: cleanStaleTemps cleaned $cleaned but tmpFilesBefore was ${tmpFilesBefore.length}',
        );
        exit(1);
      }

      final tmpFilesAfter = roundDir
          .listSync()
          .where((f) => p.basename(f.path).startsWith('.Note.md.tephra-tmp-'))
          .toList();
      if (tmpFilesAfter.isNotEmpty) {
        stderr.writeln(
          'KILL round=$round FAILED: tmp files remained after cleanStaleTemps',
        );
        exit(1);
      }

      stdout.writeln(
        'KILL round=$round acked=$lastAcked found=$foundVersion ok',
      );
    }

    stdout.writeln('KILL $rounds/$rounds ok');
  } finally {
    try {
      baseTempDir.deleteSync(recursive: true);
    } catch (_) {}
  }
}
