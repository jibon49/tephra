// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:tephra_sync/tephra_sync.dart';

import '../../l10n/app_localizations.dart';
import '../platform/tray_service.dart';
import '../platform/window_service.dart';
import 'sync_messages.dart';
import 'sync_worker_client.dart';

final _log = Logger('sync.tray');

/// Coordinates the system tray, window close prevention, and sync lifecycle on desktop.
class TraySyncCoordinator {
  TraySyncCoordinator({
    required this.trayService,
    required this.windowService,
    SyncWorkerClient? syncWorkerClient,
    this.onOpen,
    this.onSyncNow,
    this.onTogglePause,
    this.onQuit,
    Future<void> Function(int code)? exitProcess,
  }) : _client = syncWorkerClient,
       _exitProcess = exitProcess ?? _defaultExit {
    _initSubscriptions();
  }

  static Future<void> _defaultExit(int code) async {
    exit(code);
  }

  final TrayService trayService;
  final WindowService windowService;
  final SyncWorkerClient? _client;
  final void Function()? onOpen;
  final void Function()? onSyncNow;
  final void Function()? onTogglePause;
  final Future<void> Function()? onQuit;
  final Future<void> Function(int code) _exitProcess;

  StreamSubscription<String>? _menuSub;
  StreamSubscription<void>? _iconSub;
  StreamSubscription<void>? _closeSub;
  bool _isPaused = false;
  bool _keepSyncingWhenClosed = false;

  void _initSubscriptions() {
    _menuSub = trayService.menuClicks.listen(_handleMenuClick);
    _iconSub = trayService.iconClicks.listen((_) => showWindow());
    _closeSub = windowService.windowCloseEvents.listen(
      (_) => handleWindowClose(),
    );
  }

  /// Sets whether the window should minimize to tray on close.
  Future<void> setKeepSyncingWhenClosed(bool keep) async {
    _keepSyncingWhenClosed = keep;
    await windowService.setPreventClose(keep);
  }

  /// Handles user closing the main window.
  Future<void> handleWindowClose() async {
    if (_keepSyncingWhenClosed) {
      await windowService.hideMainWindow();
    } else {
      await quit();
    }
  }

  /// Shows the main window and brings it to focus.
  Future<void> showWindow() async {
    await windowService.showMainWindow();
    onOpen?.call();
  }

  /// Updates tray tooltip and menu according to sync state.
  Future<void> updateStatus({
    required SyncUiState state,
    int syncingCount = 0,
    bool isPaused = false,
    required AppLocalizations l10n,
  }) async {
    _isPaused = isPaused;
    final tooltip = formatTooltip(
      state: state,
      syncingCount: syncingCount,
      l10n: l10n,
    );
    await trayService.setTooltip(tooltip);
    await trayService.setMenu(buildMenu(isPaused: isPaused, l10n: l10n));
  }

  static String formatTooltip({
    required SyncUiState state,
    int syncingCount = 0,
    required AppLocalizations l10n,
  }) {
    switch (state) {
      case SyncUiState.syncing:
        return l10n.trayTooltipSyncing(syncingCount);
      case SyncUiState.offline:
        return l10n.trayTooltipOffline;
      case SyncUiState.needsAttention:
      case SyncUiState.error:
        return l10n.trayTooltipNeedsAttention;
      case SyncUiState.notConfigured:
      case SyncUiState.idle:
      case SyncUiState.pending:
      case SyncUiState.paused:
        return l10n.trayTooltipUpToDate;
    }
  }

  static List<TrayMenuEntry> buildMenu({
    required bool isPaused,
    required AppLocalizations l10n,
  }) {
    return [
      TrayMenuItem(id: 'tray.open', label: l10n.trayMenuOpen),
      TrayMenuItem(id: 'tray.sync-now', label: l10n.trayMenuSyncNow),
      TrayMenuItem(
        id: 'tray.pause-toggle',
        label: isPaused ? l10n.trayMenuResumeSync : l10n.trayMenuPauseSync,
      ),
      const TrayMenuSeparator(),
      TrayMenuItem(id: 'tray.quit', label: l10n.trayMenuQuit),
    ];
  }

  Future<void> _handleMenuClick(String id) async {
    switch (id) {
      case 'tray.open':
        await showWindow();
      case 'tray.sync-now':
        onSyncNow?.call();
        unawaited(_client?.syncNow(trigger: SyncTrigger.manual));
      case 'tray.pause-toggle':
        onTogglePause?.call();
        unawaited(_client?.setPaused(!_isPaused));
      case 'tray.quit':
        await quit();
    }
  }

  /// Shuts down workers gracefully (up to 10 seconds) and terminates process.
  Future<void> quit() async {
    _log.info('Quitting application: shutting down sync worker...');
    try {
      if (onQuit != null) {
        await onQuit!();
      }
      if (_client != null) {
        await _client.shutdown().timeout(
          const Duration(seconds: 10),
          onTimeout: () => null,
        );
      }
    } catch (e, st) {
      _log.warning('Error during quit shutdown', e, st);
    }
    await trayService.hide();
    await trayService.dispose();
    await windowService.destroy();
    await _exitProcess(0);
  }

  Future<void> dispose() async {
    await _menuSub?.cancel();
    await _iconSub?.cancel();
    await _closeSub?.cancel();
  }
}
