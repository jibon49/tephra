// © 2026 Tephra. All rights reserved.

import 'index_database.dart';

/// Result of opening: the database plus whether it was (re)created empty and therefore needs a full index.
final class OpenedIndexDatabase {
  const OpenedIndexDatabase(this.db, {required this.needsFullIndex});

  final TephraIndexDatabase db;
  final bool needsFullIndex;
}

/// Throws [UnsupportedError] because index is unsupported on web.
Future<OpenedIndexDatabase> openIndexDatabase(String dbFile) async {
  throw UnsupportedError('The index is not available on this platform');
}

/// Throws [UnsupportedError] because index is unsupported on web.
Future<OpenedIndexDatabase> openMemoryIndexDatabase() async {
  throw UnsupportedError('The index is not available on this platform');
}

/// Throws [UnsupportedError] because index is unsupported on web.
TephraIndexDatabase openReaderIndexDatabase(String dbFile) {
  throw UnsupportedError('The index is not available on this platform');
}
