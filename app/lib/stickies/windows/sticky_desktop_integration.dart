// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:tephra_core/tephra_core.dart';

import '../../core/platform/global_hotkey_service.dart';
import '../../core/platform/tray_service.dart';
import '../../core/platform/window_service.dart';
import '../../core/platform/windows_tray_service.dart';
import '../../l10n/app_localizations.dart';
import '../../settings/app_settings.dart';
import '../../settings/vault_settings.dart';
import '../../vault/note_document_store.dart';
import '../data/sticky_positions_store.dart';
import '../data/sticky_repository.dart';
import 'sticky_hub.dart';

final _log = Logger('stickies.desktop');

/// Manages desktop system-level integrations on Windows:
/// - Global hotkey (default `Ctrl+Alt+N`) for quick capture
/// - System tray menu and icon interactions
/// - Main window close handling (minimize to tray vs graceful quit)
/// - Safe multi-stage quit flushing
class StickyDesktopIntegration {
  StickyDesktopIntegration({
    required this.globalHotkeyService,
    required this.trayService,
    required this.stickyHub,
    required this.stickyRepository,
    required this.stickyPositionsStore,
    required this.windowService,
    this.noteDocumentStore,
    this.onFlushOpenDocuments,
    this.appSettings,
    this.vaultSettings,
    this.onQuit,
    this.onNotice,
    Future<void> Function(int code)? exitProcess,
  }) : _exitProcess = exitProcess ?? _defaultExit;

  final GlobalHotkeyService globalHotkeyService;
  final TrayService trayService;
  final StickyHub stickyHub;
  final StickyRepository stickyRepository;
  final StickyPositionsStore stickyPositionsStore;
  final WindowService windowService;
  final NoteDocumentStore? noteDocumentStore;
  final Future<void> Function()? onFlushOpenDocuments;
  final AppSettings? appSettings;
  final VaultSettings? vaultSettings;
  final Future<void> Function()? onQuit;
  final void Function(String notice)? onNotice;
  final Future<void> Function(int code) _exitProcess;

  static Future<void> _defaultExit(int code) async {
    exit(code);
  }

  StreamSubscription<TrayAction>? _trayActionSub;
  StreamSubscription<void>? _iconClickSub;
  StreamSubscription<void>? _windowCloseSub;
  bool _initialized = false;

  bool get isInitialized => _initialized;

  /// Initializes tray icon, global hotkey, and window close handlers.
  Future<void> init({AppLocalizations? l10n}) async {
    if (_initialized) return;
    _initialized = true;

    // 1. Initialize tray icon & tooltip & menu
    await trayService.init(tooltip: 'Tephra');
    if (l10n != null) {
      final menuEntries = WindowsTrayService.buildDefaultEntries(l10n);
      await trayService.setMenu(menuEntries);
    } else {
      await trayService.setActions(const [
        TrayAction.newSticky,
        TrayAction.showAllStickies,
        TrayAction.hideAllStickies,
        TrayAction.openTephra,
        TrayAction.quit,
      ]);
    }

    // 2. Wire tray subscriptions
    _trayActionSub = trayService.actions.listen((action) {
      unawaited(_handleTrayAction(action));
    });

    _iconClickSub = trayService.iconClicks.listen((_) {
      unawaited(windowService.showMainWindow());
    });

    // 3. Register global hotkey
    final hotkey = appSettings?.stickyHotkey ?? 'Ctrl+Alt+N';
    await globalHotkeyService.register(hotkey, () {
      unawaited(createNewSticky());
    });

    // 4. Configure window close behavior
    final keepRunning = appSettings?.keepRunningInTray ?? true;
    await windowService.setPreventClose(keepRunning);
    _windowCloseSub = windowService.windowCloseEvents.listen((_) {
      unawaited(handleWindowClose());
    });
  }

  /// Creates a new sticky note in the vault and opens it focused in edit mode.
  Future<VaultPath?> createNewSticky() async {
    try {
      final sticky = await stickyRepository.create();
      await stickyHub.open(sticky.path, focusEdit: true);
      return sticky.path;
    } catch (e, st) {
      _log.warning('Failed to create new sticky from hotkey/tray', e, st);
      return null;
    }
  }

  Future<void> _handleTrayAction(TrayAction action) async {
    switch (action) {
      case TrayAction.newSticky:
        await createNewSticky();
      case TrayAction.showAllStickies:
        await stickyHub.showAll();
      case TrayAction.hideAllStickies:
        await stickyHub.hideAll();
      case TrayAction.openTephra:
        await windowService.showMainWindow();
      case TrayAction.quit:
        await quit();
    }
  }

  /// Handles main window close event: hides window if keepRunningInTray, else quits.
  Future<void> handleWindowClose() async {
    final keepRunning = appSettings?.keepRunningInTray ?? true;
    if (keepRunning) {
      await windowService.hideMainWindow();
    } else {
      await quit();
    }
  }

  /// Gracefully closes all sticky windows, flushes positions & open documents,
  /// hides tray, destroys window, and terminates process.
  Future<void> quit() async {
    _log.info('Quitting application: starting shutdown sequence...');
    // 1. Close all sticky windows for quit (keeps geometry in stickies.json)
    try {
      await stickyHub.closeAllForQuit();
    } catch (e, st) {
      _log.warning('Error closing sticky windows for quit', e, st);
    }

    // 2. Flush sticky positions store
    try {
      await stickyPositionsStore.flush();
    } catch (e, st) {
      _log.warning('Error flushing sticky positions store', e, st);
    }

    // 3. Flush open-document layer
    try {
      if (onFlushOpenDocuments != null) {
        await onFlushOpenDocuments!();
      } else if (noteDocumentStore != null) {
        await noteDocumentStore!.flushAll();
      }
    } catch (e, st) {
      _log.warning('Error flushing open documents', e, st);
    }

    // 4. Custom quit hook (e.g. sync client shutdown)
    try {
      if (onQuit != null) {
        await onQuit!();
      }
    } catch (e, st) {
      _log.warning('Error running onQuit hook', e, st);
    }

    // 5. Hide & dispose tray, destroy window, exit
    try {
      await trayService.hide();
      await trayService.dispose();
      await windowService.destroy();
    } catch (e, st) {
      _log.warning('Error during final desktop cleanup', e, st);
    }

    await _exitProcess(0);
  }

  /// Cleans up subscriptions and hotkey registrations.
  Future<void> dispose() async {
    await _trayActionSub?.cancel();
    _trayActionSub = null;
    await _iconClickSub?.cancel();
    _iconClickSub = null;
    await _windowCloseSub?.cancel();
    _windowCloseSub = null;
    await globalHotkeyService.unregisterAll();
    _initialized = false;
  }
}
