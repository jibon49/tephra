// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:tray_manager/tray_manager.dart';

import '../../l10n/app_localizations.dart';
import 'tray_service.dart';

/// Low-level abstraction over the native tray icon backend, injectable for testing.
abstract interface class TrayIconBackend {
  void setVisible(bool visible);
  void setTooltip(String text);
  void setIcon(String assetPath);
  void setMenu(
    List<TrayMenuEntry> entries,
    void Function(String id) onMenuClick,
  );
  void addClickListener(void Function() onClick);
  void dispose();
}

/// Native implementation of [TrayIconBackend] using `package:tray_manager`.
class NativeTrayIconBackend implements TrayIconBackend {
  NativeTrayIconBackend({this.defaultIconPath = 'assets/tray/tray.ico'});

  final String defaultIconPath;
  TrayIcon? _trayIcon;
  Menu? _menu;
  final List<MenuItem> _menuItems = [];
  ListenerId? _clickListenerId;

  /// Retained menu instance to prevent premature native garbage collection.
  Menu? get currentMenu => _menu;

  void _ensureTrayIcon() {
    if (_trayIcon != null) return;
    _trayIcon = TrayIcon.create();
    if (_trayIcon != null) {
      try {
        _trayIcon!.icon = ImageAsset.fromAsset(defaultIconPath);
      } catch (_) {}
    }
  }

  @override
  void setVisible(bool visible) {
    _ensureTrayIcon();
    _trayIcon?.setVisible(visible);
  }

  @override
  void setTooltip(String text) {
    _ensureTrayIcon();
    _trayIcon?.setTooltip(text);
  }

  @override
  void setIcon(String assetPath) {
    _ensureTrayIcon();
    try {
      _trayIcon?.icon = ImageAsset.fromAsset(assetPath);
    } catch (_) {}
  }

  @override
  void addClickListener(void Function() onClick) {
    _ensureTrayIcon();
    if (_trayIcon != null && _clickListenerId == null) {
      _clickListenerId = _trayIcon!.addListener((event) {
        if (event is TrayIconClickedEvent) {
          onClick();
        }
      });
    }
  }

  @override
  void setMenu(
    List<TrayMenuEntry> entries,
    void Function(String id) onMenuClick,
  ) {
    _ensureTrayIcon();
    final menu = Menu.create();
    if (menu == null) return;
    _menu = menu;
    _menuItems.clear();

    for (final entry in entries) {
      switch (entry) {
        case final TrayMenuItem item:
          final menuItem = MenuItem.createWithLabelAndType(
            item.label,
            MenuItemType.normal,
          );
          if (menuItem != null) {
            menuItem.isEnabled = item.isEnabled;
            menuItem.addListener((event) {
              if (event is MenuItemClickedEvent) {
                onMenuClick(item.id);
              }
            });
            _menuItems.add(menuItem);
            menu.addItem(menuItem);
          }
        case TrayMenuSeparator():
          menu.addSeparator();
      }
    }
    _trayIcon?.setContextMenu(menu);
  }

  @override
  void dispose() {
    if (_clickListenerId != null && _trayIcon != null) {
      _trayIcon!.removeListener(_clickListenerId!);
      _clickListenerId = null;
    }
    _trayIcon?.dispose();
    _trayIcon = null;
    _menu = null;
    _menuItems.clear();
  }
}

/// Windows implementation of [TrayService].
class WindowsTrayService implements TrayService {
  WindowsTrayService({TrayIconBackend? backend})
    : _backend = backend ?? NativeTrayIconBackend() {
    _backend.addClickListener(() {
      if (!_iconClicks.isClosed) {
        _iconClicks.add(null);
      }
    });
  }

  final TrayIconBackend _backend;
  final StreamController<String> _menuClicks =
      StreamController<String>.broadcast();
  final StreamController<void> _iconClicks = StreamController<void>.broadcast();

  @override
  Stream<String> get menuClicks => _menuClicks.stream;

