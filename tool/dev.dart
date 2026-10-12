// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  final port = int.parse(Platform.environment['PORT'] ?? '8093');
  final repoRoot = _findRepoRoot();
  final ip = await _lanIp();
  stdout.writeln('Local: http://localhost:$port/');
  stdout.writeln('Network: http://${ip ?? '127.0.0.1'}:$port/');
  final child = await Process.start(
    'flutter',
    [
      'run',
      '-d',
      'web-server',
      '--web-hostname',
      '0.0.0.0',
      '--web-port',
      '$port',
    ],
    workingDirectory: p.join(repoRoot, 'app'),
    mode: ProcessStartMode.inheritStdio,
    runInShell: Platform.isWindows,
  );
  final sigint = ProcessSignal.sigint.watch().listen(
    (_) => child.kill(ProcessSignal.sigint),
  );
  final code = await child.exitCode;
  await sigint.cancel();
  exit(code);
}

String _findRepoRoot() {
  var dir = Directory.current;
  while (true) {
    final appPubspec = File(p.join(dir.path, 'app', 'pubspec.yaml'));
    if (appPubspec.existsSync()) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      break;
    }
    dir = parent;
  }
  throw StateError(
    'Could not find repository root containing app/pubspec.yaml',
  );
}

Future<String?> _lanIp() async {
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    final candidates = <String>[];
    for (final interface in interfaces) {
      final name = interface.name.toLowerCase();
      if (name.contains('vethernet') ||
          name.contains('wsl') ||
          name.contains('virtualbox') ||
          name.contains('vmware') ||
          name.contains('hyper-v') ||
          name.contains('docker') ||
          name.contains('loopback')) {
        continue;
      }
      for (final addr in interface.addresses) {
        final address = addr.address;
        if (address.startsWith('169.254.')) {
          continue;
        }
        candidates.add(address);
      }
    }
    for (final addr in candidates) {
      if (addr.startsWith('192.168.')) {
        return addr;
      }
    }
    for (final addr in candidates) {
      if (addr.startsWith('10.')) {
        return addr;
      }
    }
    for (final addr in candidates) {
      if (addr.startsWith('172.')) {
        return addr;
      }
    }
    if (candidates.isNotEmpty) {
      return candidates.first;
    }
  } catch (_) {}
  return null;
}
