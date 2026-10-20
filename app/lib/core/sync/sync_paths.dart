// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Paths and directory resolution for sync engine state databases and metadata.
class SyncPaths {
  SyncPaths._();

  /// Returns the path to the SQLite sync state database for [vaultId].
  static Future<String> syncDatabasePath(String vaultId) async {
    final dir = await getApplicationSupportDirectory();
    final dbFile = p.join(dir.path, 'sync', '$vaultId.sqlite');
    final parentDir = Directory(p.dirname(dbFile));
    if (!parentDir.existsSync()) {
      parentDir.createSync(recursive: true);
    }
    return dbFile;
  }

  /// Synchronously computes the sync database path given [appSupportPath].
  static String syncDatabasePathForSupportDir(
    String appSupportPath,
    String vaultId,
  ) {
    final dbFile = p.join(appSupportPath, 'sync', '$vaultId.sqlite');
    final parentDir = Directory(p.dirname(dbFile));
    if (!parentDir.existsSync()) {
      parentDir.createSync(recursive: true);
    }
    return dbFile;
  }
}
