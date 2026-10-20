// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/core/platform/tray_service.dart';
import 'package:tephra/core/platform/window_service.dart';
import 'package:tephra/core/platform/windows_tray_service.dart';
import 'package:tephra/core/sync/sync_messages.dart';
import 'package:tephra/core/sync/tray_sync_coordinator.dart';
import 'package:tephra/l10n/app_localizations.dart';

class FakeTrayIconBackend implements TrayIconBackend {
  bool isVisible = false;
  String? tooltip;
  String? iconAsset;
  List<TrayMenuEntry> menuEntries = [];
  void Function(String id)? menuClickHandler;
  void Function()? iconClickHandler;
  bool isDisposed = false;

  @override
  void addClickListener(void Function() onClick) => iconClickHandler = onClick;

  @override
  void dispose() => isDisposed = true;

  @override
  void setIcon(String assetPath) => iconAsset = assetPath;

  @override
  void setMenu(
    List<TrayMenuEntry> entries,
    void Function(String id) onMenuClick,
  ) {
    menuEntries = List.of(entries);
    menuClickHandler = onMenuClick;
  }

  @override
  void setTooltip(String text) => tooltip = text;

  @override
  void setVisible(bool visible) => isVisible = visible;
}

class FakeWindowService implements WindowService {
  bool isShown = true;
  bool preventClose = false;
  bool isDestroyed = false;
  final StreamController<void> _closeEvents =
      StreamController<void>.broadcast();

  @override
  Future<void> destroy() async => isDestroyed = true;

  @override
  Future<void> hideMainWindow() async => isShown = false;

  @override
  Future<bool> isPreventClose() async => preventClose;

  @override
  Future<void> setPreventClose(bool prevent) async => preventClose = prevent;

  @override
  Future<void> showMainWindow() async => isShown = true;

  @override
  Stream<void> get windowCloseEvents => _closeEvents.stream;

  void simulateClose() => _closeEvents.add(null);
}

