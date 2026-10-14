// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

final _log = Logger('explorer');

/// Reveals [absolutePath] in Windows File Explorer with the item selected.
Future<void> revealInSystemExplorer(String absolutePath) async {
  if (!Platform.isWindows) return;
  try {
    final normalized = p.windows.normalize(absolutePath);
    await Process.run('explorer.exe', ['/select,', normalized]);
  } catch (e, st) {
    _log.warning(
      'Failed to reveal file in Windows Explorer: $absolutePath',
      e,
      st,
    );
  }
}
