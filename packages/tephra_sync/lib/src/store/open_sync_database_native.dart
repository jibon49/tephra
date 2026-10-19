// © 2026 Tephra. All rights reserved.

import 'dart:ffi';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'sync_database.dart';

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

void _setup(sqlite.Database raw) {
  raw.execute('PRAGMA journal_mode = WAL');
  raw.execute('PRAGMA synchronous = NORMAL');
  raw.execute('PRAGMA foreign_keys = ON');
  raw.execute('PRAGMA busy_timeout = 5000');
}

/// Opens a file-backed sync database.
Future<TephraSyncDatabase> openSyncDatabase(String dbFile) async {
  _ensureSqliteInitialized();
  Directory(p.dirname(dbFile)).createSync(recursive: true);
  return TephraSyncDatabase(NativeDatabase(File(dbFile), setup: _setup));
}

/// Opens an in-memory sync database for testing.
Future<TephraSyncDatabase> openMemorySyncDatabase() async {
  _ensureSqliteInitialized();
  return TephraSyncDatabase(NativeDatabase.memory(setup: _setup));
}