  @override
  Stream<TrayAction> get actions => _menuClicks.stream
      .map((id) {
        switch (id) {
          case 'new_sticky':
          case 'tray.new-sticky':
            return TrayAction.newSticky;
          case 'show_all_stickies':
          case 'tray.show-all-stickies':
            return TrayAction.showAllStickies;
          case 'hide_all_stickies':
          case 'tray.hide-all-stickies':
            return TrayAction.hideAllStickies;
          case 'open_tephra':
          case 'tray.open':
            return TrayAction.openTephra;
          case 'quit':
          case 'tray.quit':
            return TrayAction.quit;
          default:
            return null;
        }
      })
      .where((a) => a != null)
      .cast<TrayAction>();

  @override
  Stream<void> get iconClicks => _iconClicks.stream;

  @override
  Future<void> init({required String tooltip}) => show(tooltip: tooltip);

  @override
  Future<void> show({required String tooltip}) async {
    _backend.setTooltip(tooltip);
    _backend.setVisible(true);
  }

  @override
  Future<void> setTooltip(String text) async {
    _backend.setTooltip(text);
  }

  @override
  Future<void> setMenu(List<TrayMenuEntry> entries) async {
    _backend.setMenu(entries, (id) {
      if (!_menuClicks.isClosed) {
        _menuClicks.add(id);
      }
    });
  }

  @override
  Future<void> setActions(
    List<TrayAction> actions, {
    Map<TrayAction, String>? labels,
  }) async {
    final entries = <TrayMenuEntry>[];
    for (var i = 0; i < actions.length; i++) {
      final action = actions[i];
      final id = actionToMenuId(action);
      final label = labels?[action] ?? defaultActionLabel(action);
      entries.add(TrayMenuItem(id: id, label: label));
      if (action == TrayAction.hideAllStickies ||
          action == TrayAction.openTephra) {
        if (i + 1 < actions.length) {
          entries.add(const TrayMenuSeparator());
        }
      }
    }
    await setMenu(entries);
  }

  /// Converts a [TrayAction] to its menu item ID.
  static String actionToMenuId(TrayAction action) {
    switch (action) {
      case TrayAction.newSticky:
        return 'new_sticky';
      case TrayAction.showAllStickies:
        return 'show_all_stickies';
      case TrayAction.hideAllStickies:
        return 'hide_all_stickies';
      case TrayAction.openTephra:
        return 'open_tephra';
      case TrayAction.quit:
        return 'quit';
    }
  }

  /// Returns a fallback English label for [action].
  static String defaultActionLabel(TrayAction action) {
    switch (action) {
      case TrayAction.newSticky:
        return 'New sticky';
      case TrayAction.showAllStickies:
        return 'Show all stickies';
      case TrayAction.hideAllStickies:
        return 'Hide all stickies';
      case TrayAction.openTephra:
        return 'Open Tephra';
      case TrayAction.quit:
        return 'Quit';
    }
  }

  /// Builds the canonical tray menu entries using localized labels.
  static List<TrayMenuEntry> buildDefaultEntries(
    AppLocalizations l10n, {
    List<TrayMenuEntry> extraEntries = const [],
  }) {
    return [
      TrayMenuItem(id: 'new_sticky', label: l10n.trayNewSticky),
      TrayMenuItem(id: 'show_all_stickies', label: l10n.trayShowAllStickies),
      TrayMenuItem(id: 'hide_all_stickies', label: l10n.trayHideAllStickies),
      const TrayMenuSeparator(),
      TrayMenuItem(id: 'open_tephra', label: l10n.trayOpenTephra),
      if (extraEntries.isNotEmpty) ...[
        const TrayMenuSeparator(),
        ...extraEntries,
      ],
      const TrayMenuSeparator(),
      TrayMenuItem(id: 'quit', label: l10n.trayQuit),
    ];
  }

  @override
  Future<void> hide() async {
    _backend.setVisible(false);
  }

  @override
  Future<void> dispose() async {
    _backend.dispose();
    await _menuClicks.close();
    await _iconClicks.close();
  }
}
