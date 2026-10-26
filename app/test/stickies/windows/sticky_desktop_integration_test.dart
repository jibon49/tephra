// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/core/platform/global_hotkey_service.dart';
import 'package:tephra/core/platform/tray_service.dart';
import 'package:tephra/core/platform/window_service.dart';
import 'package:tephra/settings/app_settings.dart';
import 'package:tephra/stickies/data/sticky_positions_store.dart';
import 'package:tephra/stickies/data/sticky_repository.dart';
import 'package:tephra/stickies/model/sticky.dart';
import 'package:tephra/stickies/model/sticky_color.dart';
import 'package:tephra/stickies/model/sticky_meta.dart';
import 'package:tephra/stickies/windows/sticky_desktop_integration.dart';
import 'package:tephra/stickies/windows/sticky_hub.dart';
import 'package:tephra/stickies/windows/text_merger.dart';
import 'package:tephra/stickies/windows/window_bus.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../fakes.dart';

class MockGlobalHotkeyService implements GlobalHotkeyService {
  String? registeredAccelerator;
  void Function()? onPressedHandler;
  int unregisterAllCalls = 0;

  @override
  Future<void> register(String accelerator, void Function() onPressed) async {
    registeredAccelerator = accelerator;
    onPressedHandler = onPressed;
  }

  @override
  Future<void> unregisterAll() async {
    unregisterAllCalls++;
    registeredAccelerator = null;
    onPressedHandler = null;
  }

  void trigger() => onPressedHandler?.call();
}

class MockTrayService implements TrayService {
  final StreamController<TrayAction> _actionsController =
      StreamController<TrayAction>.broadcast();
  final StreamController<void> _iconClicksController =
      StreamController<void>.broadcast();
  final StreamController<String> _menuClicksController =
      StreamController<String>.broadcast();

  String? currentTooltip;
  List<TrayMenuEntry> currentMenu = [];
  bool isVisible = false;
  bool isDisposed = false;

  @override
  Stream<TrayAction> get actions => _actionsController.stream;

  @override
  Stream<void> get iconClicks => _iconClicksController.stream;

  @override
  Stream<String> get menuClicks => _menuClicksController.stream;

  @override
  Future<void> init({required String tooltip}) async {
    currentTooltip = tooltip;
    isVisible = true;
  }

  @override
  Future<void> show({required String tooltip}) async {
    currentTooltip = tooltip;
    isVisible = true;
  }

  @override
  Future<void> hide() async {
    isVisible = false;
  }

  @override
  Future<void> setTooltip(String text) async {
    currentTooltip = text;
  }

  @override
  Future<void> setMenu(List<TrayMenuEntry> entries) async {
    currentMenu = entries;
  }

  @override
  Future<void> setActions(List<TrayAction> actions) async {}

  @override
  Future<void> dispose() async {
    isDisposed = true;
    await _actionsController.close();
    await _iconClicksController.close();
    await _menuClicksController.close();
  }

  void sendAction(TrayAction action) => _actionsController.add(action);
  void clickIcon() => _iconClicksController.add(null);
}

class MockWindowService implements WindowService {
  bool isShown = true;
  bool isDestroyed = false;
  bool preventClose = false;
  final StreamController<void> _closeEvents =
      StreamController<void>.broadcast();

  @override
  Future<void> showMainWindow() async => isShown = true;

  @override
  Future<void> hideMainWindow() async => isShown = false;

  @override
  Future<void> destroy() async => isDestroyed = true;

  @override
  Future<bool> isPreventClose() async => preventClose;

  @override
  Future<void> setPreventClose(bool prevent) async => preventClose = prevent;

  @override
  Future<bool> isLaunchAtStartupEnabled() async => false;

  @override
  Future<void> setLaunchAtStartup(bool enabled) async {}

  @override
  Stream<void> get windowCloseEvents => _closeEvents.stream;

  void triggerClose() => _closeEvents.add(null);
}

class MockStickyHub extends StickyHub {
  MockStickyHub({
    required super.bus,
    required super.repo,
    required super.openNotes,
    required super.merger,
    required super.positions,
    required super.conflictNamer,
    required super.clock,
    this.onCloseAllForQuit,
  });

  final void Function()? onCloseAllForQuit;
  final List<VaultPath> openedPaths = [];
  final List<bool> openedFocusEdit = [];
  int showAllCalls = 0;
  int hideAllCalls = 0;
  int closeAllForQuitCalls = 0;

  @override
  Future<void> open(VaultPath path, {bool focusEdit = false}) async {
    openedPaths.add(path);
    openedFocusEdit.add(focusEdit);
  }

  @override
  Future<void> showAll({int? maxWindows}) async {
    showAllCalls++;
  }

  @override
  Future<void> hideAll() async {
    hideAllCalls++;
  }

  @override
  Future<void> closeAllForQuit() async {
    closeAllForQuitCalls++;
    onCloseAllForQuit?.call();
  }
}

