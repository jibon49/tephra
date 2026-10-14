// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart tool/kill_writer.dart <vaultDir>');
    exit(1);
  }

  final vaultDir = args[0];
  final fs = IoVaultFileSystem(vaultDir);
  final path = VaultPath('Note.md');

  var n = 1;
  while (true) {
    final sb = StringBuffer();
    sb.writeln('VERSION $n');
    for (var i = 2; i <= 4999; i++) {
      sb.writeln('line $i of $n');
    }
    sb.write('END $n\n');

    await fs.writeText(path, TextDocument(text: sb.toString()));
    stdout.writeln('ACK $n');
    await stdout.flush();
    n++;
  }
}
