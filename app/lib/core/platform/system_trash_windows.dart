// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:logging/logging.dart';
import 'package:tephra_vault/tephra_vault.dart';

/// Windows implementation of [SystemTrash] using PowerShell and Microsoft.VisualBasic RecycleBin.
final class WindowsSystemTrash implements SystemTrash {
  final _log = Logger('trash');

  @override
  Future<bool> moveToTrash(
    String absolutePath, {
    required bool isFolder,
  }) async {
    final method = isFolder ? 'DeleteDirectory' : 'DeleteFile';
    final script =
        'Add-Type -AssemblyName Microsoft.VisualBasic; '
        r'$p = $env:TEPHRA_TRASH_PATH; '
        '[Microsoft.VisualBasic.FileIO.FileSystem]::$method('
        r"$p, 'OnlyErrorDialogs', 'SendToRecycleBin')";

    try {
      final result = await Process.run(
        'powershell.exe',
        [
          '-NoProfile',
          '-NonInteractive',
          '-ExecutionPolicy',
          'Bypass',
          '-Command',
          script,
        ],
        environment: {'TEPHRA_TRASH_PATH': absolutePath},
        includeParentEnvironment: true,
      ).timeout(const Duration(seconds: 20));

      if (result.exitCode != 0) {
        _log.warning(
          'PowerShell trash exitCode ${result.exitCode}: ${result.stderr}',
        );
        return false;
      }
      return true;
    } catch (e, st) {
      _log.warning('Failed to move $absolutePath to Windows trash: $e', e, st);
      return false;
    }
  }
}
