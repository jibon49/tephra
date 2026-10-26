// © 2026 Tephra. All rights reserved.

import 'package:quick_actions/quick_actions.dart';

/// Launcher app shortcuts service (e.g. Android long-press app icon shortcuts).
abstract interface class AppShortcutService {
  Future<void> init(
    void Function(String shortcutId) onShortcut, {
    String? newNoteTitle,
    String? dailyNoteTitle,
    String? newStickyTitle,
  }); // ids: 'new-note', 'daily', 'new-sticky'
}

/// No-op implementation of [AppShortcutService] for unsupported platforms.
class NoopAppShortcutService implements AppShortcutService {
  const NoopAppShortcutService();

  @override
  Future<void> init(
    void Function(String shortcutId) onShortcut, {
    String? newNoteTitle,
    String? dailyNoteTitle,
    String? newStickyTitle,
  }) async {}
}

/// Android implementation of [AppShortcutService] using [QuickActions].
class AndroidAppShortcutService implements AppShortcutService {
  AndroidAppShortcutService({QuickActions? quickActions})
    : _quickActions = quickActions ?? const QuickActions();

  final QuickActions _quickActions;

  @override
  Future<void> init(
    void Function(String shortcutId) onShortcut, {
    String? newNoteTitle,
    String? dailyNoteTitle,
    String? newStickyTitle,
  }) async {
    try {
      await _quickActions.initialize((String type) {
        onShortcut(type);
      });
      await _quickActions.setShortcutItems([
        ShortcutItem(
          type: 'new-note',
          localizedTitle: newNoteTitle ?? 'New note',
          icon: 'ic_shortcut_note',
        ),
        ShortcutItem(
          type: 'daily',
          localizedTitle: dailyNoteTitle ?? "Today's note",
          icon: 'ic_shortcut_daily',
        ),
        ShortcutItem(
          type: 'new-sticky',
          localizedTitle: newStickyTitle ?? 'New sticky',
          icon: 'ic_shortcut_sticky',
        ),
      ]);
    } catch (_) {}
  }
}