void main() {
  late FakeTrayIconBackend backend;
  late WindowsTrayService trayService;
  late FakeWindowService windowService;
  late AppLocalizations l10n;

  setUpAll(() {
    l10n = lookupAppLocalizations(const Locale('en'));
  });

  setUp(() {
    backend = FakeTrayIconBackend();
    trayService = WindowsTrayService(backend: backend);
    windowService = FakeWindowService();
  });

  tearDown(() async {
    await trayService.dispose();
  });

  group('WindowsTrayService', () {
    test('show, setTooltip, setMenu, hide and dispose', () async {
      await trayService.show(tooltip: 'Initial tooltip');
      expect(backend.isVisible, isTrue);
      expect(backend.tooltip, 'Initial tooltip');

      await trayService.setTooltip('Updated tooltip');
      expect(backend.tooltip, 'Updated tooltip');

      const entries = [
        TrayMenuItem(id: 'item1', label: 'Item 1'),
        TrayMenuSeparator(),
        TrayMenuItem(id: 'item2', label: 'Item 2', isEnabled: false),
      ];
      await trayService.setMenu(entries);
      expect(backend.menuEntries, entries);

      final menuClicks = <String>[];
      final sub = trayService.menuClicks.listen(menuClicks.add);

      backend.menuClickHandler?.call('item1');
      await pumpEventQueue();
      expect(menuClicks, ['item1']);
      await sub.cancel();

      final iconClicks = <void>[];
      final iconSub = trayService.iconClicks.listen(iconClicks.add);

      backend.iconClickHandler?.call();
      await pumpEventQueue();
      expect(iconClicks.length, 1);
      await iconSub.cancel();

      await trayService.hide();
      expect(backend.isVisible, isFalse);
    });
  });

  group('TraySyncCoordinator', () {
    test('formatTooltip returns correct localized strings per state', () {
      expect(
        TraySyncCoordinator.formatTooltip(state: SyncUiState.idle, l10n: l10n),
        'Tephra — Up to date',
      );

      expect(
        TraySyncCoordinator.formatTooltip(
          state: SyncUiState.syncing,
          syncingCount: 12,
          l10n: l10n,
        ),
        'Tephra — Syncing 12 files…',
      );

      expect(
        TraySyncCoordinator.formatTooltip(
          state: SyncUiState.offline,
          l10n: l10n,
        ),
        'Tephra — Offline',
      );

      expect(
        TraySyncCoordinator.formatTooltip(
          state: SyncUiState.needsAttention,
          l10n: l10n,
        ),
        'Tephra — Needs attention',
      );

      expect(
        TraySyncCoordinator.formatTooltip(state: SyncUiState.error, l10n: l10n),
        'Tephra — Needs attention',
      );
    });

    test('buildMenu reflects pause state', () {
      final menuUnpaused = TraySyncCoordinator.buildMenu(
        isPaused: false,
        l10n: l10n,
      );
      final pauseItem = menuUnpaused.whereType<TrayMenuItem>().firstWhere(
        (i) => i.id == 'tray.pause-toggle',
      );
      expect(pauseItem.label, 'Pause sync');

      final menuPaused = TraySyncCoordinator.buildMenu(
        isPaused: true,
        l10n: l10n,
      );
      final resumeItem = menuPaused.whereType<TrayMenuItem>().firstWhere(
        (i) => i.id == 'tray.pause-toggle',
      );
      expect(resumeItem.label, 'Resume sync');
    });

    test('menu click IDs map to coordinator actions', () async {
      var openCalled = false;
      var syncNowCalled = false;
      var togglePauseCalled = false;
      var quitCalled = false;
      int? exitCode;

      final coordinator = TraySyncCoordinator(
        trayService: trayService,
        windowService: windowService,
        onOpen: () => openCalled = true,
        onSyncNow: () => syncNowCalled = true,
        onTogglePause: () => togglePauseCalled = true,
        onQuit: () async => quitCalled = true,
        exitProcess: (code) async => exitCode = code,
      );

      await coordinator.updateStatus(
        state: SyncUiState.syncing,
        syncingCount: 5,
        isPaused: false,
        l10n: l10n,
      );
      expect(backend.tooltip, 'Tephra — Syncing 5 files…');

      // Click tray.open
      backend.menuClickHandler?.call('tray.open');
      await pumpEventQueue();
      expect(openCalled, isTrue);
      expect(windowService.isShown, isTrue);

      // Click tray.sync-now
      backend.menuClickHandler?.call('tray.sync-now');
      await pumpEventQueue();
      expect(syncNowCalled, isTrue);

      // Click tray.pause-toggle
      backend.menuClickHandler?.call('tray.pause-toggle');
      await pumpEventQueue();
      expect(togglePauseCalled, isTrue);

      // Click tray.quit
      backend.menuClickHandler?.call('tray.quit');
      await pumpEventQueue();
      expect(quitCalled, isTrue);
      expect(exitCode, 0);
      expect(windowService.isDestroyed, isTrue);
      expect(backend.isDisposed, isTrue);

      await coordinator.dispose();
    });

    test(
      'keepSyncingWhenClosed on: window close hides window instead of quitting',
      () async {
        var quitCalled = false;
        final coordinator = TraySyncCoordinator(
          trayService: trayService,
          windowService: windowService,
          onQuit: () async => quitCalled = true,
          exitProcess: (code) async {},
        );

        await coordinator.setKeepSyncingWhenClosed(true);
        expect(windowService.preventClose, isTrue);

        windowService.simulateClose();
        await pumpEventQueue();

        expect(windowService.isShown, isFalse);
        expect(quitCalled, isFalse);

        await coordinator.dispose();
      },
    );

    test('keepSyncingWhenClosed off: window close quits application', () async {
      var quitCalled = false;
      int? exitCode;

      final coordinator = TraySyncCoordinator(
        trayService: trayService,
        windowService: windowService,
        onQuit: () async => quitCalled = true,
        exitProcess: (code) async => exitCode = code,
      );

      await coordinator.setKeepSyncingWhenClosed(false);
      expect(windowService.preventClose, isFalse);

      windowService.simulateClose();
      await pumpEventQueue();

      expect(quitCalled, isTrue);
      expect(exitCode, 0);

      await coordinator.dispose();
    });
  });
}
