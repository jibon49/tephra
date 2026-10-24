// © 2026 Tephra. All rights reserved.

import 'dart:async';

/// Actions that can be performed from the system tray menu.
enum TrayAction {
  newSticky,
  showAllStickies,
  hideAllStickies,
  openTephra,
  quit,
}

/// Base class for system tray menu entries.
sealed class TrayMenuEntry {
  const TrayMenuEntry();
}

/// A clickable menu item in the system tray menu.
final class TrayMenuItem extends TrayMenuEntry {
  const TrayMenuItem({
    required this.id,
    required this.label,
    this.isEnabled = true,
  });

  final String id;
  final String label;
  final bool isEnabled;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrayMenuItem &&
          id == other.id &&
          label == other.label &&
          isEnabled == other.isEnabled;

  @override
  int get hashCode => Object.hash(id, label, isEnabled);
}

/// A separator bar in the system tray menu.
final class TrayMenuSeparator extends TrayMenuEntry {
  const TrayMenuSeparator();

  @override
  bool operator ==(Object other) => other is TrayMenuSeparator;

  @override
  int get hashCode => 0;
}

/// Platform service for interacting with the system tray icon and menu.
abstract interface class TrayService {
  /// Initializes the tray service with [tooltip].
  Future<void> init({required String tooltip});

  /// Shows the tray icon with the given [tooltip].
  Future<void> show({required String tooltip});

  /// Updates the tooltip displayed when hovering over the tray icon.
  Future<void> setTooltip(String text);

  /// Configures the context menu displayed on tray icon interaction.
  Future<void> setMenu(List<TrayMenuEntry> entries);

  /// Configures the context menu from high-level [TrayAction] values.
  Future<void> setActions(List<TrayAction> actions);

  /// Stream of high-level [TrayAction] clicks.
  Stream<TrayAction> get actions;

  /// Stream of clicked menu item IDs.
  Stream<String> get menuClicks;

  /// Stream of clicks on the tray icon itself.
  Stream<void> get iconClicks;

  /// Hides the tray icon.
  Future<void> hide();

  /// Releases all resources associated with the tray icon.
  Future<void> dispose();
}

/// No-op implementation of [TrayService] for unsupported platforms (e.g. Android/Web).
class NoopTrayService implements TrayService {
  const NoopTrayService();

  @override
  Future<void> init({required String tooltip}) async {}

  @override
  Future<void> show({required String tooltip}) async {}

  @override
  Future<void> setTooltip(String text) async {}

  @override
  Future<void> setMenu(List<TrayMenuEntry> entries) async {}

  @override
  Future<void> setActions(List<TrayAction> actions) async {}

  @override
  Stream<TrayAction> get actions => const Stream.empty();

  @override
  Stream<String> get menuClicks => const Stream.empty();

  @override
  Stream<void> get iconClicks => const Stream.empty();

  @override
  Future<void> hide() async {}

  @override
  Future<void> dispose() async {}
}
