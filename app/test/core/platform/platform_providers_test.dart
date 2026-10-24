// © 2026 Tephra. All rights reserved.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/core/platform/app_shortcut_service.dart';
import 'package:tephra/core/platform/global_hotkey_service.dart';
import 'package:tephra/core/platform/home_widget_service.dart';
import 'package:tephra/core/platform/notification_service.dart';
import 'package:tephra/core/platform/overlay_service.dart';
import 'package:tephra/core/platform/share_intent_service.dart';
import 'package:tephra/core/platform/tray_service.dart';
import 'package:tephra/core/platform/window_service.dart';
import 'package:tephra/core/providers.dart';
import 'package:tephra/settings/app_settings.dart';
import 'package:tephra/settings/vault_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Platform services and providers', () {
    test('noop services never throw', () async {
      // 1. NotificationService
      const noopNotification = NoopNotificationService();
      await noopNotification.init();
      final permState = await noopNotification.permissionState();
      expect(permState.notifications, isTrue);
      expect(permState.exactAlarms, isTrue);
      expect(await noopNotification.requestNotificationPermission(), isTrue);
      expect(await noopNotification.requestExactAlarmPermission(), isTrue);
      await noopNotification.showNotification(
        id: 1,
        title: 'Title',
        body: 'Body',
        payload: 'payload',
      );
      await noopNotification.schedule(
        ScheduledReminder(
          id: 1,
          at: DateTime.utc(2026, 10, 24, 12, 0),
          title: 'Title',
          body: 'Body',
          payload: 'payload',
        ),
      );
      await noopNotification.cancel(1);
      await noopNotification.showQuickNoteNotification();
      await noopNotification.hideQuickNoteNotification();
      expect(await noopNotification.taps.toList(), isEmpty);
      expect(await noopNotification.launchPayload(), isNull);

      // 2. GlobalHotkeyService
      const noopHotkey = NoopGlobalHotkeyService();
      await noopHotkey.register('Ctrl+Alt+N', () {});
      await noopHotkey.unregisterAll();

      // 3. TrayService
      const noopTray = NoopTrayService();
      await noopTray.init(tooltip: 'Tephra');
      await noopTray.show(tooltip: 'Tephra');
      await noopTray.setTooltip('Tephra Tooltip');
      await noopTray.setMenu(const []);
      await noopTray.setActions(const []);
      expect(await noopTray.actions.toList(), isEmpty);
      expect(await noopTray.menuClicks.toList(), isEmpty);
      expect(await noopTray.iconClicks.toList(), isEmpty);
      await noopTray.hide();
      await noopTray.dispose();

      // 4. WindowService
      const noopWindow = NoopWindowService();
      await noopWindow.showMainWindow();
      await noopWindow.hideMainWindow();
      expect(await noopWindow.isLaunchAtStartupEnabled(), isFalse);
      await noopWindow.setLaunchAtStartup(true);
      await noopWindow.setPreventClose(true);
      expect(await noopWindow.isPreventClose(), isFalse);
      expect(await noopWindow.windowCloseEvents.toList(), isEmpty);
      await noopWindow.destroy();

      // 5. HomeWidgetService
      const noopHomeWidget = NoopHomeWidgetService();
      await noopHomeWidget.saveJson('key', {'a': 1});
      expect(await noopHomeWidget.readJson('key'), isNull);
      await noopHomeWidget.updateStickyWidgets();
      await noopHomeWidget.updateStackWidgets();
      await noopHomeWidget.updateCaptureWidgets();
      expect(await noopHomeWidget.installedStickyWidgetIds(), isEmpty);
      expect(await noopHomeWidget.widgetLaunches.toList(), isEmpty);
      expect(await noopHomeWidget.initialWidgetLaunch(), isNull);

      // 6. OverlayService
      const noopOverlay = NoopOverlayService();
      expect(await noopOverlay.hasPermission(), isFalse);
      expect(await noopOverlay.requestPermission(), isFalse);
      await noopOverlay.showBubble('Stickies/Test.md');
      await noopOverlay.closeBubble();
      expect(await noopOverlay.isActive(), isFalse);
      await noopOverlay.send({'action': 'ping'});
      expect(await noopOverlay.messages.toList(), isEmpty);

      // 7. ShareIntentService
      const noopShare = NoopShareIntentService();
      expect(await noopShare.initialShare(), isEmpty);
      expect(await noopShare.shares.toList(), isEmpty);
      await noopShare.markHandled();

      // 8. AppShortcutService
      const noopShortcut = NoopAppShortcutService();
      await noopShortcut.init((_) {});
    });

    test('settings defaults', () {
      final vault = VaultSettings.fromJson(const {});
      expect(vault.stickyFolder, 'Stickies');
      expect(vault.stickyDefaultColor, 'yellow');
      expect(vault.shareTarget, 'dailyNote');
      expect(vault.quickCaptureTarget, 'dailyNote');
      expect(vault.inboxNotePath, 'Inbox.md');

      final app = AppSettings.fromJson(
        const {},
        newDeviceId: () => 'default-device-uuid',
      );
      expect(app.stickiesRestoreOnStart, isTrue);
      expect(app.stickiesHiddenAll, isFalse);
      expect(app.stickiesMaxWindows, 20);
      expect(app.stickyHotkey, 'Ctrl+Alt+N');
      expect(app.startWithWindows, isFalse);
      expect(app.keepRunningInTray, isTrue);
      expect(app.quickNoteNotification, isFalse);
      expect(app.remindersEnabled, isTrue);
    });

    test('settings preserve unknown keys', () {
      final vaultJson = <String, Object?>{
        'x.unknown': 5,
        'stickies.folder': 'Notes/Sticky',
      };
      final vault = VaultSettings.fromJson(vaultJson);
      expect(vault.stickyFolder, 'Notes/Sticky');
      final reEncodedVault = vault.toJson();
      expect(reEncodedVault['x.unknown'], 5);
      expect(reEncodedVault['stickies.folder'], 'Notes/Sticky');

      final appJson = <String, Object?>{
        'x.unknown': 5,
        'stickies.folder': 'Notes/Sticky',
      };
      final app = AppSettings.fromJson(appJson, newDeviceId: () => 'dev-1');
      final reEncodedApp = app.toJson();
      expect(reEncodedApp['x.unknown'], 5);
      expect(reEncodedApp['stickies.folder'], 'Notes/Sticky');
    });

    test('providers resolve services without error', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(notificationServiceProvider), isNotNull);
      expect(container.read(globalHotkeyServiceProvider), isNotNull);
      expect(container.read(trayServiceProvider), isNotNull);
      expect(container.read(windowServiceProvider), isNotNull);
      expect(container.read(homeWidgetServiceProvider), isNotNull);
      expect(container.read(overlayServiceProvider), isNotNull);
      expect(container.read(shareIntentServiceProvider), isNotNull);
      expect(container.read(appShortcutServiceProvider), isNotNull);
    });
  });
}
