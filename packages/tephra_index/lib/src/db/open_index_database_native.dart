// © 2026 Tephra. All rights reserved.

import 'dart:ffi';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../index_exceptions.dart';
import 'index_database.dart';

DynamicLibrary? _sqliteLib;

void _ensureSqliteInitialized() {
  if (_sqliteLib != null) return;
  if (Platform.isWindows) {
    final candidates = [
      'build/native_assets/windows/sqlite3.dll',
      '../build/native_assets/windows/sqlite3.dll',
      'app/build/native_assets/windows/sqlite3.dll',
      '../app/build/native_assets/windows/sqlite3.dll',
      '.dart_tool/lib/sqlite3.dll',
      '../.dart_tool/lib/sqlite3.dll',
      '../../.dart_tool/lib/sqlite3.dll',
    ];
    for (final rel in candidates) {
      final f = File(rel);
      if (f.existsSync()) {
        try {
          _sqliteLib = DynamicLibrary.open(f.absolute.path);
          break;
        } catch (_) {}
      }
    }
  }
}

/// Result of opening: the database plus whether it was (re)created empty and therefore needs a full index.
final class OpenedIndexDatabase {
  const OpenedIndexDatabase(this.db, {required this.needsFullIndex});

  final TephraIndexDatabase db;
  final bool needsFullIndex;
}

final Logger _logger = Logger('index');

void _setup(sqlite.Database raw) {
  raw.execute('PRAGMA journal_mode = WAL');
  raw.execute('PRAGMA synchronous = NORMAL');
  raw.execute('PRAGMA foreign_keys = ON');
  raw.execute('PRAGMA busy_timeout = 5000');
  raw.execute('PRAGMA temp_store = MEMORY');
  raw.execute('PRAGMA cache_size = -16000');
}

void _readerSetup(sqlite.Database raw) {
  raw.execute('PRAGMA busy_timeout = 5000');
  raw.execute('PRAGMA query_only = ON');
}

void _deleteDbFiles(String dbFile) {
  for (final path in [dbFile, '$dbFile-wal', '$dbFile-shm']) {
    try {
      final f = File(path);
      if (f.existsSync()) {
        f.deleteSync();
      }
    } catch (_) {}
  }
}

/// Opens [dbFile] synchronously-on-this-isolate (used by the worker isolate and by tests).
Future<OpenedIndexDatabase> openIndexDatabase(String dbFile) async {
  _ensureSqliteInitialized();
  Directory(p.dirname(dbFile)).createSync(recursive: true);

  TephraIndexDatabase? db;
  bool wasRecreated = false;
  String? storedVersion;

  for (var attempt = 1; attempt <= 2; attempt++) {
    try {
      db = TephraIndexDatabase(NativeDatabase(File(dbFile), setup: _setup));
      final rows = await db
          .customSelect(
            "SELECT value FROM index_meta WHERE key = 'parserVersion'",
          )
          .get();
      if (rows.isNotEmpty) {
        storedVersion = rows.first.read<String>('value');
      }
      break;
    } catch (e, st) {
      if (db != null) {
        try {
          await db.close();
        } catch (_) {}
        db = null;
      }
      if (attempt == 1) {
        _logger.warning('index database unreadable, recreating: $e', e, st);
        _deleteDbFiles(dbFile);
        wasRecreated = true;
      } else {
        throw IndexCorruptException(
          'Failed to open or recreate index database: $e',
        );
      }
    }
  }

  if (db == null) {
    throw const IndexCorruptException('Failed to open database');
  }

  final expectedVersion = TephraIndexDatabase.parserVersion.toString();
  final bool needsFullIndex =
      wasRecreated || storedVersion == null || storedVersion != expectedVersion;

  if (needsFullIndex &&
      storedVersion != null &&
      storedVersion != expectedVersion) {
    await db.wipeAll();
  }

  await db.customStatement(
    "INSERT OR REPLACE INTO index_meta(key, value) VALUES ('parserVersion', ?)",
    [expectedVersion],
  );

  return OpenedIndexDatabase(db, needsFullIndex: needsFullIndex);
}

/// Opens an in-memory database (tests, in-process runner).
Future<OpenedIndexDatabase> openMemoryIndexDatabase() async {
  _ensureSqliteInitialized();
  final db = TephraIndexDatabase(NativeDatabase.memory(setup: _setup));
  final expectedVersion = TephraIndexDatabase.parserVersion.toString();
  await db.customStatement(
    "INSERT OR REPLACE INTO index_meta(key, value) VALUES ('parserVersion', ?)",
    [expectedVersion],
  );
  return OpenedIndexDatabase(db, needsFullIndex: true);
}

/// Opens [dbFile] for reading from the UI isolate; SQLite runs in a drift background isolate.
TephraIndexDatabase openReaderIndexDatabase(String dbFile) {
  return TephraIndexDatabase(
    NativeDatabase.createInBackground(File(dbFile), setup: _readerSetup),
  );
}
