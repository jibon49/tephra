// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notification_service.dart';
import 'storage_permission_service.dart';
import 'system_trash_windows.dart';
import 'tray_service.dart';
import 'window_service.dart';
import 'windows_tray_service.dart';

final storagePermissionServiceProvider = Provider<StoragePermissionService>(
  (ref) => (!kIsWeb && Platform.isAndroid)
      ? AndroidStoragePermissionService()
      : const NoopStoragePermissionService(),
);

final windowsSystemTrashProvider = Provider<WindowsSystemTrash?>(
  (ref) => (!kIsWeb && Platform.isWindows) ? WindowsSystemTrash() : null,
);

final trayServiceProvider = Provider<TrayService>((ref) {
  if (!kIsWeb && Platform.isWindows) {
    final service = WindowsTrayService();
    ref.onDispose(() => service.dispose());
    return service;
  }
  return const NoopTrayService();
});

final windowServiceProvider = Provider<WindowService>((ref) {
  if (!kIsWeb && Platform.isWindows) {
    final service = WindowsWindowService();
    ref.onDispose(() => service.destroy());
    return service;
  }
  return const NoopWindowService();
});

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => const NoopNotificationService(),
);
