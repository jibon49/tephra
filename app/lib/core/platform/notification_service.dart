// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Top-level background notification response handler (used by quick replies in step 04.16).
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // Handled in step 04.16 for quick replies.
}

/// Permission state for system notifications and exact alarms.
final class NotificationPermissionState {
  const NotificationPermissionState({
    required this.notifications,
    required this.exactAlarms,
  });

  final bool notifications;
  final bool exactAlarms;
}

/// A scheduled reminder notification.
final class ScheduledReminder {
  const ScheduledReminder({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
    required this.payload,
  });

  final int id;
  final DateTime at;
  final String title;
  final String body;
  final String payload;
}

/// Platform service for showing and scheduling notifications.
abstract interface class NotificationService {
  Future<void> init();
  Future<NotificationPermissionState> permissionState();
  Future<bool> requestNotificationPermission();
  Future<bool> requestExactAlarmPermission();
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  });
  Future<void> schedule(ScheduledReminder reminder);
  Future<void> cancel(int id);
  Future<void> showQuickNoteNotification();
  Future<void> hideQuickNoteNotification();
  Stream<String> get taps;
  Future<String?> launchPayload();
}

/// No-op implementation of [NotificationService] for unsupported platforms or headless runs.
class NoopNotificationService implements NotificationService {
  const NoopNotificationService();

  @override
  Future<void> init() async {}

  @override
  Future<NotificationPermissionState> permissionState() async =>
      const NotificationPermissionState(notifications: true, exactAlarms: true);

  @override
  Future<bool> requestNotificationPermission() async => true;

  @override
  Future<bool> requestExactAlarmPermission() async => true;

  @override
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {}

  @override
  Future<void> schedule(ScheduledReminder reminder) async {}

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> showQuickNoteNotification() async {}

  @override
  Future<void> hideQuickNoteNotification() async {}

  @override
  Stream<String> get taps => const Stream.empty();

  @override
  Future<String?> launchPayload() async => null;
}

/// Windows implementation of [NotificationService].
class WindowsNotificationService implements NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<String> _taps = StreamController<String>.broadcast();
  bool _initialized = false;

  @override
  Future<void> init() async {
    if (_initialized) return;
    const initSettings = InitializationSettings(
      windows: WindowsInitializationSettings(
        appName: 'Tephra',
        appUserModelId: 'com.tephra.app',
        guid: 'b6f1c7e2-4a8d-4f3e-9c51-2d7a6e0f9b13',
      ),
    );
    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          _taps.add(payload);
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
    _initialized = true;
  }

  @override
  Future<NotificationPermissionState> permissionState() async =>
      const NotificationPermissionState(notifications: true, exactAlarms: true);

  @override
  Future<bool> requestNotificationPermission() async => true;

  @override
  Future<bool> requestExactAlarmPermission() async => true;

  @override
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) await init();
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        windows: WindowsNotificationDetails(),
      ),
      payload: payload,
    );
  }

  @override
  Future<void> schedule(ScheduledReminder reminder) async {
    if (!_initialized) await init();
    await _plugin.zonedSchedule(
      id: reminder.id,
      title: reminder.title,
      body: reminder.body,
      scheduledDate: tz.TZDateTime.from(reminder.at, tz.UTC),
      notificationDetails: const NotificationDetails(
        windows: WindowsNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: reminder.payload,
    );
  }

  @override
  Future<void> cancel(int id) async {
    if (!_initialized) await init();
    await _plugin.cancel(id: id);
  }

  @override
  Future<void> showQuickNoteNotification() async {}

  @override
  Future<void> hideQuickNoteNotification() async {}

  @override
  Stream<String> get taps => _taps.stream;

  @override
  Future<String?> launchPayload() async {
    if (!_initialized) await init();
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details != null && details.didNotificationLaunchApp) {
      return details.notificationResponse?.payload;
    }
    return null;
  }
}

/// Android implementation of [NotificationService].
class AndroidNotificationService implements NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<String> _taps = StreamController<String>.broadcast();
  bool _initialized = false;

  @override
  Future<void> init() async {
    if (_initialized) return;
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@drawable/ic_stat_tephra'),
    );
    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          _taps.add(payload);
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
    _initialized = true;
  }

  @override
  Future<NotificationPermissionState> permissionState() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final notifs = await android?.areNotificationsEnabled() ?? false;
    final exact = await android?.canScheduleExactNotifications() ?? false;
    return NotificationPermissionState(
      notifications: notifs,
      exactAlarms: exact,
    );
  }

  @override
  Future<bool> requestNotificationPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? false;
  }

  @override
  Future<bool> requestExactAlarmPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestExactAlarmsPermission() ?? false;
  }

  @override
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) await init();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'reminders',
        'Reminders',
        channelDescription: 'Sticky note reminder notifications',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@drawable/ic_stat_tephra',
      ),
    );
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  @override
  Future<void> schedule(ScheduledReminder reminder) async {
    if (!_initialized) await init();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final exact = await android?.canScheduleExactNotifications() ?? true;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'reminders',
        'Reminders',
        channelDescription: 'Sticky note reminder notifications',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@drawable/ic_stat_tephra',
      ),
    );

    await _plugin.zonedSchedule(
      id: reminder.id,
      title: reminder.title,
      body: reminder.body,
      scheduledDate: tz.TZDateTime.from(reminder.at, tz.UTC),
      notificationDetails: details,
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: reminder.payload,
    );
  }

  @override
  Future<void> cancel(int id) async {
    if (!_initialized) await init();
    await _plugin.cancel(id: id);
  }

  @override
  Future<void> showQuickNoteNotification() {
    throw UnimplementedError(
      'AndroidNotificationService.showQuickNoteNotification will be implemented in step 04.16',
    );
  }

  @override
  Future<void> hideQuickNoteNotification() {
    throw UnimplementedError(
      'AndroidNotificationService.hideQuickNoteNotification will be implemented in step 04.16',
    );
  }

  @override
  Stream<String> get taps => _taps.stream;

  @override
  Future<String?> launchPayload() async {
    if (!_initialized) await init();
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details != null && details.didNotificationLaunchApp) {
      return details.notificationResponse?.payload;
    }
    return null;
  }
}
