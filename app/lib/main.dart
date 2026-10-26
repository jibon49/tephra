// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:home_widget/home_widget.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tephra/app.dart';
import 'package:tephra/core/json_file_store.dart';
import 'package:tephra/core/logging.dart';
import 'package:tephra/core/perf/perf_probe.dart';
import 'package:tephra/core/providers.dart';
import 'package:tephra/core/sync/background_sync.dart';
import 'package:tephra/core/uuid.dart';
import 'package:tephra/settings/app_settings.dart';
import 'package:tephra/settings/app_settings_store.dart';
import 'package:tephra/settings/providers.dart';
import 'package:tephra/stickies/android/widget_callback.dart';
import 'package:tephra/stickies/providers.dart';
import 'package:tephra/stickies/windows/sticky_protocol.dart';
import 'package:tephra/stickies/windows/sticky_window_main.dart';
import 'package:tephra/stickies/windows/window_bus.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:window_manager/window_manager.dart';
import 'package:workmanager/workmanager.dart';

Future<void> main(List<String> args) async {
  PerfProbe.markAppStart();
  if (PerfProbe.enabled) {
    PerfProbe.installLogBridge();
    Logger.root.level = Level.ALL;
  }
  WidgetsFlutterBinding.ensureInitialized();
  await setupLogging();
  installCrashHandlers();

  final isAutostart = args.contains('--autostart');

  if (!kIsWeb && Platform.isWindows) {
    try {
      final controller = await WindowController.fromCurrentEngine();
      final stickyArgs = StickyWindowArgs.tryDecode(controller.arguments);
      if (stickyArgs != null) {
        await runStickyWindow(controller, stickyArgs);
        return;
      }
    } catch (e, st) {
      Logger('app').warning('Failed to query multi-window engine', e, st);
    }
  }

  if (!kIsWeb && Platform.isAndroid) {
    try {
      await Workmanager().initialize(tephraBackgroundDispatcher);
    } catch (e, st) {
      Logger('app').warning('Failed to initialize Workmanager', e, st);
    }
    try {
      await HomeWidget.registerInteractivityCallback(stickyWidgetCallback);
    } catch (e, st) {
      Logger(
        'app',
      ).warning('Failed to register HomeWidget interactivity callback', e, st);
    }
  }

  if (!kIsWeb && Platform.isWindows) {
    try {
      await windowManager.ensureInitialized();
      if (isAutostart) {
        await windowManager.hide();
      }
    } catch (e, st) {
      Logger('app').warning('Failed to initialize windowManager', e, st);
    }
  }

  WindowBus? windowBus;
  if (!kIsWeb && Platform.isWindows) {
    try {
      windowBus = await DesktopWindowBus.fromCurrentEngine();
    } catch (e, st) {
      Logger('app').warning('Failed to initialize DesktopWindowBus', e, st);
    }
  }

  final AppSettings initial;
  final AppSettingsStore? store;
  Directory? appSupportDir;

  tz.initializeTimeZones();
  if (!kIsWeb) {
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      Logger('app')
          .warning('Failed to load local time zone ($e); falling back to UTC');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }

  if (kIsWeb) {
    initial = AppSettings(deviceId: generateUuidV4());
    store = null;
  } else {
    final dir = await getApplicationSupportDirectory();
    appSupportDir = dir;
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
        if (windowBus != null) windowBusProvider.overrideWithValue(windowBus),
        if (appSupportDir != null)
          appSupportDirectoryProvider.overrideWithValue(appSupportDir),
      ],
      child: const TephraApp(),
    ),
  );
}
