// © 2026 Tephra. All rights reserved.

/// System-wide global hotkey service.
abstract interface class GlobalHotkeyService {
  /// Registers a global hotkey accelerator (e.g. 'Ctrl+Alt+N') with an action callback.
  Future<void> register(String accelerator, void Function() onPressed);

  /// Unregisters all registered global hotkeys.
  Future<void> unregisterAll();
}

/// No-op implementation of [GlobalHotkeyService] for unsupported platforms.
class NoopGlobalHotkeyService implements GlobalHotkeyService {
  const NoopGlobalHotkeyService();

  @override
  Future<void> register(String accelerator, void Function() onPressed) async {}

  @override
  Future<void> unregisterAll() async {}
}

/// Windows stub implementation of [GlobalHotkeyService].
class WindowsGlobalHotkeyService implements GlobalHotkeyService {
  @override
  Future<void> register(String accelerator, void Function() onPressed) {
    throw UnimplementedError(
      'WindowsGlobalHotkeyService.register will be implemented in step 04.11',
    );
  }

  @override
  Future<void> unregisterAll() {
    throw UnimplementedError(
      'WindowsGlobalHotkeyService.unregisterAll will be implemented in step 04.11',
    );
  }
}
