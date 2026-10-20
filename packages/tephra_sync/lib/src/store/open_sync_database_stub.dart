// © 2026 Tephra. All rights reserved.

import 'sync_database.dart';

/// Throws [UnsupportedError] on unsupported platforms (e.g. web preview).
Future<TephraSyncDatabase> openSyncDatabase(String dbFile) async {
  throw UnsupportedError('Sync database is not supported on this platform');
}

/// Throws [UnsupportedError] on unsupported platforms.
Future<TephraSyncDatabase> openMemorySyncDatabase() async {
  throw UnsupportedError('Sync database is not supported on this platform');
}
