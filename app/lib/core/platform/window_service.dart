// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:window_manager/window_manager.dart';

/// Platform service for window management (desktop).
abstract interface class WindowService {
  /// Shows and focuses the main application window.
  Future<void> showMainWindow();

  /// Hides the main application window (e.g. to system tray).
  Future<void> hideMainWindow();

  /// Checks whether autostart with Windows is enabled.
  Future<bool> isLaunchAtStartupEnabled();

  /// Enables or disables autostart with Windows.
  Future<void> setLaunchAtStartup(bool enabled);

  /// Sets whether window close is intercepted rather than immediately terminating the process.
  Future<void> setPreventClose(bool prevent);

  /// Checks whether close interception is enabled.
  Future<bool> isPreventClose();

  /// Stream of user-initiated close requests (e.g. clicking the 'X' button).
  Stream<void> get windowCloseEvents;

  /// Destroys the window and releases resources.
  Future<void> destroy();
}

/// No-op implementation of [WindowService] for unsupported platforms (e.g. Android/Web).
class NoopWindowService implements WindowService {
  const NoopWindowService();

  @override
  Future<void> showMainWindow() async {}

  @override
  Future<void> hideMainWindow() async {}

  @override
  Future<bool> isLaunchAtStartupEnabled() async => false;

  @override
  Future<void> setLaunchAtStartup(bool enabled) async {}

  @override
  Future<void> setPreventClose(bool prevent) async {}

  @override
  Future<bool> isPreventClose() async => false;

  @override
  Stream<void> get windowCloseEvents => const Stream.empty();

  @override
  Future<void> destroy() async {}
}

/// Windows implementation of [WindowService] backed by `package:window_manager`.
class WindowsWindowService with WindowListener implements WindowService {
  WindowsWindowService({WindowManager? manager})
    : _manager = manager ?? windowManager {
    _manager.addListener(this);
  }

  final WindowManager _manager;
  final StreamController<void> _closeEvents =
      StreamController<void>.broadcast();

  @override
  Future<void> showMainWindow() async {
    await _manager.show();
    await _manager.focus();
  }

  @override
  Future<void> hideMainWindow() async {
    await _manager.hide();
  }

  @override
  Future<bool> isLaunchAtStartupEnabled() async => false;

  @override
  Future<void> setLaunchAtStartup(bool enabled) async {}

  @override
  Future<void> setPreventClose(bool prevent) async {
    await _manager.setPreventClose(prevent);
  }

  @override
  Future<bool> isPreventClose() async {
    return _manager.isPreventClose();
  }

  @override
  Stream<void> get windowCloseEvents => _closeEvents.stream;

  @override
  void onWindowClose() {
    if (!_closeEvents.isClosed) {
      _closeEvents.add(null);
    }
  }

  @override
  Future<void> destroy() async {
    _manager.removeListener(this);
    await _closeEvents.close();
    await _manager.destroy();
  }
}
