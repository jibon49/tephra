// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_shortcut_service.dart';
import 'global_hotkey_service.dart';
import 'home_widget_service.dart';
import 'notification_service.dart';
import 'overlay_service.dart';
import 'share_intent_service.dart';
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

final notificationServiceProvider = Provider<NotificationService>((ref) {
  if (kIsWeb) return const NoopNotificationService();
  if (Platform.isWindows) return WindowsNotificationService();
  if (Platform.isAndroid) return AndroidNotificationService();
  return const NoopNotificationService();
});

final globalHotkeyServiceProvider = Provider<GlobalHotkeyService>((ref) {
  if (kIsWeb) return const NoopGlobalHotkeyService();
  if (Platform.isWindows) return WindowsGlobalHotkeyService();
  return const NoopGlobalHotkeyService();
});

final homeWidgetServiceProvider = Provider<HomeWidgetService>((ref) {
  if (kIsWeb) return const NoopHomeWidgetService();
  if (Platform.isAndroid) return AndroidHomeWidgetService();
  return const NoopHomeWidgetService();
});

final overlayServiceProvider = Provider<OverlayService>((ref) {
  if (kIsWeb) return const NoopOverlayService();
  if (Platform.isAndroid) return AndroidOverlayService();
  return const NoopOverlayService();
});

final shareIntentServiceProvider = Provider<ShareIntentService>((ref) {
  if (kIsWeb) return const NoopShareIntentService();
  if (Platform.isAndroid) return AndroidShareIntentService();
  return const NoopShareIntentService();
});

final appShortcutServiceProvider = Provider<AppShortcutService>((ref) {
  if (kIsWeb) return const NoopAppShortcutService();
  if (Platform.isAndroid) return AndroidAppShortcutService();
  return const NoopAppShortcutService();
});