class MockStickyPositionsStore extends StickyPositionsStore {
  MockStickyPositionsStore({
    required super.fs,
    required super.deviceId,
    this.onFlush,
  });

  final void Function()? onFlush;
  int flushCalls = 0;

  @override
  Future<void> flush() async {
    flushCalls++;
    onFlush?.call();
  }
}

class MockStickyRepository extends StickyRepository {
  MockStickyRepository({
    required super.fs,
    required super.search,
    required super.settings,
    required super.openNotes,
    required super.clock,
  });

  int nextId = 1;
  final List<Sticky> createdStickies = [];

  @override
  Future<Sticky> create({String body = '', StickyColor? color}) async {
    final path = VaultPath('Stickies/Sticky $nextId.md');
    nextId++;
    final sticky = Sticky(
      path: path,
      text: body,
      meta: StickyMeta(
        isSticky: true,
        color: color ?? const NamedStickyColor(StickyColorName.yellow),
      ),
      hash: 'hash-$nextId',
      modified: DateTime(2026, 10, 26),
    );
    createdStickies.add(sticky);
    return sticky;
  }
}

void main() {
  group('StickyDesktopIntegration', () {
    late MockGlobalHotkeyService hotkeyService;
    late MockTrayService trayService;
    late MockWindowService windowService;
    late MemoryVaultFileSystem fs;
    late FakeOpenNoteBridge openNotes;
    late MockStickyRepository repo;
    late MockStickyPositionsStore positionsStore;
    late MockStickyHub hub;
    late List<String> eventLog;
    late StickyDesktopIntegration integration;

    setUp(() async {
      eventLog = [];
      hotkeyService = MockGlobalHotkeyService();
      trayService = MockTrayService();
      windowService = MockWindowService();

      fs = MemoryVaultFileSystem();
      openNotes = FakeOpenNoteBridge();
      repo = MockStickyRepository(
        fs: fs,
        search: null,
        settings: const StickySettingsView(
          stickyFolder: 'Stickies',
          defaultColor: NamedStickyColor(StickyColorName.yellow),
        ),
        openNotes: openNotes,
        clock: SystemClock(),
      );

      positionsStore = MockStickyPositionsStore(
        fs: fs,
        deviceId: 'dev1',
        onFlush: () {
          eventLog.add('positions.flush');
        },
      );

      hub = MockStickyHub(
        bus: const NoopWindowBus(),
        repo: repo,
        openNotes: openNotes,
        merger: const SyncTextMerger(),
        positions: positionsStore,
        conflictNamer: (path) => path,
        clock: SystemClock(),
        onCloseAllForQuit: () {
          eventLog.add('hub.closeAllForQuit');
        },
      );

      integration = StickyDesktopIntegration(
        globalHotkeyService: hotkeyService,
        trayService: trayService,
        stickyHub: hub,
        stickyRepository: repo,
        stickyPositionsStore: positionsStore,
        windowService: windowService,
        appSettings: const AppSettings(
          deviceId: 'desktop_test',
          stickyHotkey: 'Ctrl+Alt+N',
          keepRunningInTray: true,
        ),
        onFlushOpenDocuments: () async {
          eventLog.add('documents.flush');
        },
        exitProcess: (code) async {
          eventLog.add('exitProcess');
        },
      );

      await integration.init();
    });

    tearDown(() async {
      await integration.dispose();
      openNotes.dispose();
    });

    test('hotkey creates and opens sticky with focusEdit', () async {
      expect(hotkeyService.registeredAccelerator, 'Ctrl+Alt+N');

      hotkeyService.trigger();
      // Allow async create + open to complete
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(hub.openedPaths.length, 1);
      expect(hub.openedPaths.first.value, startsWith('Stickies/'));
      expect(hub.openedFocusEdit.first, isTrue);
    });

    test('tray show/hide call hub', () async {
      trayService.sendAction(TrayAction.showAllStickies);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(hub.showAllCalls, 1);

      trayService.sendAction(TrayAction.hideAllStickies);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(hub.hideAllCalls, 1);

      trayService.sendAction(TrayAction.newSticky);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(hub.openedPaths.length, 1);
      expect(hub.openedFocusEdit.first, isTrue);

      trayService.sendAction(TrayAction.openTephra);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(windowService.isShown, isTrue);
    });

    test('tray icon click brings main window to front', () async {
      windowService.isShown = false;
      trayService.clickIcon();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(windowService.isShown, isTrue);
    });

    test(
      'window close event minimizes to tray when keepRunningInTray is true',
      () async {
        windowService.isShown = true;
        windowService.triggerClose();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(windowService.isShown, isFalse);
        expect(eventLog, isEmpty); // Did not quit
      },
    );

    test('quit flushes before exit in strict required order', () async {
      await integration.quit();

      expect(eventLog, [
        'hub.closeAllForQuit',
        'positions.flush',
        'documents.flush',
        'exitProcess',
      ]);
      expect(trayService.isDisposed, isTrue);
      expect(windowService.isDestroyed, isTrue);
    });
  });
}
