// © 2026 Tephra. All rights reserved.

import 'package:flutter/foundation.dart';

/// A vault recently opened by the user.
@immutable
final class RecentVault {
  const RecentVault({
    required this.path,
    required this.name,
    required this.lastOpened,
  });

  factory RecentVault.fromJson(Map<String, Object?> json) {
    return RecentVault(
      path: json['path'] as String? ?? '',
      name: json['name'] as String? ?? '',
      lastOpened: json['lastOpened'] != null
          ? DateTime.tryParse(json['lastOpened'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  final String path;
  final String name;
  final DateTime lastOpened;

  Map<String, Object?> toJson() => {
    'path': path,
    'name': name,
    'lastOpened': lastOpened.toIso8601String(),
  };

  RecentVault copyWith({String? path, String? name, DateTime? lastOpened}) {
    return RecentVault(
      path: path ?? this.path,
      name: name ?? this.name,
      lastOpened: lastOpened ?? this.lastOpened,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecentVault &&
          path == other.path &&
          name == other.name &&
          lastOpened == other.lastOpened;

  @override
  int get hashCode => Object.hash(path, name, lastOpened);

  @override
  String toString() => 'RecentVault($name, $path, $lastOpened)';
}

/// Global application settings stored in `<appSupportDir>/settings.json`.
@immutable
final class AppSettings {
  const AppSettings({
    this.themeMode = 'system',
    this.recentVaults = const [],
    required this.deviceId,
    this.deviceName = '',
    this.lastVaultPath,
    this.recentCommands = const [],
    this.pagePreviewReadingRequiresCtrl = false,
    this.pagePreviewEditorRequiresCtrl = true,
    this.switcherShowAttachments = false,
    bool? keepSyncingWhenClosed,
    bool? keepRunningInTray,
    this.stickiesRestoreOnStart = true,
    this.stickiesHiddenAll = false,
    this.stickiesMaxWindows = 20,
    this.stickyHotkey = 'Ctrl+Alt+N',
    this.startWithWindows = false,
    this.quickNoteNotification = false,
    this.remindersEnabled = true,
    this.extra = const {},
  }) : keepRunningInTray = keepRunningInTray ?? keepSyncingWhenClosed ?? true;

  factory AppSettings.fromJson(
    Map<String, Object?> json, {
    required String Function() newDeviceId,
  }) {
    final deviceId = json['deviceId'] as String? ?? newDeviceId();
    final themeMode = json['themeMode'] as String? ?? 'system';
    final deviceName = json['deviceName'] as String? ?? '';
    final lastVaultPath = json['lastVaultPath'] as String?;
    final pagePreviewReadingRequiresCtrl =
        json['pagePreviewReadingRequiresCtrl'] as bool? ?? false;
    final pagePreviewEditorRequiresCtrl =
        json['pagePreviewEditorRequiresCtrl'] as bool? ?? true;
    final switcherShowAttachments =
        json['switcherShowAttachments'] as bool? ?? false;
    final keepRunningInTray =
        json['app.keepRunningInTray'] as bool? ??
        (json['keepSyncingWhenClosed'] as bool? ?? true);
    final stickiesRestoreOnStart =
        json['stickies.restoreOnStart'] as bool? ?? true;
    final stickiesHiddenAll = json['stickies.hiddenAll'] as bool? ?? false;
    final stickiesMaxWindows = json['stickies.maxWindows'] as int? ?? 20;
    final stickyHotkey = json['stickies.hotkey'] as String? ?? 'Ctrl+Alt+N';
    final startWithWindows = json['app.startWithWindows'] as bool? ?? false;
    final quickNoteNotification =
        json['capture.persistentNotification'] as bool? ?? false;
    final remindersEnabled = json['reminders.enabled'] as bool? ?? true;

    final rawRecentVaults = json['recentVaults'];
    final recentVaults = <RecentVault>[];
    if (rawRecentVaults is List) {
      for (final item in rawRecentVaults) {
        if (item is Map) {
          recentVaults.add(RecentVault.fromJson(item.cast<String, Object?>()));
        }
      }
    }

    final rawRecentCommands = json['recentCommands'];
    final recentCommands = <String>[];
    if (rawRecentCommands is List) {
      for (final item in rawRecentCommands) {
        if (item is String) {
          recentCommands.add(item);
        }
      }
    }

    const knownKeys = {
      'deviceId',
      'themeMode',
      'deviceName',
      'lastVaultPath',
      'recentVaults',
      'recentCommands',
      'pagePreviewReadingRequiresCtrl',
      'pagePreviewEditorRequiresCtrl',
      'switcherShowAttachments',
      'keepSyncingWhenClosed',
      'app.keepRunningInTray',
      'stickies.restoreOnStart',
      'stickies.hiddenAll',
      'stickies.maxWindows',
      'stickies.hotkey',
      'app.startWithWindows',
      'capture.persistentNotification',
      'reminders.enabled',
    };
    final extra = <String, Object?>{};
    for (final entry in json.entries) {
      if (!knownKeys.contains(entry.key)) {
        extra[entry.key] = entry.value;
      }
    }

    return AppSettings(
      deviceId: deviceId,
      themeMode: themeMode,
      deviceName: deviceName,
      lastVaultPath: lastVaultPath,
      recentVaults: List.unmodifiable(recentVaults.take(12)),
      recentCommands: List.unmodifiable(recentCommands.take(10)),
      pagePreviewReadingRequiresCtrl: pagePreviewReadingRequiresCtrl,
      pagePreviewEditorRequiresCtrl: pagePreviewEditorRequiresCtrl,
      switcherShowAttachments: switcherShowAttachments,
      keepRunningInTray: keepRunningInTray,
      stickiesRestoreOnStart: stickiesRestoreOnStart,
      stickiesHiddenAll: stickiesHiddenAll,
      stickiesMaxWindows: stickiesMaxWindows,
      stickyHotkey: stickyHotkey,
      startWithWindows: startWithWindows,
      quickNoteNotification: quickNoteNotification,
      remindersEnabled: remindersEnabled,
      extra: Map.unmodifiable(extra),
    );
  }

  /// 'system' | 'light' | 'dark'
  final String themeMode;

  /// Newest first, max 12.
  final List<RecentVault> recentVaults;

  /// UUID v4 generated on first run.
  final String deviceId;

  /// User-facing device name.
  final String deviceName;

  /// Path of the last opened vault to re-open on startup.
  final String? lastVaultPath;

  /// IDs of recently used palette commands, newest first, max 10.
  final List<String> recentCommands;

  /// Whether hovering over internal links in reading view requires holding Ctrl to show page preview.
  final bool pagePreviewReadingRequiresCtrl;

  /// Whether hovering over internal links in editor view requires holding Ctrl to show page preview.
  final bool pagePreviewEditorRequiresCtrl;

  /// Whether the quick switcher includes non-markdown attachments.
  final bool switcherShowAttachments;

  /// Whether to keep the app and sync workers running in the system tray when the window is closed.
  final bool keepRunningInTray;
  bool get keepSyncingWhenClosed => keepRunningInTray;

  /// Whether to restore floating sticky windows at startup.
  final bool stickiesRestoreOnStart;

  /// Whether stickies are currently hidden globally.
  final bool stickiesHiddenAll;

  /// Maximum allowed floating sticky windows open at once.
  final int stickiesMaxWindows;

  /// Global hotkey accelerator string for quick note capture.
  final String stickyHotkey;

  /// Whether to launch Tephra on Windows user login.
  final bool startWithWindows;

  /// Whether persistent quick-note notification is enabled on Android.
  final bool quickNoteNotification;

  /// Whether reminder notifications are enabled.
  final bool remindersEnabled;

  /// Unknown keys preserved on read/write.
  final Map<String, Object?> extra;

  Map<String, Object?> toJson() {
    final map = <String, Object?>{
      'themeMode': themeMode,
      'recentVaults': recentVaults.map((v) => v.toJson()).toList(),
      'deviceId': deviceId,
      'deviceName': deviceName,
      if (lastVaultPath != null) 'lastVaultPath': lastVaultPath,
      'recentCommands': recentCommands,
      'pagePreviewReadingRequiresCtrl': pagePreviewReadingRequiresCtrl,
      'pagePreviewEditorRequiresCtrl': pagePreviewEditorRequiresCtrl,
      'switcherShowAttachments': switcherShowAttachments,
      'keepSyncingWhenClosed': keepRunningInTray,
      'app.keepRunningInTray': keepRunningInTray,
      'stickies.restoreOnStart': stickiesRestoreOnStart,
      'stickies.hiddenAll': stickiesHiddenAll,
      'stickies.maxWindows': stickiesMaxWindows,
      'stickies.hotkey': stickyHotkey,
      'app.startWithWindows': startWithWindows,
      'capture.persistentNotification': quickNoteNotification,
      'reminders.enabled': remindersEnabled,
    };
    map.addAll(extra);
    return map;
  }

  AppSettings copyWith({
    String? themeMode,
    List<RecentVault>? recentVaults,
    String? deviceId,
    String? deviceName,
    String? Function()? lastVaultPath,
    List<String>? recentCommands,
    bool? pagePreviewReadingRequiresCtrl,
    bool? pagePreviewEditorRequiresCtrl,
    bool? switcherShowAttachments,
    bool? keepSyncingWhenClosed,
    bool? keepRunningInTray,
    bool? stickiesRestoreOnStart,
    bool? stickiesHiddenAll,
    int? stickiesMaxWindows,
    String? stickyHotkey,
    bool? startWithWindows,
    bool? quickNoteNotification,
    bool? remindersEnabled,
    Map<String, Object?>? extra,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      recentVaults: recentVaults ?? this.recentVaults,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      lastVaultPath: lastVaultPath != null
          ? lastVaultPath()
          : this.lastVaultPath,
      recentCommands: recentCommands ?? this.recentCommands,
      pagePreviewReadingRequiresCtrl:
          pagePreviewReadingRequiresCtrl ?? this.pagePreviewReadingRequiresCtrl,
      pagePreviewEditorRequiresCtrl:
          pagePreviewEditorRequiresCtrl ?? this.pagePreviewEditorRequiresCtrl,
      switcherShowAttachments:
          switcherShowAttachments ?? this.switcherShowAttachments,
      keepRunningInTray:
          keepRunningInTray ?? keepSyncingWhenClosed ?? this.keepRunningInTray,
      stickiesRestoreOnStart:
          stickiesRestoreOnStart ?? this.stickiesRestoreOnStart,
      stickiesHiddenAll: stickiesHiddenAll ?? this.stickiesHiddenAll,
      stickiesMaxWindows: stickiesMaxWindows ?? this.stickiesMaxWindows,
      stickyHotkey: stickyHotkey ?? this.stickyHotkey,
      startWithWindows: startWithWindows ?? this.startWithWindows,
      quickNoteNotification:
          quickNoteNotification ?? this.quickNoteNotification,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      extra: extra ?? this.extra,
    );
  }

  /// Adds [path] to [recentVaults], moving it to front if already present. Max 12.
  AppSettings addRecentVault(String path, String name, [DateTime? time]) {
    final now = time ?? DateTime.now();
    final updated = <RecentVault>[
      RecentVault(path: path, name: name, lastOpened: now),
    ];
    for (final v in recentVaults) {
      if (v.path != path) {
        updated.add(v);
      }
    }
    return copyWith(
      recentVaults: List.unmodifiable(updated.take(12)),
      lastVaultPath: () => path,
    );
  }

  /// Removes [path] from [recentVaults] and clears [lastVaultPath] if matched.
  AppSettings removeRecentVault(String path) {
    final updated = recentVaults.where((v) => v.path != path).toList();
    final newLast = lastVaultPath == path ? null : lastVaultPath;
    return copyWith(
      recentVaults: List.unmodifiable(updated),
      lastVaultPath: () => newLast,
    );
  }

  /// Inserts [commandId] at the front of [recentCommands], removing any prior occurrence. Max 10.
  AppSettings touchCommand(String commandId) {
    final updated = <String>[commandId];
    for (final id in recentCommands) {
      if (id != commandId) {
        updated.add(id);
      }
    }
    return copyWith(recentCommands: List.unmodifiable(updated.take(10)));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings &&
          themeMode == other.themeMode &&
          listEquals(recentVaults, other.recentVaults) &&
          deviceId == other.deviceId &&
          deviceName == other.deviceName &&
          lastVaultPath == other.lastVaultPath &&
          listEquals(recentCommands, other.recentCommands) &&
          pagePreviewReadingRequiresCtrl ==
              other.pagePreviewReadingRequiresCtrl &&
          pagePreviewEditorRequiresCtrl ==
              other.pagePreviewEditorRequiresCtrl &&
          switcherShowAttachments == other.switcherShowAttachments &&
          keepRunningInTray == other.keepRunningInTray &&
          stickiesRestoreOnStart == other.stickiesRestoreOnStart &&
          stickiesHiddenAll == other.stickiesHiddenAll &&
          stickiesMaxWindows == other.stickiesMaxWindows &&
          stickyHotkey == other.stickyHotkey &&
          startWithWindows == other.startWithWindows &&
          quickNoteNotification == other.quickNoteNotification &&
          remindersEnabled == other.remindersEnabled &&
          mapEquals(extra, other.extra);

  @override
  int get hashCode => Object.hashAll([
    themeMode,
    Object.hashAll(recentVaults),
    deviceId,
    deviceName,
    lastVaultPath,
    Object.hashAll(recentCommands),
    pagePreviewReadingRequiresCtrl,
    pagePreviewEditorRequiresCtrl,
    switcherShowAttachments,
    keepRunningInTray,
    stickiesRestoreOnStart,
    stickiesHiddenAll,
    stickiesMaxWindows,
    stickyHotkey,
    startWithWindows,
    quickNoteNotification,
    remindersEnabled,
    Object.hashAll(extra.entries),
  ]);
}
