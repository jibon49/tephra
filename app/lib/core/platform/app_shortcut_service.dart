// © 2026 Tephra. All rights reserved.

/// Launcher app shortcuts service (e.g. Android long-press app icon shortcuts).
abstract interface class AppShortcutService {
  Future<void> init(
    void Function(String shortcutId) onShortcut,
  ); // ids: 'new-note', 'daily', 'new-sticky'
}

/// No-op implementation of [AppShortcutService] for unsupported platforms.
class NoopAppShortcutService implements AppShortcutService {
  const NoopAppShortcutService();

  @override
  Future<void> init(void Function(String shortcutId) onShortcut) async {}
}

/// Android stub implementation of [AppShortcutService].
class AndroidAppShortcutService implements AppShortcutService {
  @override
  Future<void> init(void Function(String shortcutId) onShortcut) {
    throw UnimplementedError(
      'AndroidAppShortcutService.init will be implemented in step 04.16',
    );
  }
}
