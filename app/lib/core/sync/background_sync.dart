// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:workmanager/workmanager.dart';

import 'headless_sync_runner.dart';

final _log = Logger('sync.background');

/// Top-level background dispatcher invoked by the native WorkManager engine on Android.
@pragma('vm:entry-point')
void tephraBackgroundDispatcher() {
  Workmanager().executeTask((String task, Map<String, dynamic>? input) async {
    WidgetsFlutterBinding.ensureInitialized();
    return HeadlessSyncRunner().runAll(budget: const Duration(minutes: 8));
  });
}

/// Helper for scheduling and cancelling periodic background synchronization on Android.
final class BackgroundSyncScheduler {
  static const String uniqueName = 'tephra-sync-periodic';
  static const String taskName = 'tephraSync';

  /// Applies scheduling according to [enabled] and network/charging constraints.
  static Future<void> apply({
    required bool enabled,
    bool wifiOnly = false,
    bool chargingOnly = false,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;

    try {
      if (enabled) {
        await Workmanager().registerPeriodicTask(
          uniqueName,
          taskName,
          frequency: const Duration(minutes: 15),
          constraints: Constraints(
            networkType: wifiOnly
                ? NetworkType.unmetered
                : NetworkType.connected,
            requiresCharging: chargingOnly,
            requiresBatteryNotLow: true,
          ),
          existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
          backoffPolicy: BackoffPolicy.exponential,
          backoffPolicyDelay: const Duration(minutes: 5),
        );
        _log.info(
          'Registered periodic WorkManager task (wifiOnly: $wifiOnly, chargingOnly: $chargingOnly)',
        );
      } else {
        await Workmanager().cancelByUniqueName(uniqueName);
        _log.info('Cancelled periodic WorkManager task');
      }
    } catch (e, st) {
      _log.warning('Failed to update WorkManager periodic schedule', e, st);
    }
  }
}
