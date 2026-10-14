// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'src/roundtrip.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart run tool/roundtrip_check.dart <vaultDir>...');
    exit(1);
  }

  var allOk = true;
  for (final dir in args) {
    final result = await checkVaultRoundtrip(dir);
    stdout.writeln(result.toSummary());
    if (!result.isSuccess) {
      allOk = false;
    }
  }

  if (!allOk) {
    exit(1);
  }
}
