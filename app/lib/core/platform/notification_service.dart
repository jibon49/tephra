// © 2026 Tephra. All rights reserved.

import 'dart:async';

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
