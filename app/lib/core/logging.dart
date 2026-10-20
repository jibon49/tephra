// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// The log sink lives for the whole app lifetime; the OS closes it at process exit.
// ignore: close_sinks
IOSink? _logSink;

// App-lifetime subscription; cancelled implicitly at process exit. Retained so it is not garbage collected.
// ignore: cancel_subscriptions, unused_element
StreamSubscription<LogRecord>? _logSubscription;

/// Formats one log record as a single line (plus error/stack lines when present).
String formatLogRecord(LogRecord record) {
  final buffer = StringBuffer(
    '${record.time.toIso8601String()} ${record.level.name.padRight(7)} ${record.loggerName}: ${record.message}',
  );
  if (record.error != null) {
    buffer.write('\n  error: ${record.error}');
  }
  if (record.stackTrace != null) {
    buffer.write('\n${record.stackTrace}');
  }
  return buffer.toString();
}

/// Rotates `<dir>/tephra.log` when it is larger than [maxBytes]:
/// tephra.3.log→tephra.4.log (old tephra.4.log deleted), 2→3, 1→2, tephra.log→tephra.1.log.
Future<void> rotateLogs(
  Directory dir, {
  int maxBytes = 2 * 1024 * 1024,
  int keep = 4,
}) async {
  final activeFile = File(p.join(dir.path, 'tephra.log'));
  if (!activeFile.existsSync() || await activeFile.length() <= maxBytes) {
    return;
  }
  final oldestFile = File(p.join(dir.path, 'tephra.$keep.log'));
  if (oldestFile.existsSync()) {
    await oldestFile.delete();
  }
  for (var i = keep - 1; i >= 1; i--) {
    final current = File(p.join(dir.path, 'tephra.$i.log'));
    if (current.existsSync()) {
      final next = File(p.join(dir.path, 'tephra.${i + 1}.log'));
      await current.rename(next.path);
    }
  }
  await activeFile.rename(p.join(dir.path, 'tephra.1.log'));
}

/// Sets levels, prints every record to stdout and (on non-web platforms) appends it to
/// `<appSupportDir>/logs/tephra.log`. Call once, before runApp.
Future<void> setupLogging() async {
  Logger.root.level = kDebugMode ? Level.ALL : Level.INFO;
  _logSubscription = Logger.root.onRecord.listen((record) {
    final line = formatLogRecord(record);
    // Logs must reach stdout so Dev Launcher and flutter run show them; package:logging has no sink of its own.
    print(line); // ignore: avoid_print
    _logSink?.writeln(line);
  });

  if (!kIsWeb) {
    try {
      final appSupportDir = await getApplicationSupportDirectory();
      final logsDir = Directory(p.join(appSupportDir.path, 'logs'));
      if (!logsDir.existsSync()) {
        logsDir.createSync(recursive: true);
      }
      await rotateLogs(logsDir);
      final logFile = File(p.join(logsDir.path, 'tephra.log'));
      _logSink = logFile.openWrite(mode: FileMode.append);
    } catch (e, st) {
      Logger('logging').warning('Failed to initialize file logging', e, st);
    }
  }
}

/// Sets up logging for headless background runs (appends to rotating log file without stdout prints).
Future<void> setupHeadlessLogging({Directory? appSupportDir}) async {
  if (_logSink != null) return;
  Logger.root.level = kDebugMode ? Level.ALL : Level.INFO;
  _logSubscription ??= Logger.root.onRecord.listen((record) {
    final line = formatLogRecord(record);
    _logSink?.writeln(line);
  });

  if (!kIsWeb) {
    try {
      final dir = appSupportDir ?? await getApplicationSupportDirectory();
      final logsDir = Directory(p.join(dir.path, 'logs'));
      if (!logsDir.existsSync()) {
        logsDir.createSync(recursive: true);
      }
      await rotateLogs(logsDir);
      final logFile = File(p.join(logsDir.path, 'tephra.log'));
      _logSink = logFile.openWrite(mode: FileMode.append);
    } catch (e, st) {
      Logger('logging')
          .warning('Failed to initialize headless file logging', e, st);
    }
  }
}

/// Routes FlutterError.onError and PlatformDispatcher.instance.onError to Logger('crash').
void installCrashHandlers() {
  final log = Logger('crash');
  FlutterError.onError = (details) {
    log.severe(details.exceptionAsString(), details.exception, details.stack);
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    log.severe('Uncaught error', error, stack);
    return true;
  };
}
