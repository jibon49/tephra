// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tephra/app.dart';
import 'package:tephra/core/json_file_store.dart';
import 'package:tephra/core/logging.dart';
import 'package:tephra/core/perf/perf_probe.dart';
import 'package:tephra/core/sync/background_sync.dart';
import 'package:tephra/core/uuid.dart';
import 'package:tephra/settings/app_settings.dart';
import 'package:tephra/settings/app_settings_store.dart';
import 'package:tephra/settings/providers.dart';
import 'package:window_manager/window_manager.dart';
import 'package:workmanager/workmanager.dart';

Future<void> main() async {
  PerfProbe.markAppStart();
  if (PerfProbe.enabled) {
    PerfProbe.installLogBridge();
    Logger.root.level = Level.ALL;
  }
  WidgetsFlutterBinding.ensureInitialized();
  await setupLogging();
  installCrashHandlers();

  if (!kIsWeb && Platform.isAndroid) {
    try {
      await Workmanager().initialize(tephraBackgroundDispatcher);
    } catch (e, st) {
      Logger('app').warning('Failed to initialize Workmanager', e, st);
    }
  }

  if (!kIsWeb && Platform.isWindows) {
    try {
      await windowManager.ensureInitialized();
    } catch (e, st) {
      Logger('app').warning('Failed to initialize windowManager', e, st);
    }
  }

  final AppSettings initial;
  final AppSettingsStore? store;

  if (kIsWeb) {
    initial = AppSettings(deviceId: generateUuidV4());
    store = null;
  } else {
    final dir = await getApplicationSupportDirectory();
    final file = AppJsonFile(File(p.join(dir.path, 'settings.json')));
    store = AppSettingsStore(file);
    initial = store.load();
  }

  Logger('app').info('Tephra starting');
  Logger('app').info('device ${initial.deviceId.substring(0, 8)}…');

  runApp(
    ProviderScope(
      overrides: [
        initialAppSettingsProvider.overrideWithValue(initial),
        if (store != null) appSettingsStoreProvider.overrideWithValue(store),
      ],
      child: const TephraApp(),
    ),
  );
}
